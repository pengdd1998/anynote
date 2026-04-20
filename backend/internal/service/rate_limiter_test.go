package service

import (
	"testing"
	"time"
)

func TestRateLimiterAllows(t *testing.T) {
	rl := NewRateLimiter(3, 100*time.Millisecond)

	if !rl.Allow("user1") {
		t.Error("first request should be allowed")
	}
	if !rl.Allow("user1") {
		t.Error("second request should be allowed")
	}
	if !rl.Allow("user1") {
		t.Error("third request should be allowed")
	}
	if rl.Allow("user1") {
		t.Error("fourth request should be rejected (limit=3)")
	}
}

func TestRateLimiterPerUserIsolation(t *testing.T) {
	rl := NewRateLimiter(1, time.Hour)

	if !rl.Allow("user1") {
		t.Error("user1 first request should be allowed")
	}
	if rl.Allow("user1") {
		t.Error("user1 second request should be rejected")
	}
	if !rl.Allow("user2") {
		t.Error("user2 first request should be allowed (independent from user1)")
	}
}

func TestRateLimiterWindowExpiry(t *testing.T) {
	rl := NewRateLimiter(1, 50*time.Millisecond)

	if !rl.Allow("user1") {
		t.Error("first request should be allowed")
	}
	if rl.Allow("user1") {
		t.Error("second request should be rejected")
	}

	// Wait for window to expire
	time.Sleep(80 * time.Millisecond)

	if !rl.Allow("user1") {
		t.Error("request after window expiry should be allowed")
	}
}

func TestRateLimiterCount(t *testing.T) {
	rl := NewRateLimiter(10, time.Hour)

	rl.Allow("user1")
	rl.Allow("user1")
	rl.Allow("user1")

	if count := rl.Count("user1"); count != 3 {
		t.Errorf("expected count 3, got %d", count)
	}

	if count := rl.Count("user2"); count != 0 {
		t.Errorf("expected count 0 for user2, got %d", count)
	}
}

// -- Eviction tests --

func TestEvictionRemovesExpiredWindows(t *testing.T) {
	// Use a very short window so timestamps expire quickly.
	// Set evictInterval=1 so eviction runs on every Allow() call.
	rl := newRateLimiterWithEvict(5, 50*time.Millisecond, 1)

	// Create windows for 10 users.
	for i := 0; i < 10; i++ {
		rl.Allow("expired-user-" + string(rune('a'+i)))
	}

	if got := rl.WindowCount(); got != 10 {
		t.Fatalf("expected 10 windows after setup, got %d", got)
	}

	// Wait for all windows to fully expire.
	time.Sleep(100 * time.Millisecond)

	// Trigger eviction by calling Allow with a brand-new user.
	rl.Allow("trigger-user")

	// All 10 expired windows should be removed. Only trigger-user remains.
	got := rl.WindowCount()
	if got != 1 {
		t.Errorf("expected 1 window after eviction (trigger-user), got %d", got)
	}
}

func TestEvictionDoesNotRemoveActiveWindows(t *testing.T) {
	// Short window, eviction on every call.
	rl := newRateLimiterWithEvict(5, 50*time.Millisecond, 1)

	// Create an active user.
	rl.Allow("active-user")

	// Immediately trigger eviction (window has not expired).
	rl.Allow("trigger-user")

	// Both active-user and trigger-user should still be present.
	got := rl.WindowCount()
	if got != 2 {
		t.Errorf("expected 2 windows (both active), got %d", got)
	}
}

func TestEvictionPartialExpiry(t *testing.T) {
	// Mix of expired and active windows.
	rl := newRateLimiterWithEvict(5, 50*time.Millisecond, 1)

	rl.Allow("expired-user")
	rl.Allow("another-expired")

	if got := rl.WindowCount(); got != 2 {
		t.Fatalf("expected 2 windows after setup, got %d", got)
	}

	// Wait for those windows to expire.
	time.Sleep(100 * time.Millisecond)

	// Now add an active user and trigger eviction.
	rl.Allow("active-user")

	// The 2 expired windows should be gone, active-user stays.
	got := rl.WindowCount()
	if got != 1 {
		t.Errorf("expected 1 window (active-user only), got %d", got)
	}

	// Verify active-user can still use its window.
	if count := rl.Count("active-user"); count != 1 {
		t.Errorf("expected active-user count=1, got %d", count)
	}
}

func TestEvictionKeepsMemoryBounded(t *testing.T) {
	// Simulate many unique keys with a short window.
	// evictInterval=10 so eviction triggers every 10th call.
	rl := newRateLimiterWithEvict(1, 30*time.Millisecond, 10)

	// Create 500 unique keys.
	for i := 0; i < 500; i++ {
		rl.Allow("key-" + string(rune(i)))
	}

	initialCount := rl.WindowCount()
	if initialCount != 500 {
		t.Fatalf("expected 500 windows after setup, got %d", initialCount)
	}

	// Wait for all to expire.
	time.Sleep(80 * time.Millisecond)

	// Make enough calls to trigger eviction multiple times.
	// Each call triggers eviction at interval=10, so 50 calls = 5 sweeps.
	for i := 0; i < 50; i++ {
		rl.Allow("cleanup-trigger-" + string(rune(i)))
	}

	finalCount := rl.WindowCount()

	// The 500 original expired windows should have been evicted.
	// Only the cleanup-trigger-* windows remain (at most 50).
	if finalCount > 50 {
		t.Errorf("expected at most 50 windows after eviction, got %d -- memory is not bounded", finalCount)
	}
}

func TestEvictionDisabledWhenIntervalZero(t *testing.T) {
	// evictInterval=0 disables lazy eviction.
	rl := newRateLimiterWithEvict(5, 50*time.Millisecond, 0)

	rl.Allow("user-a")
	rl.Allow("user-b")

	if got := rl.WindowCount(); got != 2 {
		t.Fatalf("expected 2 windows, got %d", got)
	}

	time.Sleep(100 * time.Millisecond)

	// Trigger calls -- but eviction is disabled, so expired windows stay.
	rl.Allow("user-c")

	// user-a and user-b should still be in the map even though expired.
	got := rl.WindowCount()
	if got != 3 {
		t.Errorf("expected 3 windows (eviction disabled), got %d", got)
	}
}

func TestWindowCountMethod(t *testing.T) {
	rl := NewRateLimiter(10, time.Hour)

	if got := rl.WindowCount(); got != 0 {
		t.Errorf("expected 0 windows on fresh limiter, got %d", got)
	}

	rl.Allow("u1")
	rl.Allow("u2")
	rl.Allow("u3")

	if got := rl.WindowCount(); got != 3 {
		t.Errorf("expected 3 windows, got %d", got)
	}
}
