package llm

import (
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestNewCircuitBreaker_Defaults(t *testing.T) {
	cb := NewCircuitBreaker()
	if cb.State() != StateClosed {
		t.Errorf("initial state = %v, want StateClosed", cb.State())
	}
	if cb.failureThreshold != 5 {
		t.Errorf("failureThreshold = %d, want 5", cb.failureThreshold)
	}
	if cb.successThreshold != 3 {
		t.Errorf("successThreshold = %d, want 3", cb.successThreshold)
	}
	if cb.openTimeout != 30*time.Second {
		t.Errorf("openTimeout = %v, want 30s", cb.openTimeout)
	}
	if cb.halfOpenMaxReqs != 1 {
		t.Errorf("halfOpenMaxReqs = %d, want 1", cb.halfOpenMaxReqs)
	}
}

func TestNewCircuitBreaker_CustomOptions(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(3),
		WithSuccessThreshold(2),
		WithOpenTimeout(10*time.Second),
		WithHalfOpenMaxRequests(5),
	)
	if cb.failureThreshold != 3 {
		t.Errorf("failureThreshold = %d, want 3", cb.failureThreshold)
	}
	if cb.successThreshold != 2 {
		t.Errorf("successThreshold = %d, want 2", cb.successThreshold)
	}
	if cb.openTimeout != 10*time.Second {
		t.Errorf("openTimeout = %v, want 10s", cb.openTimeout)
	}
	if cb.halfOpenMaxReqs != 5 {
		t.Errorf("halfOpenMaxReqs = %d, want 5", cb.halfOpenMaxReqs)
	}
}

// ── Closed -> Open transition ────────────────────────

func TestCircuitBreaker_ClosedToOpen(t *testing.T) {
	cb := NewCircuitBreaker(WithFailureThreshold(3))

	for i := 0; i < 2; i++ {
		cb.RecordFailure()
		if cb.State() != StateClosed {
			t.Errorf("after %d failures, state = %v, want StateClosed", i+1, cb.State())
		}
	}

	cb.RecordFailure() // 3rd failure trips the circuit
	if cb.State() != StateOpen {
		t.Errorf("after %d failures, state = %v, want StateOpen", 3, cb.State())
	}
}

func TestCircuitBreaker_SuccessResetsFailureCount(t *testing.T) {
	cb := NewCircuitBreaker(WithFailureThreshold(3))

	cb.RecordFailure()
	cb.RecordFailure() // 2 consecutive failures
	cb.RecordSuccess() // resets failure count
	cb.RecordFailure()
	cb.RecordFailure() // 2 more consecutive failures

	if cb.State() != StateClosed {
		t.Errorf("state = %v, want StateClosed (failures should have been reset by success)", cb.State())
	}
}

// ── Open state behavior ──────────────────────────────

func TestCircuitBreaker_Open_RejectsRequests(t *testing.T) {
	cb := NewCircuitBreaker(WithFailureThreshold(1))
	cb.RecordFailure() // trip the circuit

	if cb.State() != StateOpen {
		t.Fatalf("state = %v, want StateOpen", cb.State())
	}

	err := cb.Allow()
	if !errors.Is(err, ErrCircuitOpen) {
		t.Errorf("Allow() in Open state returned %v, want ErrCircuitOpen", err)
	}
}

// ── Open -> Half-Open transition ─────────────────────

func TestCircuitBreaker_OpenToHalfOpen(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(1),
		WithOpenTimeout(50*time.Millisecond),
	)

	cb.RecordFailure() // trips to Open
	if cb.State() != StateOpen {
		t.Fatalf("state = %v, want StateOpen", cb.State())
	}

	// Wait for open timeout to elapse.
	time.Sleep(80 * time.Millisecond)

	err := cb.Allow()
	if err != nil {
		t.Fatalf("Allow() after timeout returned %v, want nil (should transition to HalfOpen)", err)
	}
	if cb.State() != StateHalfOpen {
		t.Errorf("state = %v, want StateHalfOpen", cb.State())
	}
}

// ── Half-Open -> Closed transition ───────────────────

