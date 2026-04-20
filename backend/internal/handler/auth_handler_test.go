package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock AuthService
// ---------------------------------------------------------------------------

type mockAuthService struct {
	registerFn       func(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error)
	loginFn          func(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error)
	refreshTokenFn   func(ctx context.Context, refreshToken string) (*domain.AuthResponse, error)
	getCurrentUserFn func(ctx context.Context, userID uuid.UUID) (*domain.User, error)
	deleteAccountFn  func(ctx context.Context, userID uuid.UUID, authKeyHash []byte) error
}

func (m *mockAuthService) Register(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
	if m.registerFn != nil {
		return m.registerFn(ctx, req)
	}
	return nil, errors.New("not implemented")
}

func (m *mockAuthService) Login(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error) {
	if m.loginFn != nil {
		return m.loginFn(ctx, req)
	}
	return nil, errors.New("not implemented")
}

func (m *mockAuthService) RefreshToken(ctx context.Context, refreshToken string) (*domain.AuthResponse, error) {
	if m.refreshTokenFn != nil {
		return m.refreshTokenFn(ctx, refreshToken)
	}
	return nil, errors.New("not implemented")
}

func (m *mockAuthService) GetCurrentUser(ctx context.Context, userID uuid.UUID) (*domain.User, error) {
	if m.getCurrentUserFn != nil {
		return m.getCurrentUserFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockAuthService) DeleteAccount(ctx context.Context, userID uuid.UUID, authKeyHash []byte) error {
	if m.deleteAccountFn != nil {
		return m.deleteAccountFn(ctx, userID, authKeyHash)
	}
	return errors.New("not implemented")
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const testJWTSecret = "test-jwt-secret-for-handler-tests"

// setupAuthRouter creates a chi router wired with the AuthHandler and the
// AuthMiddleware, matching the real route layout.
func setupAuthRouter(svc *mockAuthService) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestLogger)

	h := &AuthHandler{authService: svc}

	r.Route("/api/v1/auth", func(r chi.Router) {
		r.Post("/register", h.Register)
		r.Post("/login", h.Login)
		r.Post("/refresh", h.RefreshToken)
	})

	// Authenticated routes
	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		r.Get("/api/v1/auth/me", h.Me)
		r.Delete("/api/v1/auth/account", h.DeleteAccount)
	})

	return r
}

// generateTestToken creates a valid access JWT for the given user ID.
func generateTestToken(userID string) string {
	claims := jwt.MapClaims{
		"user_id":    userID,
		"email":      "test@example.com",
		"plan":       "free",
		"token_type": "access",
		"iat":        time.Now().Unix(),
		"exp":        time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(testJWTSecret))
	return tokenStr
}

