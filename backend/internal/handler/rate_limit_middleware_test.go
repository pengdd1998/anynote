package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/anynote/backend/internal/service"
)

func TestRateLimitMiddleware_AllowsUnderLimit(t *testing.T) {
	limiter := service.NewRateLimiter(3, time.Minute)
	mw := RateLimitMiddleware(limiter, IPKeyFunc, time.Minute)

	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "1.2.3.4:1234"
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("request %d: status = %d, want %d", i+1, w.Code, http.StatusOK)
		}
	}
}

func TestRateLimitMiddleware_BlocksOverLimit(t *testing.T) {
	limiter := service.NewRateLimiter(2, time.Minute)
	mw := RateLimitMiddleware(limiter, IPKeyFunc, time.Minute)

	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	// Exhaust the limit
	for i := 0; i < 2; i++ {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "5.6.7.8:1234"
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, req)
	}

	// Next request should be blocked
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "5.6.7.8:1234"
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("over-limit status = %d, want %d", w.Code, http.StatusTooManyRequests)
	}
}

func TestRateLimitMiddleware_SetsRetryAfterHeader(t *testing.T) {
	limiter := service.NewRateLimiter(1, time.Minute)
	mw := RateLimitMiddleware(limiter, IPKeyFunc, time.Minute)

	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	// First request passes
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "9.8.7.6:1234"
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	// Second request blocked
	req = httptest.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "9.8.7.6:1234"
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	retryAfter := w.Header().Get("Retry-After")
	if retryAfter != "60" {
		t.Errorf("Retry-After = %q, want %q", retryAfter, "60")
	}
}

func TestRateLimitMiddleware_DifferentKeysIsolated(t *testing.T) {
	limiter := service.NewRateLimiter(1, time.Minute)
	mw := RateLimitMiddleware(limiter, IPKeyFunc, time.Minute)

	handler := mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	// First IP
	req1 := httptest.NewRequest(http.MethodGet, "/test", nil)
	req1.RemoteAddr = "1.1.1.1:1234"
	w1 := httptest.NewRecorder()
	handler.ServeHTTP(w1, req1)

	// Second IP should have its own limit
	req2 := httptest.NewRequest(http.MethodGet, "/test", nil)
	req2.RemoteAddr = "2.2.2.2:1234"
	w2 := httptest.NewRecorder()
	handler.ServeHTTP(w2, req2)

	if w2.Code != http.StatusOK {
		t.Errorf("different IP status = %d, want %d", w2.Code, http.StatusOK)
	}
}

func TestUserIDKeyFunc(t *testing.T) {
	t.Run("with_user_id", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "1.2.3.4:1234"
		ctx := context.WithValue(req.Context(), userIDKey, "user-123")
		req = req.WithContext(ctx)

		key := UserIDKeyFunc(req)
		if key != "user:user-123" {
			t.Errorf("key = %q, want %q", key, "user:user-123")
		}
	})

	t.Run("without_user_id_falls_back_to_ip", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/test", nil)
		req.RemoteAddr = "1.2.3.4:1234"

		key := UserIDKeyFunc(req)
		if key != "ip:1.2.3.4:1234" {
			t.Errorf("key = %q, want %q", key, "ip:1.2.3.4:1234")
		}
	})
}

func TestIPKeyFunc(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.RemoteAddr = "10.0.0.1:5678"

	key := IPKeyFunc(req)
	if key != "10.0.0.1:5678" {
		t.Errorf("key = %q, want %q", key, "10.0.0.1:5678")
	}
}
