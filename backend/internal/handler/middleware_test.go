package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestAuthMiddlewareValidToken(t *testing.T) {
	secret := "test-secret"

	// Generate a valid token
	claims := jwt.MapClaims{
		"user_id": "550e8400-e29b-41d4-a716-446655440000",
		"email":   "test@example.com",
		"plan":    "free",
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(secret))

	// Create test handler
	called := false
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		userID := getUserID(r.Context())
		if userID == "" {
			t.Error("user_id should be set in context")
		}
		w.WriteHeader(http.StatusOK)
	})

	middleware := AuthMiddleware(secret)(next)

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)
	rec := httptest.NewRecorder()

	middleware.ServeHTTP(rec, req)

	if !called {
		t.Error("next handler should be called")
	}
	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}
}

func TestAuthMiddlewareMissingToken(t *testing.T) {
	secret := "test-secret"

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next should not be called without token")
	})

	middleware := AuthMiddleware(secret)(next)

	req := httptest.NewRequest("GET", "/test", nil)
	rec := httptest.NewRecorder()

	middleware.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestAuthMiddlewareInvalidToken(t *testing.T) {
	secret := "test-secret"

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next should not be called with invalid token")
	})

	middleware := AuthMiddleware(secret)(next)

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", "Bearer invalid-token")
	rec := httptest.NewRecorder()

	middleware.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestAuthMiddleware_NoBearerPrefix(t *testing.T) {
	secret := "test-secret"

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next should not be called without Bearer prefix")
	})

	middleware := AuthMiddleware(secret)(next)

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", "Basic dXNlcjpwYXNz")
	rec := httptest.NewRecorder()

	middleware.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}

	var errResp map[string]interface{}
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp["error"] != "invalid_authorization" {
		t.Errorf("error = %v, want invalid_authorization", errResp["error"])
	}
}

func TestAuthMiddleware_TokenMissingUserID(t *testing.T) {
	secret := "test-secret"

	// Create a valid JWT but without user_id claim.
	claims := jwt.MapClaims{
		"email": "test@example.com",
		"plan":  "free",
		"iat":   time.Now().Unix(),
		"exp":   time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(secret))

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next should not be called when user_id is missing from claims")
	})

	middleware := AuthMiddleware(secret)(next)

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)
	rec := httptest.NewRecorder()

	middleware.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}

	var errResp map[string]interface{}
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp["error"] != "invalid_claims" {
		t.Errorf("error = %v, want invalid_claims", errResp["error"])
	}
}

func TestAuthMiddleware_ExpiredToken(t *testing.T) {
	secret := "test-secret"

	// Create an expired JWT.
	claims := jwt.MapClaims{
		"user_id": "550e8400-e29b-41d4-a716-446655440000",
		"email":   "test@example.com",
		"plan":    "free",
		"exp":     time.Now().Add(-1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(secret))

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next should not be called with expired token")
	})

	middleware := AuthMiddleware(secret)(next)

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)
	rec := httptest.NewRecorder()

	middleware.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}