// generateTestRefreshToken creates a valid refresh JWT for the given user ID.
func generateTestRefreshToken(userID string) string {
	claims := jwt.MapClaims{
		"user_id":    userID,
		"email":      "test@example.com",
		"plan":       "free",
		"token_type": "refresh",
		"iat":        time.Now().Unix(),
		"exp":        time.Now().Add(30 * 24 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(testJWTSecret))
	return tokenStr
}

func makeAuthResponse(userID uuid.UUID) *domain.AuthResponse {
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

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/auth/register
// ---------------------------------------------------------------------------

func TestAuthHandler_Register_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		registerFn: func(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
			return makeAuthResponse(userID), nil
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice",
		AuthKeyHash: []byte("hash"),
		Salt:        []byte("salt"),
		RecoveryKey: []byte("recovery"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusCreated, rec.Body.String())
	}

	var resp domain.AuthResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.AccessToken == "" {
		t.Error("AccessToken should not be empty")
	}
	if resp.RefreshToken == "" {
		t.Error("RefreshToken should not be empty")
	}
	if resp.User.Email != "test@example.com" {
		t.Errorf("User.Email = %q, want %q", resp.User.Email, "test@example.com")
	}
	if resp.User.ID != userID {
		t.Errorf("User.ID = %v, want %v", resp.User.ID, userID)
	}
}

func TestAuthHandler_Register_DuplicateEmail(t *testing.T) {
	svc := &mockAuthService{
		registerFn: func(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
			return nil, service.ErrEmailExists
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice",
		AuthKeyHash: []byte("hash"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusConflict, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "email_exists" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "email_exists")
	}
}

func TestAuthHandler_Register_DuplicateUsername(t *testing.T) {
	svc := &mockAuthService{
		registerFn: func(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
			return nil, service.ErrUsernameExists
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice",
		AuthKeyHash: []byte("hash"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusConflict, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "username_exists" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "username_exists")
	}
}

func TestAuthHandler_Register_InvalidBody(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestAuthHandler_Register_MissingFields(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	// Send empty email and username.
	body, _ := json.Marshal(domain.RegisterRequest{
		Email:    "",
		Username: "",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnprocessableEntity, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/auth/login
// ---------------------------------------------------------------------------

func TestAuthHandler_Login_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		loginFn: func(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error) {
			return makeAuthResponse(userID), nil
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.LoginRequest{
		Email:       "alice@example.com",
		AuthKeyHash: []byte("hash"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.AuthResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.AccessToken == "" {
		t.Error("AccessToken should not be empty")
	}
	if resp.User.Email != "test@example.com" {
		t.Errorf("User.Email = %q, want %q", resp.User.Email, "test@example.com")
	}
}

func TestAuthHandler_Login_WrongCredentials(t *testing.T) {
	svc := &mockAuthService{
		loginFn: func(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error) {
			return nil, service.ErrInvalidCredentials
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.LoginRequest{
		Email:       "alice@example.com",
		AuthKeyHash: []byte("wrong"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnauthorized, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "invalid_credentials" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "invalid_credentials")
	}
}

func TestAuthHandler_Login_InvalidBody(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader([]byte("{bad")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestAuthHandler_Login_MissingFields(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.LoginRequest{
		Email:       "",
		AuthKeyHash: nil,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnprocessableEntity, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/auth/refresh
// ---------------------------------------------------------------------------

func TestAuthHandler_RefreshToken_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		refreshTokenFn: func(ctx context.Context, refreshToken string) (*domain.AuthResponse, error) {
			return makeAuthResponse(userID), nil
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(map[string]string{
		"refresh_token": "valid-refresh-token",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.AuthResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.AccessToken == "" {
		t.Error("AccessToken should not be empty")
	}
}

func TestAuthHandler_RefreshToken_Expired(t *testing.T) {
	svc := &mockAuthService{
		refreshTokenFn: func(ctx context.Context, refreshToken string) (*domain.AuthResponse, error) {
			return nil, errors.New("invalid or expired refresh token")
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(map[string]string{
		"refresh_token": "expired-token",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnauthorized, rec.Body.String())
	}
}

func TestAuthHandler_RefreshToken_InvalidBody(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/auth/me
// ---------------------------------------------------------------------------

func TestAuthHandler_Me_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		getCurrentUserFn: func(ctx context.Context, id uuid.UUID) (*domain.User, error) {
			if id != userID {
				t.Errorf("userID = %v, want %v", id, userID)
			}
			return &domain.User{
				ID:        userID,
				Email:     "alice@example.com",
				Username:  "alice",
				Plan:      "pro",
				CreatedAt: time.Now(),
				UpdatedAt: time.Now(),
			}, nil
		},
	}

	router := setupAuthRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var user domain.User
	if err := json.NewDecoder(rec.Body).Decode(&user); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if user.Email != "alice@example.com" {
		t.Errorf("Email = %q, want %q", user.Email, "alice@example.com")
	}
	if user.Plan != "pro" {
		t.Errorf("Plan = %q, want %q", user.Plan, "pro")
	}
}

func TestAuthHandler_Me_Unauthorized_NoToken(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestAuthHandler_Me_UserNotFound(t *testing.T) {
	svc := &mockAuthService{
		getCurrentUserFn: func(ctx context.Context, id uuid.UUID) (*domain.User, error) {
			return nil, errors.New("user not found")
		},
	}

	router := setupAuthRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(uuid.New().String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusNotFound, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: JWT token structure in responses
// ---------------------------------------------------------------------------

func TestAuthHandler_Register_InternalError(t *testing.T) {
	svc := &mockAuthService{
		registerFn: func(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
			return nil, errors.New("unexpected database failure")
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice",
		AuthKeyHash: []byte("hash"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "internal_error" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "internal_error")
	}
}

func TestAuthHandler_Login_InternalError(t *testing.T) {
	svc := &mockAuthService{
		loginFn: func(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error) {
			return nil, errors.New("unexpected database failure")
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.LoginRequest{
		Email:       "alice@example.com",
		AuthKeyHash: []byte("hash"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "internal_error" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "internal_error")
	}
}

// ---------------------------------------------------------------------------
// Tests: Register — missing auth_key_hash
// ---------------------------------------------------------------------------

func TestAuthHandler_Register_MissingAuthKeyHash(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice",
		AuthKeyHash: nil, // empty
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

// ---------------------------------------------------------------------------
// Tests: Login — missing auth_key_hash
// ---------------------------------------------------------------------------

func TestAuthHandler_Login_MissingAuthKeyHash(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.LoginRequest{
		Email:       "alice@example.com",
		AuthKeyHash: nil, // empty
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

// ---------------------------------------------------------------------------
// Tests: Register — invalid email format
// ---------------------------------------------------------------------------

func TestAuthHandler_Register_InvalidEmail(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.RegisterRequest{
		Email:       "not-an-email",
		Username:    "alice",
		AuthKeyHash: []byte("hash"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnprocessableEntity, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: Login — invalid email format
// ---------------------------------------------------------------------------

func TestAuthHandler_Login_InvalidEmail(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.LoginRequest{
		Email:       "not-an-email",
		AuthKeyHash: []byte("hash"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnprocessableEntity, rec.Body.String())
	}
}

func TestAuthHandler_Register_ResponseStructure(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		registerFn: func(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
			return makeAuthResponse(userID), nil
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice",
		AuthKeyHash: []byte("hash"),
		Salt:        []byte("salt"),
		RecoveryKey: []byte("recovery"),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	// Decode into raw map to verify JSON field names.
	var raw map[string]interface{}
	if err := json.NewDecoder(rec.Body).Decode(&raw); err != nil {
		t.Fatalf("decode raw response: %v", err)
	}

	// Verify top-level fields exist.
	for _, field := range []string{"access_token", "refresh_token", "expires_at", "user"} {
		if _, ok := raw[field]; !ok {
			t.Errorf("missing field %q in response", field)
		}
	}

	// Verify user sub-object.
	userMap, ok := raw["user"].(map[string]interface{})
	if !ok {
		t.Fatal("user field should be an object")
	}
	for _, field := range []string{"id", "email", "username", "plan"} {
		if _, ok := userMap[field]; !ok {
			t.Errorf("missing field user.%q in response", field)
		}
	}
}

// ---------------------------------------------------------------------------
// Tests: DELETE /api/v1/auth/account
// ---------------------------------------------------------------------------

func TestAuthHandler_DeleteAccount_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		deleteAccountFn: func(ctx context.Context, id uuid.UUID, hash []byte) error {
			return nil
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(map[string]interface{}{
		"auth_key_hash": []byte("correct-hash"),
	})

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/auth/account", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp["status"] != "deleted" {
		t.Errorf("status = %q, want %q", resp["status"], "deleted")
	}
}

func TestAuthHandler_DeleteAccount_WrongPassword(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		deleteAccountFn: func(ctx context.Context, id uuid.UUID, hash []byte) error {
			return service.ErrInvalidCredentials
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(map[string]interface{}{
		"auth_key_hash": []byte("wrong-hash"),
	})

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/auth/account", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnauthorized, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "invalid_credentials" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "invalid_credentials")
	}
}

func TestAuthHandler_DeleteAccount_Unauthorized(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	body, _ := json.Marshal(map[string]interface{}{
		"auth_key_hash": []byte("some-hash"),
	})

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/auth/account", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	// No Authorization header.
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnauthorized, rec.Body.String())
	}
}

func TestAuthHandler_DeleteAccount_MissingAuthKeyHash(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	body, _ := json.Marshal(map[string]interface{}{})

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/auth/account", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

func TestAuthHandler_DeleteAccount_InvalidBody(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/auth/account", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

func TestAuthHandler_DeleteAccount_UserNotFound(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		deleteAccountFn: func(ctx context.Context, id uuid.UUID, hash []byte) error {
			return service.ErrUserNotFound
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(map[string]interface{}{
		"auth_key_hash": []byte("some-hash"),
	})

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/auth/account", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusNotFound, rec.Body.String())
	}
}

func TestAuthHandler_DeleteAccount_InternalError(t *testing.T) {
	userID := uuid.New()
	svc := &mockAuthService{
		deleteAccountFn: func(ctx context.Context, id uuid.UUID, hash []byte) error {
			return errors.New("database connection lost")
		},
	}

	router := setupAuthRouter(svc)

	body, _ := json.Marshal(map[string]interface{}{
		"auth_key_hash": []byte("some-hash"),
	})

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/auth/account", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error.Code != "internal_error" {
		t.Errorf("error type = %q, want %q", errResp.Error.Code, "internal_error")
	}
}
