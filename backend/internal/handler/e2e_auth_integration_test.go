//go:build integration

package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// E2E Auth Integration: register -> login -> me -> refresh -> me -> rotation
// ---------------------------------------------------------------------------
// These tests exercise the full handler -> service -> repository -> PostgreSQL
// stack using testcontainers. No mocks are used.
// ---------------------------------------------------------------------------

// TestE2EIntegration_AuthLifecycle exercises the complete authentication
// lifecycle against a real database:
//  1. Register a new user -> 201
//  2. Login with the same credentials -> 200, tokens returned
//  3. GET /me with access token -> 200, correct email
//  4. Refresh the token -> 200, new tokens
//  5. GET /me with new access token -> 200
//  6. Old refresh token is invalidated after rotation -> 401
func TestE2EIntegration_AuthLifecycle(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	testEmail := fmt.Sprintf("authlifecycle-%s@example.com", uuid.New().String()[:8])
	testUsername := fmt.Sprintf("authuser_%s", uuid.New().String()[:8])
	testAuthKeyHash := []byte("integration-test-auth-key-hash-32b!")

	// -- Step 1: Register --
	t.Run("step1_register", func(t *testing.T) {
		body, _ := json.Marshal(domain.RegisterRequest{
			Email:        testEmail,
			Username:     testUsername,
			AuthKeyHash:  testAuthKeyHash,
			Salt:         []byte("testsalt-testsalt-testsalt-testsalt"),
			RecoveryKey:  []byte("testrecoverykey-testrecoverykey-test"),
			RecoverySalt: []byte("recoverysalt-recoverysalt-recover"),
		})

		resp, err := client.Post(srv.Server.URL+"/api/v1/auth/register", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("register: request failed: %v", err)
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
			t.Errorf("register: email = %q, want %q", authResp.User.Email, testEmail)
		}
		if authResp.User.Username != testUsername {
			t.Errorf("register: username = %q, want %q", authResp.User.Username, testUsername)
		}
		if authResp.User.Plan != "free" {
			t.Errorf("register: plan = %q, want %q", authResp.User.Plan, "free")
		}

		// Verify user exists in the database.
		var count int
		err = srv.Pool.QueryRow(context.Background(),
			"SELECT COUNT(*) FROM users WHERE email = $1", testEmail,
		).Scan(&count)
		if err != nil {
			t.Fatalf("register: db check: %v", err)
		}
		if count != 1 {
			t.Errorf("register: user count in db = %d, want 1", count)
		}
	})

	// -- Step 2: Login --
	var accessToken, refreshToken string

	t.Run("step2_login", func(t *testing.T) {
		body, _ := json.Marshal(domain.LoginRequest{
			Email:       testEmail,
			AuthKeyHash: testAuthKeyHash,
		})

		resp, err := client.Post(srv.Server.URL+"/api/v1/auth/login", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("login: request failed: %v", err)
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
			t.Errorf("login: email = %q, want %q", authResp.User.Email, testEmail)
		}

		accessToken = authResp.AccessToken
		refreshToken = authResp.RefreshToken
	})

	// -- Step 3: GET /me --
	t.Run("step3_me", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/auth/me", nil)
		if err != nil {
			t.Fatalf("me: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+accessToken)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("me: request failed: %v", err)
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

	// -- Step 4: Refresh token --
	var newAccessToken string

	t.Run("step4_refresh", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{
			"refresh_token": refreshToken,
		})

		resp, err := client.Post(srv.Server.URL+"/api/v1/auth/refresh", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("refresh: request failed: %v", err)
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

		newAccessToken = authResp.AccessToken
	})

	// -- Step 5: GET /me with new access token --
	t.Run("step5_me_after_refresh", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/auth/me", nil)
		if err != nil {
			t.Fatalf("me-after-refresh: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+newAccessToken)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("me-after-refresh: request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("me-after-refresh: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var user domain.User
		if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
			t.Fatalf("me-after-refresh: decode: %v", err)
		}
		if user.Email != testEmail {
			t.Errorf("me-after-refresh: email = %q, want %q", user.Email, testEmail)
		}
	})

	// -- Step 6: Verify old refresh token is invalidated --
	t.Run("step6_old_refresh_revoked", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{
			"refresh_token": refreshToken,
		})

		resp, err := client.Post(srv.Server.URL+"/api/v1/auth/refresh", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("old-refresh: request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusUnauthorized {
			t.Fatalf("old-refresh: status = %d, want %d (token should be revoked)", resp.StatusCode, http.StatusUnauthorized)
		}
	})
}

// TestE2EIntegration_AuthDuplicateEmail verifies that registering with an
// already-used email returns 409 Conflict.
func TestE2EIntegration_AuthDuplicateEmail(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	email := fmt.Sprintf("dup-%s@example.com", uuid.New().String()[:8])
	username1 := fmt.Sprintf("dup1_%s", uuid.New().String()[:8])
	username2 := fmt.Sprintf("dup2_%s", uuid.New().String()[:8])

	regBody := func(emailAddr, uname string) []byte {
		body, _ := json.Marshal(domain.RegisterRequest{
			Email:        emailAddr,
			Username:     uname,
			AuthKeyHash:  []byte("auth-key-hash-32-bytes-for-test!!"),
			Salt:         []byte("salt-value-salt-value-salt-value-s"),
			RecoveryKey:  []byte("recovery-key-recovery-key-recovery-"),
			RecoverySalt: []byte("recovery-salt-recovery-salt-recover"),
		})
		return body
	}

	// First registration should succeed.
	resp1, err := client.Post(srv.Server.URL+"/api/v1/auth/register", "application/json", bytes.NewReader(regBody(email, username1)))
	if err != nil {
		t.Fatalf("first register: request failed: %v", err)
	}
	resp1.Body.Close()
	if resp1.StatusCode != http.StatusCreated {
		t.Fatalf("first register: status = %d, want %d", resp1.StatusCode, http.StatusCreated)
	}

	// Second registration with same email should fail.
	resp2, err := client.Post(srv.Server.URL+"/api/v1/auth/register", "application/json", bytes.NewReader(regBody(email, username2)))
	if err != nil {
		t.Fatalf("duplicate register: request failed: %v", err)
	}
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusConflict {
		t.Fatalf("duplicate register: status = %d, want %d", resp2.StatusCode, http.StatusConflict)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(resp2.Body).Decode(&errResp); err != nil {
		t.Fatalf("duplicate register: decode: %v", err)
	}
	if errResp.Error.Code != "email_exists" {
		t.Errorf("duplicate register: error code = %q, want %q", errResp.Error.Code, "email_exists")
	}
}

// TestE2EIntegration_AuthInvalidLogin verifies that logging in with the wrong
// password returns 401 Unauthorized.
func TestE2EIntegration_AuthInvalidLogin(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	email := fmt.Sprintf("badlogin-%s@example.com", uuid.New().String()[:8])
	username := fmt.Sprintf("badlogin_%s", uuid.New().String()[:8])

	// Register the user first.
	regBody, _ := json.Marshal(domain.RegisterRequest{
		Email:        email,
		Username:     username,
		AuthKeyHash:  []byte("correct-auth-key-hash-32-bytes-long!"),
		Salt:         []byte("salt-value-salt-value-salt-value-s"),
		RecoveryKey:  []byte("recovery-key-recovery-key-recovery-"),
		RecoverySalt: []byte("recovery-salt-recovery-salt-recover"),
	})
	resp, err := client.Post(srv.Server.URL+"/api/v1/auth/register", "application/json", bytes.NewReader(regBody))
	if err != nil {
		t.Fatalf("register: request failed: %v", err)
	}
	resp.Body.Close()

	// Try to login with wrong auth key hash.
	loginBody, _ := json.Marshal(domain.LoginRequest{
		Email:       email,
		AuthKeyHash: []byte("wrong-auth-key-hash-32-bytes-long!!"),
	})

	resp, err = client.Post(srv.Server.URL+"/api/v1/auth/login", "application/json", bytes.NewReader(loginBody))
	if err != nil {
		t.Fatalf("bad login: request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("bad login: status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}

// TestE2EIntegration_AuthMeWithoutToken verifies that GET /me without an
// Authorization header returns 401.
func TestE2EIntegration_AuthMeWithoutToken(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	resp, err := srv.Server.Client().Get(srv.Server.URL + "/api/v1/auth/me")
	if err != nil {
		t.Fatalf("unauthenticated me: request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthenticated me: status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}
