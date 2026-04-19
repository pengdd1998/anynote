package handler

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestSecurityHeaders(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	wrapped := SecurityHeaders(handler)

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Host = "api.example.com"
	rec := httptest.NewRecorder()

	wrapped.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status: got %d, want %d", rec.Code, http.StatusOK)
	}

	tests := []struct {
		header   string
		expected string
	}{
		{"X-Content-Type-Options", "nosniff"},
		{"X-Frame-Options", "DENY"},
		{"Referrer-Policy", "strict-origin-when-cross-origin"},
		{"Permissions-Policy", "camera=(), microphone=(), geolocation=()"},
		{"Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'"},
		{"Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload"},
	}

	for _, tt := range tests {
		got := rec.Header().Get(tt.header)
		if got != tt.expected {
			t.Errorf("header %s: got %q, want %q", tt.header, got, tt.expected)
		}
	}
}

func TestSecurityHeaders_NoHSTSForLocalhost(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	wrapped := SecurityHeaders(handler)

	localhostVariants := []string{
		"localhost",
		"localhost:8080",
		"127.0.0.1",
		"127.0.0.1:3000",
		"[::1]",
		"[::1]:8080",
	}

	for _, host := range localhostVariants {
		t.Run(host, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/test", nil)
			req.Host = host
			rec := httptest.NewRecorder()

			wrapped.ServeHTTP(rec, req)

			if h := rec.Header().Get("Strict-Transport-Security"); h != "" {
				t.Errorf("HSTS should not be set for %s, got %q", host, h)
			}
		})
	}
}

func TestSecurityHeaders_HSTSForProductionHosts(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	wrapped := SecurityHeaders(handler)

	productionHosts := []string{
		"api.example.com",
		"anynote.app",
		"api.anynote.app:443",
	}

	expectedHSTS := "max-age=63072000; includeSubDomains; preload"

	for _, host := range productionHosts {
		t.Run(host, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/test", nil)
			req.Host = host
			rec := httptest.NewRecorder()

			wrapped.ServeHTTP(rec, req)

			got := rec.Header().Get("Strict-Transport-Security")
			if got != expectedHSTS {
				t.Errorf("HSTS for %s: got %q, want %q", host, got, expectedHSTS)
			}
		})
	}
}

func TestSecurityHeaders_PassesThroughToNextHandler(t *testing.T) {
	called := false
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusNoContent)
	})
	wrapped := SecurityHeaders(handler)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", nil)
	req.Host = "api.example.com"
	rec := httptest.NewRecorder()

	wrapped.ServeHTTP(rec, req)

	if !called {
		t.Error("next handler was not called")
	}
	if rec.Code != http.StatusNoContent {
		t.Errorf("status: got %d, want %d", rec.Code, http.StatusNoContent)
	}
}
