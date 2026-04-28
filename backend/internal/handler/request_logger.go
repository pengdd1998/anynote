package handler

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5/middleware"
)

// skippedPaths are paths for which request logging is suppressed to reduce noise.
var skippedPaths = map[string]bool{
	"/health":  true,
	"/ready":   true,
	"/metrics": true,
}

// RequestLogger returns middleware that logs each request with structured fields.
// It deliberately excludes request and response bodies for privacy (CLAUDE.md rule).
// Noisy endpoints (/health, /ready, /metrics) are skipped to keep logs useful.
func RequestLogger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip logging for noisy endpoints.
		if skippedPaths[r.URL.Path] {
			next.ServeHTTP(w, r)
			return
		}

		start := time.Now()
		rw := newInstrumentedResponseWriter(w)

		// Set the X-Request-ID response header so clients can correlate errors.
		requestID := middleware.GetReqID(r.Context())
		if requestID != "" {
			rw.Header().Set("X-Request-ID", requestID)
		}

		next.ServeHTTP(rw, r)

		duration := time.Since(start)
		userID := getUserID(r.Context())

		attrs := []any{
			"method", r.Method,
			"path", r.URL.Path,
			"status", rw.Status(),
			"duration_ms", duration.Milliseconds(),
			"trace_id", requestID,
		}
		if userID != "" {
			attrs = append(attrs, "user_id", userID)
		}

		// Log level: INFO for success, WARN for client errors, ERROR for server errors.
		if rw.Status() >= 500 {
			slog.Error("request completed", attrs...)
		} else if rw.Status() >= 400 {
			slog.Warn("request completed", attrs...)
		} else {
			slog.Info("request completed", attrs...)
		}
	})
}
