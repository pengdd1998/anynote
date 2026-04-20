package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/anynote/backend/internal/service"
)

// RateLimitMiddleware creates a chi-compatible middleware that rate-limits requests.
// limiter is the service rate limiter.
// keyFunc extracts the rate limit key from the request (e.g., IP or user ID).
// window is used to set the Retry-After header.
func RateLimitMiddleware(limiter *service.RateLimiter, keyFunc func(r *http.Request) string, window time.Duration) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := keyFunc(r)
			if !limiter.Allow(key) {
				w.Header().Set("Retry-After", strconv.Itoa(int(window.Seconds())))
				writeError(w, r, http.StatusTooManyRequests, "rate_limit_exceeded", "Too many requests. Please try again later.")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// IPKeyFunc extracts the client IP from the request for rate limiting.
func IPKeyFunc(r *http.Request) string {
	return r.RemoteAddr
}

// UserIDKeyFunc extracts the user ID from context for rate limiting.
// Falls back to IP if no user ID is available.
func UserIDKeyFunc(r *http.Request) string {
	if uid := getUserID(r.Context()); uid != "" {
		return "user:" + uid
	}
	return "ip:" + r.RemoteAddr
}
