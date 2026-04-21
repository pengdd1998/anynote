package service

import (
	"sync"
	"time"
)

// RateLimiter implements per-user rate limiting using a sliding window.
// Expired windows are evicted lazily to prevent unbounded memory growth.
type RateLimiter struct {
	mu             sync.Mutex
	windows        map[string]*slidingWindow
	limit          int           // Max requests per window
	windowDuration time.Duration // Window size
	callCount      int           // Tracks calls to trigger periodic eviction
	evictInterval  int           // Run eviction every Nth Allow() call (0 = never)
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
		evictInterval:  100, // evict every 100th call
	}
}

// newRateLimiterWithEvict creates a rate limiter with a custom eviction interval.
// An interval of 0 disables lazy eviction entirely.
func newRateLimiterWithEvict(limit int, window time.Duration, evictInterval int) *RateLimiter {
	return &RateLimiter{
		windows:        make(map[string]*slidingWindow),
		limit:          limit,
		windowDuration: window,
		evictInterval:  evictInterval,
	}
}

// Allow checks if a request from userID is allowed.
func (r *RateLimiter) Allow(userID string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := time.Now()
	windowStart := now.Add(-r.windowDuration)

	// Lazy eviction: every Nth call, sweep a sample of keys.
	r.callCount++
	if r.evictInterval > 0 && r.callCount%r.evictInterval == 0 {
		r.evictLocked(now)
	}

	w, exists := r.windows[userID]
	if !exists {
		w = &slidingWindow{timestamps: []time.Time{}}
		r.windows[userID] = w
	}

	// Remove expired entries within this user's window.
	valid := w.timestamps[:0]
	for _, t := range w.timestamps {
		if t.After(windowStart) {
			valid = append(valid, t)
		}
	}
	w.timestamps = valid

	// If all timestamps expired and window is now empty, check if we can
	// prune the key entirely (avoids leaving empty-window entries in the map).
	if len(w.timestamps) == 0 && !exists {
		// Just created this window and haven't added the current request yet;
		// keep it so the request gets recorded below.
	}

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

// WindowCount returns the number of tracked keys in the windows map.
// Useful for testing eviction behavior.
func (r *RateLimiter) WindowCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.windows)
}

// evictLocked removes windows whose timestamps are all expired.
// Must be called with r.mu held.
func (r *RateLimiter) evictLocked(now time.Time) {
	windowStart := now.Add(-r.windowDuration)

	// If the map is small, scan everything. Otherwise sample a subset.
	const fullScanThreshold = 500
	if len(r.windows) <= fullScanThreshold {
		for key, w := range r.windows {
			if r.isWindowExpired(w, windowStart) {
				delete(r.windows, key)
			}
		}
		return
	}

	// Sample up to sampleSize random keys for eviction.
	// Collect keys lazily and stop early once we've checked enough.
	const sampleSize = 200
	checked := 0
	for key := range r.windows {
		if checked >= sampleSize {
			break
		}
		if r.isWindowExpired(r.windows[key], windowStart) {
			delete(r.windows, key)
		}
		checked++
	}
}

// isWindowExpired returns true if all timestamps in the window are outside
// the current window (i.e., the key can be safely evicted).
// Must be called with r.mu held.
func (r *RateLimiter) isWindowExpired(w *slidingWindow, windowStart time.Time) bool {
	for _, t := range w.timestamps {
		if t.After(windowStart) {
			return false
		}
	}
	return true
}
