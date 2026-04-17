package service

import (
	"sync"
	"time"
)

// RateLimiter implements per-user rate limiting using a sliding window.
type RateLimiter struct {
	mu       sync.Mutex
	windows  map[string]*slidingWindow
	limit    int           // Max requests per window
	windowDuration time.Duration // Window size
}

type slidingWindow struct {
	timestamps []time.Time
}

// NewRateLimiter creates a new rate limiter.
// limit: max requests per window
// window: time window duration (e.g., 24h for daily limits)
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		windows:        make(map[string]*slidingWindow),
		limit:          limit,
		windowDuration: window,
	}
}

// Allow checks if a request from userID is allowed.
func (r *RateLimiter) Allow(userID string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := time.Now()
	windowStart := now.Add(-r.windowDuration)

	w, exists := r.windows[userID]
	if !exists {
		w = &slidingWindow{timestamps: []time.Time{}}
		r.windows[userID] = w
	}

	// Remove expired entries
	valid := w.timestamps[:0]
	for _, t := range w.timestamps {
		if t.After(windowStart) {
			valid = append(valid, t)
		}
	}
	w.timestamps = valid

	// Check limit
	if len(w.timestamps) >= r.limit {
		return false
	}

	// Record this request
	w.timestamps = append(w.timestamps, now)
	return true
}

// Count returns the current count for a user.
func (r *RateLimiter) Count(userID string) int {
	r.mu.Lock()
	defer r.mu.Unlock()

	w, exists := r.windows[userID]
	if !exists {
		return 0
	}

	now := time.Now()
	windowStart := now.Add(-r.windowDuration)

	count := 0
	for _, t := range w.timestamps {
		if t.After(windowStart) {
			count++
		}
	}
	return count
}
