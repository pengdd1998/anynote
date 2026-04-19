package medium

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"strings"
	"testing"

	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
)

func newTestKey() []byte {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		panic(err)
	}
	return key
}

// ---------------------------------------------------------------------------
// Name
// ---------------------------------------------------------------------------

func TestAdapter_Name(t *testing.T) {
	a := NewAdapter("client-id", "client-secret", "https://redirect")
	if a.Name() != "medium" {
		t.Errorf("Name() = %q, want %q", a.Name(), "medium")
	}
}

// ---------------------------------------------------------------------------
// StartAuth
// ---------------------------------------------------------------------------

func TestAdapter_StartAuth(t *testing.T) {
	a := NewAdapter("test-client-id", "test-secret", "https://example.com/callback")
	session, payload, err := a.StartAuth(context.Background(), nil)
	if err != nil {
		t.Fatalf("StartAuth: %v", err)
	}

	if session == nil {
		t.Fatal("session is nil")
	}
	if session.AuthRef == "" {
		t.Error("AuthRef is empty")
	}

	var data map[string]string
	if err := json.Unmarshal(payload, &data); err != nil {
		t.Fatalf("unmarshal payload: %v", err)
	}

	if data["auth_type"] != "oauth2_redirect" {
		t.Errorf("auth_type = %q, want %q", data["auth_type"], "oauth2_redirect")
	}

	authURL := data["auth_url"]
	if !strings.Contains(authURL, "client_id=test-client-id") {
		t.Errorf("auth_url should contain client_id, got %q", authURL)
	}
	if !strings.Contains(authURL, "response_type=code") {
		t.Errorf("auth_url should contain response_type=code, got %q", authURL)
	}
	if !strings.Contains(authURL, "redirect_uri=") {
		t.Errorf("auth_url should contain redirect_uri, got %q", authURL)
	}
	if !strings.Contains(authURL, "scope=basicProfile,publishPost") {
		t.Errorf("auth_url should contain scope, got %q", authURL)
	}
	if !strings.Contains(authURL, "state=") {
		t.Errorf("auth_url should contain state, got %q", authURL)
	}
	if !strings.HasPrefix(authURL, mediumAuthorize) {
		t.Errorf("auth_url should start with %s, got %q", mediumAuthorize, authURL)
	}

	// Verify the CDPContext contains an oauthState.
	oauthSt, ok := session.CDPContext.(*oauthState)
	if !ok {
		t.Fatal("CDPContext should be an *oauthState")
	}
	if oauthSt.State == "" {
		t.Error("oauthState.State should not be empty")
	}
	if oauthSt.Completed {
		t.Error("oauthState.Completed should be false initially")
	}
}

// ---------------------------------------------------------------------------
// PollAuth
// ---------------------------------------------------------------------------

func TestAdapter_PollAuth_Pending(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")

	session := &platform.AuthSession{
		AuthRef:    "test-ref",
		CDPContext: &oauthState{State: "state-123"}, // No code yet.
	}

	result, err := a.PollAuth(context.Background(), session, nil)
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if result != nil {
		t.Error("expected nil result when no code provided (pending)")
	}
}

func TestAdapter_PollAuth_InvalidContext(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")

	session := &platform.AuthSession{
		AuthRef:    "test-ref",
		CDPContext: "not-oauth-state",
	}

	_, err := a.PollAuth(context.Background(), session, nil)
	if err == nil {
		t.Error("expected error for invalid CDPContext type")
	}
}

func TestAdapter_PollAuth_AuthDataRoundTrip(t *testing.T) {
	// Since PollAuth hits the real Medium OAuth token URL and user API,
	// which are unreachable in unit tests, we verify the auth data
	// encryption/decryption round trip that PollAuth would perform.
	key := newTestKey()

	authData := mediumAuthData{
		AccessToken:  "test-access-token",
		RefreshToken: "test-refresh-token",
		ExpiresAt:    0, // Not expired.
		TokenType:    "Bearer",
		UserID:       "user-123",
	}
	authJSON, err := json.Marshal(authData)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	encrypted, err := llm.EncryptAPIKey(string(authJSON), key)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}

	// Verify we can decrypt and get the expected data.
	decrypted, err := llm.DecryptAPIKey(encrypted, key)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}

	var decoded mediumAuthData
	if err := json.Unmarshal([]byte(decrypted), &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if decoded.AccessToken != "test-access-token" {
		t.Errorf("AccessToken = %q, want %q", decoded.AccessToken, "test-access-token")
	}
	if decoded.RefreshToken != "test-refresh-token" {
		t.Errorf("RefreshToken = %q, want %q", decoded.RefreshToken, "test-refresh-token")
	}
	if decoded.TokenType != "Bearer" {
		t.Errorf("TokenType = %q, want %q", decoded.TokenType, "Bearer")
	}
	if decoded.UserID != "user-123" {
		t.Errorf("UserID = %q, want %q", decoded.UserID, "user-123")
	}
}