func TestCircuitBreaker_HalfOpenToClosed(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(1),
		WithSuccessThreshold(2),
		WithOpenTimeout(10*time.Millisecond),
	)

	cb.RecordFailure() // trips to Open

	time.Sleep(20 * time.Millisecond) // wait for open timeout
	cb.Allow()                        // transitions to HalfOpen

	cb.RecordSuccess()
	if cb.State() != StateHalfOpen {
		t.Errorf("after 1 success, state = %v, want StateHalfOpen", cb.State())
	}

	cb.RecordSuccess() // 2nd success transitions to Closed
	if cb.State() != StateClosed {
		t.Errorf("after 2 successes, state = %v, want StateClosed", cb.State())
	}
}

// ── Half-Open -> Open transition ─────────────────────

func TestCircuitBreaker_HalfOpenToOpen_OnFailure(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(1),
		WithSuccessThreshold(3),
		WithOpenTimeout(10*time.Millisecond),
	)

	cb.RecordFailure() // trips to Open
	time.Sleep(20 * time.Millisecond)
	cb.Allow() // transitions to HalfOpen

	cb.RecordSuccess() // 1 success
	cb.RecordFailure() // any failure in half-open reopens

	if cb.State() != StateOpen {
		t.Errorf("after failure in HalfOpen, state = %v, want StateOpen", cb.State())
	}
}

// ── Half-Open concurrency limit ──────────────────────

func TestCircuitBreaker_HalfOpen_ConcurrencyLimit(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(1),
		WithOpenTimeout(10*time.Millisecond),
		WithHalfOpenMaxRequests(2),
	)

	cb.RecordFailure() // trips to Open
	time.Sleep(20 * time.Millisecond)

	// First two probe requests are allowed.
	if err := cb.Allow(); err != nil {
		t.Fatalf("first Allow() returned %v, want nil", err)
	}
	if err := cb.Allow(); err != nil {
		t.Fatalf("second Allow() returned %v, want nil", err)
	}

	// Third probe should be rejected (max is 2).
	err := cb.Allow()
	if !errors.Is(err, ErrCircuitOpen) {
		t.Errorf("third Allow() returned %v, want ErrCircuitOpen", err)
	}
}

func TestCircuitBreaker_HalfOpen_ConcurrencyDecrementsOnSuccess(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(1),
		WithOpenTimeout(10*time.Millisecond),
		WithHalfOpenMaxRequests(1),
		WithSuccessThreshold(2),
	)

	cb.RecordFailure() // trips to Open
	time.Sleep(20 * time.Millisecond)

	// First probe request allowed.
	if err := cb.Allow(); err != nil {
		t.Fatalf("first Allow() returned %v, want nil", err)
	}
	// Second probe rejected (max=1).
	if err := cb.Allow(); !errors.Is(err, ErrCircuitOpen) {
		t.Fatalf("second Allow() returned %v, want ErrCircuitOpen", err)
	}

	// Record success: decrements halfOpenReqs.
	cb.RecordSuccess()
	// Now a new probe should be allowed.
	if err := cb.Allow(); err != nil {
		t.Fatalf("Allow() after success returned %v, want nil", err)
	}
}

// ── State change callback ────────────────────────────

func TestCircuitBreaker_OnStateChange(t *testing.T) {
	var transitions []struct{ from, to State }
	cb := NewCircuitBreaker(
		WithFailureThreshold(1),
		WithSuccessThreshold(1),
		WithOpenTimeout(10*time.Millisecond),
		WithOnStateChange(func(from, to State) {
			transitions = append(transitions, struct{ from, to State }{from, to})
		}),
	)

	cb.RecordFailure() // Closed -> Open
	time.Sleep(20 * time.Millisecond)
	cb.Allow()        // Open -> HalfOpen
	cb.RecordSuccess() // HalfOpen -> Closed

	if len(transitions) != 3 {
		t.Fatalf("expected 3 transitions, got %d", len(transitions))
	}

	want := []struct{ from, to State }{
		{StateClosed, StateOpen},
		{StateOpen, StateHalfOpen},
		{StateHalfOpen, StateClosed},
	}

	for i, w := range want {
		if transitions[i].from != w.from || transitions[i].to != w.to {
			t.Errorf("transition %d: from=%v to=%v, want from=%v to=%v",
				i, transitions[i].from, transitions[i].to, w.from, w.to)
		}
	}
}

// ── Full lifecycle ───────────────────────────────────

