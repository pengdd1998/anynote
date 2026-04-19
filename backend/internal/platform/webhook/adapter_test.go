package webhook

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"net/http"
	"net/http/httptest"
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
	a := NewAdapter()
	if a.Name() != "webhook" {
		t.Errorf("Name() = %q, want %q", a.Name(), "webhook")
	}
}

// ---------------------------------------------------------------------------
// StartAuth
// ---------------------------------------------------------------------------

func TestAdapter_StartAuth(t *testing.T) {
	a := NewAdapter()
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

	// Verify the payload is valid JSON with the expected credential fields.
	var input webhookCredInput
	if err := json.Unmarshal(payload, &input); err != nil {
		t.Fatalf("unmarshal payload: %v", err)
	}
	if input.AuthType != "credentials_input" {
		t.Errorf("AuthType = %q, want %q", input.AuthType, "credentials_input")
	}
	if len(input.Fields) != 2 {
		t.Fatalf("len(Fields) = %d, want 2", len(input.Fields))
	}

	t.Run("url_field", func(t *testing.T) {
		f := input.Fields[0]
		if f.Name != "url" {
			t.Errorf("Field[0].Name = %q, want %q", f.Name, "url")
		}
		if !f.Required {
			t.Error("url field should be required")
		}
	})

	t.Run("secret_field", func(t *testing.T) {
		f := input.Fields[1]
		if f.Name != "secret" {
			t.Errorf("Field[1].Name = %q, want %q", f.Name, "secret")
		}
		if f.Required {
			t.Error("secret field should be optional")
		}
	})
}

// ---------------------------------------------------------------------------
// PollAuth
// ---------------------------------------------------------------------------

func TestAdapter_PollAuth_Pending(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef:    "test-ref",
		CDPContext: nil, // No credentials yet.
	}

	result, err := a.PollAuth(context.Background(), session, key)
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if result != nil {
		t.Error("expected nil result when CDPContext is nil (pending)")
	}
}

func TestAdapter_PollAuth_InvalidContext(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef:    "test-ref",
		CDPContext: "not-a-map", // Wrong type.
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err == nil {
		t.Error("expected error for invalid CDPContext type")
	}
}

func TestAdapter_PollAuth_EmptyURL(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"url": "",
		},
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err == nil {
		t.Error("expected error for empty webhook URL")
	}
}

func TestAdapter_PollAuth_UnreachableEndpoint(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"url": "http://127.0.0.1:1/impossible-endpoint",
		},
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err == nil {
		t.Error("expected error for unreachable endpoint")
	}
}

func TestAdapter_PollAuth_ValidEndpoint(t *testing.T) {
	// Start a test server that accepts POST and returns 200.
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("expected POST, got %s", r.Method)
		}
		if r.Header.Get("Content-Type") != "application/json" {
			t.Errorf("expected Content-Type application/json, got %s", r.Header.Get("Content-Type"))
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"url":    server.URL,
			"secret": "my-secret",
		},
	}

	encrypted, err := a.PollAuth(context.Background(), session, key)
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if encrypted == nil {
		t.Fatal("encrypted should not be nil on success")
	}

	// Verify we can decrypt the returned auth data.
	authJSON, err := llm.DecryptAPIKey(encrypted, key)
	if err != nil {
		t.Fatalf("DecryptAPIKey: %v", err)
	}

	var authData webhookAuthData
	if err := json.Unmarshal([]byte(authJSON), &authData); err != nil {
		t.Fatalf("unmarshal auth data: %v", err)
	}
	if authData.URL != server.URL {
		t.Errorf("URL = %q, want %q", authData.URL, server.URL)
	}
	if authData.Secret != "my-secret" {
		t.Errorf("Secret = %q, want %q", authData.Secret, "my-secret")
	}
}

func TestAdapter_PollAuth_EndpointReturnsError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"url": server.URL,
		},
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err == nil {
		t.Error("expected error when endpoint returns 500")
	}
}

func TestAdapter_PollAuth_SecretHeaderSent(t *testing.T) {
	var receivedSecret string

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedSecret = r.Header.Get("X-Webhook-Secret")
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"url":    server.URL,
			"secret": "test-secret-value",
		},
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if receivedSecret != "test-secret-value" {
		t.Errorf("X-Webhook-Secret = %q, want %q", receivedSecret, "test-secret-value")
	}
}

func TestAdapter_PollAuth_NoSecretSent(t *testing.T) {
	var receivedSecret string

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedSecret = r.Header.Get("X-Webhook-Secret")
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"url": server.URL,
		},
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if receivedSecret != "" {
		t.Errorf("X-Webhook-Secret should be empty when no secret provided, got %q", receivedSecret)
	}
}

