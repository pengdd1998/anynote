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