func TestCircuitBreaker_FullLifecycle(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(3),
		WithSuccessThreshold(2),
		WithOpenTimeout(50*time.Millisecond),
	)

	// Start closed.
	if cb.State() != StateClosed {
		t.Fatalf("initial state = %v, want StateClosed", cb.State())
	}

	// Accumulate failures but do not trip.
	cb.RecordFailure()
	cb.RecordFailure()
	if cb.State() != StateClosed {
		t.Errorf("state = %v, want StateClosed after 2 failures", cb.State())
	}

	// Trip the circuit.
	cb.RecordFailure()
	if cb.State() != StateOpen {
		t.Errorf("state = %v, want StateOpen after 3 failures", cb.State())
	}

	// Requests are rejected.
	if err := cb.Allow(); !errors.Is(err, ErrCircuitOpen) {
		t.Errorf("Allow() in Open = %v, want ErrCircuitOpen", err)
	}

	// Wait for open timeout.
	time.Sleep(70 * time.Millisecond)

	// Probe request transitions to half-open.
	if err := cb.Allow(); err != nil {
		t.Fatalf("Allow() after timeout = %v, want nil", err)
	}
	if cb.State() != StateHalfOpen {
		t.Errorf("state = %v, want StateHalfOpen", cb.State())
	}

	// Successful probes transition to closed.
	cb.RecordSuccess()
	cb.RecordSuccess()
	if cb.State() != StateClosed {
		t.Errorf("state = %v, want StateClosed after successful probes", cb.State())
	}
}

// ── Thread safety ────────────────────────────────────

func TestCircuitBreaker_ConcurrentAccess(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(10),
		WithSuccessThreshold(5),
		WithOpenTimeout(10*time.Millisecond),
	)

	const goroutines = 50
	const opsPerGoroutine = 100

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()
			for j := 0; j < opsPerGoroutine; j++ {
				err := cb.Allow()
				if err == nil {
					// Simulate some work, then record result.
					if id%3 == 0 {
						cb.RecordFailure()
					} else {
						cb.RecordSuccess()
					}
				}
			}
		}(i)
	}

	wg.Wait()

	// The test passes if there are no data races (detected by -race flag)
	// and the final state is one of the valid states.
	finalState := cb.State()
	if finalState != StateClosed && finalState != StateOpen && finalState != StateHalfOpen {
		t.Errorf("final state = %v, unexpected", finalState)
	}
}

func TestCircuitBreaker_ConcurrentAllowAndRecord(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(5),
		WithSuccessThreshold(3),
		WithOpenTimeout(5*time.Millisecond),
	)

	const iterations = 1000
	var allowedCount atomic.Int64
	var rejectedCount atomic.Int64

	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < iterations; j++ {
				if err := cb.Allow(); err == nil {
					allowedCount.Add(1)
					cb.RecordSuccess()
				} else {
					rejectedCount.Add(1)
				}
			}
		}()
	}
	wg.Wait()

	total := allowedCount.Load() + rejectedCount.Load()
	if total != 10*iterations {
		t.Errorf("total operations = %d, want %d", total, 10*iterations)
	}
}

// ── Allow() does not auto-transition from Closed ─────

func TestCircuitBreaker_Allow_ClosedStateAlwaysPasses(t *testing.T) {
	cb := NewCircuitBreaker()
	for i := 0; i < 100; i++ {
		if err := cb.Allow(); err != nil {
			t.Errorf("Allow() in Closed state returned %v on call %d", err, i)
		}
	}
}

// ── RecordFailure after success resets correctly ─────

func TestCircuitBreaker_MultipleTripsAndRecoveries(t *testing.T) {
	cb := NewCircuitBreaker(
		WithFailureThreshold(2),
		WithSuccessThreshold(1),
		WithOpenTimeout(10*time.Millisecond),
	)

	for cycle := 0; cycle < 3; cycle++ {
		// Trip the circuit.
		cb.RecordFailure()
		cb.RecordFailure()
		if cb.State() != StateOpen {
			t.Fatalf("cycle %d: state after failures = %v, want StateOpen", cycle, cb.State())
		}

		// Wait for timeout and probe.
		time.Sleep(20 * time.Millisecond)
		if err := cb.Allow(); err != nil {
			t.Fatalf("cycle %d: Allow() returned %v", cycle, err)
		}
		if cb.State() != StateHalfOpen {
			t.Fatalf("cycle %d: state after probe = %v, want StateHalfOpen", cycle, cb.State())
		}

		// Recover.
		cb.RecordSuccess()
		if cb.State() != StateClosed {
			t.Fatalf("cycle %d: state after recovery = %v, want StateClosed", cycle, cb.State())
		}
	}
}