// ---------------------------------------------------------------------------
// Publish
// ---------------------------------------------------------------------------

func TestAdapter_Publish(t *testing.T) {
	var receivedBody webhookPayload
	var receivedSecret string

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedSecret = r.Header.Get("X-Webhook-Secret")

		if err := json.NewDecoder(r.Body).Decode(&receivedBody); err != nil {
			t.Errorf("decode body: %v", err)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	// Encrypt auth data for the test server.
	authData := webhookAuthData{
		URL:    server.URL,
		Secret: "publish-secret",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	result, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "Test Title",
		Content: "Test Content",
		Tags:    []string{"tag1", "tag2"},
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if result.PlatformURL != server.URL {
		t.Errorf("PlatformURL = %q, want %q", result.PlatformURL, server.URL)
	}
	if result.PlatformID == "" {
		t.Error("PlatformID should not be empty")
	}
	if receivedBody.Title != "Test Title" {
		t.Errorf("payload Title = %q, want %q", receivedBody.Title, "Test Title")
	}
	if receivedBody.Content != "Test Content" {
		t.Errorf("payload Content = %q, want %q", receivedBody.Content, "Test Content")
	}
	if receivedBody.Platform != "webhook" {
		t.Errorf("payload Platform = %q, want %q", receivedBody.Platform, "webhook")
	}
	if receivedSecret != "publish-secret" {
		t.Errorf("X-Webhook-Secret = %q, want %q", receivedSecret, "publish-secret")
	}
}

func TestAdapter_Publish_CustomHeaders(t *testing.T) {
	var receivedHeaders = map[string]string{}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedHeaders["X-Webhook-Secret"] = r.Header.Get("X-Webhook-Secret")
		receivedHeaders["X-Custom-Auth"] = r.Header.Get("X-Custom-Auth")
		receivedHeaders["Authorization"] = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := webhookAuthData{
		URL:    server.URL,
		Secret: "my-secret",
		Headers: map[string]string{
			"X-Custom-Auth": "token-123",
			"Authorization": "Bearer abc",
		},
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	result, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "Custom Headers Test",
		Content: "Content",
		Tags:    []string{"test"},
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if result.PlatformURL != server.URL {
		t.Errorf("PlatformURL = %q, want %q", result.PlatformURL, server.URL)
	}
	if receivedHeaders["X-Webhook-Secret"] != "my-secret" {
		t.Errorf("X-Webhook-Secret = %q, want %q", receivedHeaders["X-Webhook-Secret"], "my-secret")
	}
	if receivedHeaders["X-Custom-Auth"] != "token-123" {
		t.Errorf("X-Custom-Auth = %q, want %q", receivedHeaders["X-Custom-Auth"], "token-123")
	}
	if receivedHeaders["Authorization"] != "Bearer abc" {
		t.Errorf("Authorization = %q, want %q", receivedHeaders["Authorization"], "Bearer abc")
	}
}

func TestAdapter_Publish_BadAuthData(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	_, err := a.Publish(context.Background(), []byte("corrupted"), key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
	})
	if err == nil {
		t.Error("expected error when decrypting corrupted auth data")
	}
}

func TestAdapter_Publish_EndpointError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := webhookAuthData{URL: server.URL}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	_, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
	})
	if err == nil {
		t.Error("expected error when endpoint returns non-2xx")
	}
}

func TestAdapter_Publish_UnreachableEndpoint(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	authData := webhookAuthData{URL: "http://127.0.0.1:1/impossible-endpoint"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	_, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
	})
	if err == nil {
		t.Error("expected error when endpoint is unreachable")
	}
}

func TestAdapter_Publish_InvalidAuthJSON(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	// Encrypt something that is not valid webhookAuthData JSON.
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
// CheckStatus
// ---------------------------------------------------------------------------

func TestAdapter_CheckStatus(t *testing.T) {
	a := NewAdapter()

	status, err := a.CheckStatus(context.Background(), nil, nil, "any-id")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "live" {
		t.Errorf("status = %q, want %q", status, "live")
	}
}

// ---------------------------------------------------------------------------
// RevokeAuth
// ---------------------------------------------------------------------------

func TestAdapter_RevokeAuth(t *testing.T) {
	a := NewAdapter()

	err := a.RevokeAuth(context.Background(), nil, nil)
	if err != nil {
		t.Errorf("RevokeAuth should be a no-op, got error: %v", err)
	}
}
