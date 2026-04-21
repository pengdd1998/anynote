package testutil

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// DefaultTestJWTSecret is a valid JWT secret for tests (>= 16 chars).
const DefaultTestJWTSecret = "test-secret-minimum-16"

// GenerateTestToken creates a signed JWT with the given claims.
// Uses DefaultTestJWTSecret and HMAC-SHA256.
func GenerateTestToken(t *testing.T, userID, email, plan, tokenType string) string {
	t.Helper()
	claims := jwt.MapClaims{
		"user_id":    userID,
		"email":      email,
		"plan":       plan,
		"token_type": tokenType,
		"iat":        time.Now().Unix(),
		"exp":        time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, err := token.SignedString([]byte(DefaultTestJWTSecret))
	if err != nil {
		t.Fatalf("failed to sign test token: %v", err)
	}
	return tokenStr
}

// GenerateAccessToken creates a valid access token for the given user ID.
func GenerateAccessToken(t *testing.T, userID string) string {
	t.Helper()
	return GenerateTestToken(t, userID, "test@example.com", "free", "access")
}

// GenerateRefreshToken creates a valid refresh token for the given user ID.
func GenerateRefreshToken(t *testing.T, userID string) string {
	t.Helper()
	return GenerateTestToken(t, userID, "test@example.com", "free", "refresh")
}

// SetupTestRouter creates a chi.Mux with standard middleware for testing.
func SetupTestRouter() *chi.Mux {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.Recoverer)
	return r
}

// DecodeJSON decodes a JSON response body into the given value.
func DecodeJSON(t *testing.T, body bytes.Buffer, v interface{}) {
	t.Helper()
	if err := json.NewDecoder(&body).Decode(v); err != nil {
		t.Fatalf("failed to decode JSON response: %v", err)
	}
}

// RandomUUID returns a new random UUID string for testing.
func RandomUUID() string {
	return uuid.New().String()
}

// AssertHTTPError checks that the response has the expected status code
// and the error response contains the expected error code.
func AssertHTTPError(t *testing.T, rec *httptest.ResponseRecorder, wantStatus int, wantCode string) {
	t.Helper()
	if rec.Code != wantStatus {
		t.Errorf("expected status %d, got %d; body: %s", wantStatus, rec.Code, rec.Body.String())
	}
	if wantCode != "" {
		var errResp domain.ErrorResponse
		if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
			t.Fatalf("failed to decode error response: %v", err)
		}
		if errResp.Error.Code != wantCode {
			t.Errorf("error code = %q, want %q", errResp.Error.Code, wantCode)
		}
	}
}

// MakeAuthResponse creates a standard AuthResponse for test assertions.
func MakeAuthResponse(userID uuid.UUID) *domain.AuthResponse {
	return &domain.AuthResponse{
		AccessToken:  "access-token-" + userID.String(),
		RefreshToken: "refresh-token-" + userID.String(),
		ExpiresAt:    time.Now().Add(1 * time.Hour),
		User: domain.User{
			ID:        userID,
			Email:     "test@example.com",
			Username:  "testuser",
			Plan:      "free",
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
	}
}

// NewJSONRequest creates an httptest.Request with a JSON-encoded body and
// Content-Type header set to application/json.
func NewJSONRequest(t *testing.T, method, target string, payload interface{}) *http.Request {
	t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("failed to marshal JSON body: %v", err)
	}
	req := httptest.NewRequest(method, target, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	return req
}

// SetBearerToken adds an Authorization header with a Bearer token to the request.
func SetBearerToken(req *http.Request, token string) {
	req.Header.Set("Authorization", "Bearer "+token)
}

// AssertStatus is a lightweight status code assertion.
func AssertStatus(t *testing.T, rec *httptest.ResponseRecorder, want int) {
	t.Helper()
	if rec.Code != want {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, want, rec.Body.String())
	}
}
