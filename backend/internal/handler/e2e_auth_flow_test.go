package handler

import (
	"bytes"
	"context"
	"encoding/json"
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
// E2E Auth Flow: register -> login -> me -> refresh -> me
// ---------------------------------------------------------------------------

// TestE2EAuthFlow exercises the complete authentication lifecycle:
// register, login, fetch current user, refresh the token, and fetch again.
func TestE2EAuthFlow(t *testing.T) {
	userID := uuid.New()
	testEmail := "e2e@example.com"
	testUsername := "e2euser"
	testAuthKeyHash := []byte("e2e-auth-key-hash-32-bytes-long!!")

	// ------ helpers to build sub-responses ------

	makeAuthResp := func(accessToken, refreshToken string) *domain.AuthResponse {
		return &domain.AuthResponse{
			AccessToken:  accessToken,
			RefreshToken: refreshToken,
			ExpiresAt:    time.Now().Add(1 * time.Hour),
			User: domain.User{
				ID:        userID,
				Email:     testEmail,
				Username:  testUsername,
				Plan:      "free",
				CreatedAt: time.Now(),
				UpdatedAt: time.Now(),
			},
		}
	}

	// Use the same JWT secret that the middleware expects so tokens round-trip.
	jwtSecret := testJWTSecret

	// Generate a realistic access token that AuthMiddleware will accept.
	mintAccessToken := func() string {
		claims := jwt.MapClaims{
			"user_id": userID.String(),
			"email":   testEmail,
			"plan":    "free",
			"iat":     time.Now().Unix(),
			"exp":     time.Now().Add(1 * time.Hour).Unix(),
		}
		tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		s, _ := tok.SignedString([]byte(jwtSecret))
		return s
	}

	// Generate a refresh token (same shape, longer expiry).
	mintRefreshToken := func() string {
		claims := jwt.MapClaims{
			"user_id": userID.String(),
			"email":   testEmail,
			"plan":    "free",
			"iat":     time.Now().Unix(),
			"exp":     time.Now().Add(30 * 24 * time.Hour).Unix(),
		}
		tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		s, _ := tok.SignedString([]byte(jwtSecret))
		return s
	}

	// Track state across the flow so the mock services behave consistently.
	accessToken := mintAccessToken()
	refreshToken := mintRefreshToken()
	registered := false

	// ------ mock service ------

	authSvc := &mockAuthService{
		registerFn: func(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
			if req.Email != testEmail {
				t.Errorf("register: email = %q, want %q", req.Email, testEmail)
			}
			registered = true
			return makeAuthResp(accessToken, refreshToken), nil
		},
		loginFn: func(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error) {
			if !registered {
				t.Error("login called before register")
			}
			return makeAuthResp(accessToken, refreshToken), nil
		},
		refreshTokenFn: func(ctx context.Context, rt string) (*domain.AuthResponse, error) {
			if rt != refreshToken {
				t.Errorf("refresh: token = %q, want %q", rt, refreshToken)
			}
			// Mint a new access token for the refreshed session.
			newAccess := mintAccessToken()
			accessToken = newAccess // update captured variable for subsequent calls
			return makeAuthResp(newAccess, refreshToken), nil
		},
		getCurrentUserFn: func(ctx context.Context, id uuid.UUID) (*domain.User, error) {
			if id != userID {
				t.Errorf("me: userID = %v, want %v", id, userID)
			}
			return &domain.User{
				ID:        userID,
				Email:     testEmail,
				Username:  testUsername,
				Plan:      "free",
				CreatedAt: time.Now(),
				UpdatedAt: time.Now(),
			}, nil
		},
	}

	// ------ build router (matches production layout) ------

	h := &AuthHandler{authService: authSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)

	// Public auth routes.
	r.Route("/api/v1/auth", func(authR chi.Router) {
		authR.Post("/register", h.Register)
		authR.Post("/login", h.Login)
		authR.Post("/refresh", h.RefreshToken)
	})

	// Authenticated routes.
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(jwtSecret))
		authR.Get("/api/v1/auth/me", h.Me)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	client := server.Client()

	// ------ Step 1: POST /api/v1/auth/register (expect 201) ------

	t.Run("step1_register", func(t *testing.T) {
		body, _ := json.Marshal(domain.RegisterRequest{
			Email:       testEmail,
			Username:    testUsername,
			AuthKeyHash: testAuthKeyHash,
			Salt:        []byte("salt"),
			RecoveryKey: []byte("recovery"),
		})

		resp, err := client.Post(server.URL+"/api/v1/auth/register", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("register request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("register: status = %d, want %d", resp.StatusCode, http.StatusCreated)
		}

		var authResp domain.AuthResponse
		if err := json.NewDecoder(resp.Body).Decode(&authResp); err != nil {
			t.Fatalf("register: decode: %v", err)
		}
		if authResp.AccessToken == "" {
			t.Error("register: access_token is empty")
		}
		if authResp.RefreshToken == "" {
			t.Error("register: refresh_token is empty")
		}
		if authResp.User.Email != testEmail {
			t.Errorf("register: user.email = %q, want %q", authResp.User.Email, testEmail)
		}

		// Capture the tokens returned by the mock.
		accessToken = authResp.AccessToken
		refreshToken = authResp.RefreshToken
	})

	// ------ Step 2: POST /api/v1/auth/login (expect 200) ------

	t.Run("step2_login", func(t *testing.T) {
		body, _ := json.Marshal(domain.LoginRequest{
			Email:       testEmail,
			AuthKeyHash: testAuthKeyHash,
		})

		resp, err := client.Post(server.URL+"/api/v1/auth/login", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("login request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("login: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var authResp domain.AuthResponse
		if err := json.NewDecoder(resp.Body).Decode(&authResp); err != nil {
			t.Fatalf("login: decode: %v", err)
		}
		if authResp.AccessToken == "" {
			t.Error("login: access_token is empty")
		}
		if authResp.User.Email != testEmail {
			t.Errorf("login: user.email = %q, want %q", authResp.User.Email, testEmail)
		}

		// Use the fresh token for subsequent calls.
		accessToken = authResp.AccessToken
		refreshToken = authResp.RefreshToken
	})

	// ------ Step 3: GET /api/v1/auth/me with Bearer token (expect 200) ------

	t.Run("step3_me", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/auth/me", nil)
		if err != nil {
			t.Fatalf("me: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+accessToken)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("me request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("me: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var user domain.User
		if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
			t.Fatalf("me: decode: %v", err)
		}
		if user.Email != testEmail {
			t.Errorf("me: email = %q, want %q", user.Email, testEmail)
		}
		if user.Username != testUsername {
			t.Errorf("me: username = %q, want %q", user.Username, testUsername)
		}
	})

	// ------ Step 4: POST /api/v1/auth/refresh (expect 200) ------

	t.Run("step4_refresh", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{
			"refresh_token": refreshToken,
		})

		resp, err := client.Post(server.URL+"/api/v1/auth/refresh", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("refresh request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("refresh: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var authResp domain.AuthResponse
		if err := json.NewDecoder(resp.Body).Decode(&authResp); err != nil {
			t.Fatalf("refresh: decode: %v", err)
		}
		if authResp.AccessToken == "" {
			t.Error("refresh: new access_token is empty")
		}

		// Use the new access token for the final me call.
		accessToken = authResp.AccessToken
	})

	// ------ Step 5: GET /api/v1/auth/me with refreshed token (expect 200) ------

	t.Run("step5_me_after_refresh", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/auth/me", nil)
		if err != nil {
			t.Fatalf("me-after-refresh: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+accessToken)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("me-after-refresh request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("me-after-refresh: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var user domain.User
		if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
			t.Fatalf("me-after-refresh: decode: %v", err)
		}
		if user.ID != userID {
			t.Errorf("me-after-refresh: user.ID = %v, want %v", user.ID, userID)
		}
		if user.Email != testEmail {
			t.Errorf("me-after-refresh: email = %q, want %q", user.Email, testEmail)
		}
	})
}

// TestE2EAuthFlow_UnauthorizedMe verifies that /me returns 401 without a token.
func TestE2EAuthFlow_UnauthorizedMe(t *testing.T) {
	authSvc := &mockAuthService{}
	h := &AuthHandler{authService: authSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Get("/api/v1/auth/me", h.Me)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	resp, err := server.Client().Get(server.URL + "/api/v1/auth/me")
	if err != nil {
		t.Fatalf("unauthorized me request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthorized me: status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}

// TestE2EAuthFlow_ExpiredRefreshToken verifies that refresh with an invalid
// refresh token returns 401.
func TestE2EAuthFlow_ExpiredRefreshToken(t *testing.T) {
	authSvc := &mockAuthService{
		refreshTokenFn: func(ctx context.Context, rt string) (*domain.AuthResponse, error) {
			return nil, service.ErrInvalidCredentials
		},
	}

	h := &AuthHandler{authService: authSvc}
	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Post("/api/v1/auth/refresh", h.RefreshToken)

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(map[string]string{
		"refresh_token": "expired-or-invalid-token",
	})

	resp, err := server.Client().Post(server.URL+"/api/v1/auth/refresh", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("expired refresh request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expired refresh: status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}

// TestE2EAuthFlow_RegisterThenDuplicateEmail verifies that registering the
// same email twice returns 409.
func TestE2EAuthFlow_RegisterThenDuplicateEmail(t *testing.T) {
	callCount := 0
	authSvc := &mockAuthService{
		registerFn: func(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
			callCount++
			if callCount == 1 {
				return makeAuthResponse(uuid.New()), nil
			}
			return nil, service.ErrEmailExists
		},
	}

	h := &AuthHandler{authService: authSvc}
	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Post("/api/v1/auth/register", h.Register)

	server := httptest.NewServer(r)
	defer server.Close()

	regBody, _ := json.Marshal(domain.RegisterRequest{
		Email:       "dup@example.com",
		Username:    "dupuser",
		AuthKeyHash: []byte("hash"),
	})

	// First registration should succeed.
	resp1, err := server.Client().Post(server.URL+"/api/v1/auth/register", "application/json", bytes.NewReader(regBody))
	if err != nil {
		t.Fatalf("first register request: %v", err)
	}
	resp1.Body.Close()
	if resp1.StatusCode != http.StatusCreated {
		t.Fatalf("first register: status = %d, want %d", resp1.StatusCode, http.StatusCreated)
	}

	// Second registration with same email should fail.
	resp2, err := server.Client().Post(server.URL+"/api/v1/auth/register", "application/json", bytes.NewReader(regBody))
	if err != nil {
		t.Fatalf("duplicate register request: %v", err)
	}
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusConflict {
		t.Fatalf("duplicate register: status = %d, want %d", resp2.StatusCode, http.StatusConflict)
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(resp2.Body).Decode(&errResp)
	if errResp.Error != "email_exists" {
		t.Errorf("duplicate register: error = %q, want %q", errResp.Error, "email_exists")
	}
}