// ---------------------------------------------------------------------------
// Publish
// ---------------------------------------------------------------------------

func TestAdapter_Publish_Unreachable(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")
	key := newTestKey()

	authData := mediumAuthData{
		AccessToken: "test-access-token",
		ExpiresAt:   0,
		TokenType:   "Bearer",
		UserID:      "user-123",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	// Use a short timeout context to avoid waiting for the real API.
	ctx, cancel := context.WithTimeout(context.Background(), 1)
	defer cancel()

	// Publish tries to hit the real Medium API, which is unreachable in tests.
	_, err := a.Publish(ctx, encrypted, key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
	})
	if err == nil {
		t.Error("expected error when Medium API is unreachable")
	}
}

func TestAdapter_Publish_BadAuthData(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")
	key := newTestKey()

	_, err := a.Publish(context.Background(), []byte("corrupted"), key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
	})
	if err == nil {
		t.Error("expected error when decrypting corrupted auth data")
	}
}

func TestAdapter_Publish_ExpiredToken_NoRefresh(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")
	key := newTestKey()

	authData := mediumAuthData{
		AccessToken:  "expired-token",
		RefreshToken: "", // No refresh token.
		ExpiresAt:    1,  // Expired (Unix timestamp 1 is Jan 1 1970).
		TokenType:    "Bearer",
		UserID:       "user-123",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	_, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
	})
	if err == nil {
		t.Error("expected error when token expired with no refresh token")
	}
	if !strings.Contains(err.Error(), "expired") {
		t.Errorf("error should mention expiration, got: %v", err)
	}
}

// ---------------------------------------------------------------------------
// CheckStatus
// ---------------------------------------------------------------------------

func TestAdapter_CheckStatus(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")
	key := newTestKey()

	authData := mediumAuthData{
		AccessToken: "test-token",
		UserID:      "user-123",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "post-123")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "live" {
		t.Errorf("status = %q, want %q", status, "live")
	}
}

func TestAdapter_CheckStatus_BadAuthData(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")
	key := newTestKey()

	status, err := a.CheckStatus(context.Background(), []byte("corrupted"), key, "post-123")
	if err == nil {
		t.Error("expected error for corrupted auth data")
	}
	if status != "unknown" {
		t.Errorf("status = %q, want %q on error", status, "unknown")
	}
}

// ---------------------------------------------------------------------------
// RevokeAuth
// ---------------------------------------------------------------------------

func TestAdapter_RevokeAuth(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")

	err := a.RevokeAuth(context.Background(), nil, nil)
	if err != nil {
		t.Errorf("RevokeAuth should be a no-op, got error: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Publish — expired token with refresh token (tests the error path since
// the refresh endpoint is unreachable in unit tests)
// ---------------------------------------------------------------------------

func TestAdapter_Publish_ExpiredToken_WithRefresh(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")
	key := newTestKey()

	authData := mediumAuthData{
		AccessToken:  "expired-token",
		RefreshToken: "some-refresh-token",
		ExpiresAt:    1, // Expired (Unix timestamp 1 = Jan 1 1970).
		TokenType:    "Bearer",
		UserID:       "user-123",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	// This attempts to refresh the token, which hits the real Medium API.
	// The refresh will fail because the API is unreachable in unit tests.
	ctx, cancel := context.WithTimeout(context.Background(), 1)
	defer cancel()

	_, err := a.Publish(ctx, encrypted, key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
		Tags:    []string{"go", "test"},
	})
	if err == nil {
		t.Error("expected error when token refresh fails (unreachable API)")
	}
}

// ---------------------------------------------------------------------------
// Publish — invalid auth data JSON
// ---------------------------------------------------------------------------

func TestAdapter_Publish_InvalidAuthJSON(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")
	key := newTestKey()

	// Encrypt something that is not valid mediumAuthData JSON.
	encrypted, _ := llm.EncryptAPIKey("this is not json", key)

	_, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
	})
	if err == nil {
		t.Error("expected error when auth data is not valid JSON")
	}
}

// ---------------------------------------------------------------------------
// CheckStatus — invalid auth JSON
// ---------------------------------------------------------------------------

func TestAdapter_CheckStatus_InvalidAuthJSON(t *testing.T) {
	a := NewAdapter("cid", "csecret", "https://redirect")
	key := newTestKey()

	encrypted, _ := llm.EncryptAPIKey("not-json", key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "post-123")
	if err == nil {
		t.Error("expected error for invalid auth JSON")
	}
	if status != "unknown" {
		t.Errorf("status = %q, want %q on error", status, "unknown")
	}
}
