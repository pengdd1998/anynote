package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5/middleware"
	"github.com/golang-jwt/jwt/v5"
)

// generateBenchToken creates a signed JWT access token for benchmark use.
func generateBenchToken(secret, userID string) string {
	claims := jwt.MapClaims{
		"user_id":    userID,
		"token_type": "access",
		"exp":        time.Now().Add(time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(secret))
	return tokenStr
}

// ---------------------------------------------------------------------------
// Benchmark: AuthMiddleware — valid token (full path through JWT parsing)
// ---------------------------------------------------------------------------

func BenchmarkAuthMiddleware_ValidToken(b *testing.B) {
	secret := "benchmark-secret-min-16"
	token := generateBenchToken(secret, "user-123-benchmark")

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mw := AuthMiddleware(secret)(next)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		rec := httptest.NewRecorder()
		mw.ServeHTTP(rec, req)
	}
}

// ---------------------------------------------------------------------------
// Benchmark: AuthMiddleware — invalid token (JWT parse fails)
// ---------------------------------------------------------------------------

func BenchmarkAuthMiddleware_InvalidToken(b *testing.B) {
	secret := "benchmark-secret-min-16"

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mw := AuthMiddleware(secret)(next)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.Header.Set("Authorization", "Bearer invalid-token-string")
		rec := httptest.NewRecorder()
		mw.ServeHTTP(rec, req)
	}
}

// ---------------------------------------------------------------------------
// Benchmark: AuthMiddleware — missing auth header (fastest rejection)
// ---------------------------------------------------------------------------

func BenchmarkAuthMiddleware_MissingToken(b *testing.B) {
	secret := "benchmark-secret-min-16"

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mw := AuthMiddleware(secret)(next)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		rec := httptest.NewRecorder()
		mw.ServeHTTP(rec, req)
	}
}

// ---------------------------------------------------------------------------
// Benchmark: MaxBodySize — request body within limits
// ---------------------------------------------------------------------------

func BenchmarkMaxBodySize_WithinLimit(b *testing.B) {
	body := bytes.Repeat([]byte("x"), 1024) // 1 KB body, well within 10 MB limit

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mw := MaxBodySize(DefaultMaxBodyBytes)(next)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest("POST", "/test", bytes.NewReader(body))
		rec := httptest.NewRecorder()
		mw.ServeHTTP(rec, req)
	}
}

// ---------------------------------------------------------------------------
// Benchmark: RequestLogger — middleware overhead with structured logging
// ---------------------------------------------------------------------------

func BenchmarkRequestLogger(b *testing.B) {
	// Wrap with RequestID middleware so RequestLogger can extract the ID.
	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	handler := middleware.RequestID(RequestLogger(inner))

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest("GET", "/api/v1/test", nil)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
	}
}
