package llm

import (
	"errors"
	"sync"
	"time"
)

// State represents the current state of a circuit breaker.
type State int

const (
	// StateClosed means the circuit is healthy and requests pass through.
	StateClosed State = iota
	// StateOpen means the circuit has tripped and all requests are rejected.
	StateOpen
	// StateHalfOpen means the circuit is probing for recovery with limited requests.
	StateHalfOpen
)

// ErrCircuitOpen is returned by Allow when the circuit breaker is open
// (tripped) and the request must be rejected immediately.
var ErrCircuitOpen = errors.New("circuit breaker is open")

// CircuitBreaker implements a thread-safe three-state circuit breaker.
//
// State transitions:
//   - Closed -> Open:      after failureThreshold consecutive failures
//   - Open -> Half-Open:   after openTimeout has elapsed
//   - Half-Open -> Closed: after successThreshold consecutive successes
//   - Half-Open -> Open:   on any failure during probing
type CircuitBreaker struct {
	mu              sync.Mutex
	state           State
	failures        int
	successes       int
	lastFailureTime time.Time

	// Configurable thresholds
	failureThreshold int           // failures before opening (default: 5)
	successThreshold int           // successes in half-open to close (default: 3)
	openTimeout      time.Duration // how long to stay open before half-open (default: 30s)
	halfOpenMaxReqs  int           // max concurrent probe requests in half-open (default: 1)
	halfOpenReqs     int           // current in-flight probe requests

	// onStateChange is an optional callback invoked on state transitions.
	// It is called with the old and new state while the mutex is held, so
	// the callback must not call back into the CircuitBreaker.
	onStateChange func(from, to State)
}

// CircuitBreakerOption applies a configuration option to a CircuitBreaker.
type CircuitBreakerOption func(*CircuitBreaker)

// WithFailureThreshold sets the number of consecutive failures required to
// trip the circuit breaker open.
func WithFailureThreshold(n int) CircuitBreakerOption {
	return func(cb *CircuitBreaker) { cb.failureThreshold = n }
}

// WithSuccessThreshold sets the number of consecutive successes required in
// half-open state to transition back to closed.
func WithSuccessThreshold(n int) CircuitBreakerOption {
	return func(cb *CircuitBreaker) { cb.successThreshold = n }
}

// WithOpenTimeout sets how long the circuit breaker stays open before
// transitioning to half-open for probing.
func WithOpenTimeout(d time.Duration) CircuitBreakerOption {
	return func(cb *CircuitBreaker) { cb.openTimeout = d }
}

// WithHalfOpenMaxRequests sets the maximum number of concurrent probe requests
// allowed through while in half-open state.
func WithHalfOpenMaxRequests(n int) CircuitBreakerOption {
	return func(cb *CircuitBreaker) { cb.halfOpenMaxReqs = n }
}

// WithOnStateChange registers a callback invoked on state transitions.
func WithOnStateChange(fn func(from, to State)) CircuitBreakerOption {
	return func(cb *CircuitBreaker) { cb.onStateChange = fn }
}

// NewCircuitBreaker creates a CircuitBreaker with sensible defaults.
// Defaults: failureThreshold=5, successThreshold=3, openTimeout=30s,
// halfOpenMaxReqs=1.
func NewCircuitBreaker(opts ...CircuitBreakerOption) *CircuitBreaker {
	cb := &CircuitBreaker{
		state:            StateClosed,
		failureThreshold: 5,
		successThreshold: 3,
		openTimeout:      30 * time.Second,
		halfOpenMaxReqs:  1,
	}
	for _, opt := range opts {
		opt(cb)
	}
	return cb
}

// Allow checks whether a request is allowed to proceed. Returns nil if the
// request should be forwarded to the provider, or ErrCircuitOpen if the
// circuit is tripped and the request must fail fast.
//
// In half-open state, Allow enforces a concurrency limit on probe requests.
func (cb *CircuitBreaker) Allow() error {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	switch cb.state {
	case StateClosed:
		return nil

	case StateOpen:
		// Check if enough time has elapsed to transition to half-open.
		if time.Since(cb.lastFailureTime) > cb.openTimeout {
			cb.setState(StateHalfOpen)
			cb.halfOpenReqs = 1 // this request counts as the first probe
			return nil
		}
		return ErrCircuitOpen

	case StateHalfOpen:
		if cb.halfOpenReqs >= cb.halfOpenMaxReqs {
			return ErrCircuitOpen
		}
		cb.halfOpenReqs++
		return nil

	default:
		return nil
	}
}

// RecordSuccess records a successful request. In half-open state, consecutive
// successes count towards the success threshold; once reached, the circuit
// transitions back to closed. In closed state this is a no-op.
func (cb *CircuitBreaker) RecordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	switch cb.state {
	case StateHalfOpen:
		cb.successes++
		if cb.halfOpenReqs > 0 {
			cb.halfOpenReqs--
		}
		if cb.successes >= cb.successThreshold {
			cb.setState(StateClosed)
		}
	case StateClosed:
		// Reset consecutive failure count on success.
		cb.failures = 0
	}
}

// RecordFailure records a failed request. In closed state, consecutive
// failures count towards the failure threshold; once reached, the circuit
// trips open. In half-open state, any failure immediately reopens the circuit.
func (cb *CircuitBreaker) RecordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.lastFailureTime = time.Now()

	switch cb.state {
	case StateClosed:
		cb.failures++
		if cb.failures >= cb.failureThreshold {
			cb.setState(StateOpen)
		}
	case StateHalfOpen:
		if cb.halfOpenReqs > 0 {
			cb.halfOpenReqs--
		}
		cb.setState(StateOpen)
	}
}

// State returns the current circuit breaker state. Primarily for observability.
func (cb *CircuitBreaker) State() State {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	return cb.state
}

// setState transitions to a new state and resets counters. The caller must
// hold cb.mu.
func (cb *CircuitBreaker) setState(newState State) {
	if cb.state == newState {
		return
	}
	old := cb.state
	cb.state = newState

	// Reset counters for the new state.
	switch newState {
	case StateClosed:
		cb.failures = 0
		cb.successes = 0
		cb.halfOpenReqs = 0
	case StateOpen:
		cb.successes = 0
		cb.halfOpenReqs = 0
	case StateHalfOpen:
		cb.failures = 0
		cb.successes = 0
		cb.halfOpenReqs = 0
	}

	if cb.onStateChange != nil {
		cb.onStateChange(old, newState)
	}
}
