package handler

import (
	"net/http"
	"strings"
)

// SecurityHeaders adds security-related headers to all HTTP responses.
// It is designed to be used as global middleware on the router so that
// every response includes hardened browser-facing headers.
func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Prevent MIME type sniffing
		w.Header().Set("X-Content-Type-Options", "nosniff")
		// Prevent framing (API server should never be embedded)
		w.Header().Set("X-Frame-Options", "DENY")
		// Control referrer information
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		// Disable browser features not needed by an API
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		// CSP for API-only server: no content sources, no framing
		w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		// HSTS - only in production (skip for localhost / loopback)
		if !isLocalhost(r.Host) {
			w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload")
		}

		next.ServeHTTP(w, r)
	})
}

// isLocalhost returns true if the host points to the local machine.
func isLocalhost(host string) bool {
	if host == "localhost" || host == "127.0.0.1" {
		return true
	}
	if strings.HasPrefix(host, "localhost:") || strings.HasPrefix(host, "127.0.0.1:") {
		return true
	}
	// Handle [::1] and [::1]:port IPv6 loopback variants
	trimmed := strings.TrimPrefix(strings.TrimSuffix(host, "]"), "[")
	if trimmed == "::1" {
		return true
	}
	if strings.HasPrefix(host, "[::1]:") {
		return true
	}
	return false
}
