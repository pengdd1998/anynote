package wordpress

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"net/http"
	"net/http/httptest"
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
	a := NewAdapter()
	if a.Name() != "wordpress" {
		t.Errorf("Name() = %q, want %q", a.Name(), "wordpress")
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
	if !strings.HasPrefix(session.AuthRef, "wp-") {
		t.Errorf("AuthRef should start with 'wp-', got %q", session.AuthRef)
	}

	var input wpCredInput
	if err := json.Unmarshal(payload, &input); err != nil {
		t.Fatalf("unmarshal payload: %v", err)
	}
	if input.AuthType != "credentials_input" {
		t.Errorf("AuthType = %q, want %q", input.AuthType, "credentials_input")
	}
	if len(input.Fields) != 3 {
		t.Fatalf("len(Fields) = %d, want 3", len(input.Fields))
	}

	expectedFields := []struct {
		name     string
		required bool
	}{
		{"site_url", true},
		{"username", true},
		{"app_password", true},
	}
	for i, exp := range expectedFields {
		if input.Fields[i].Name != exp.name {
			t.Errorf("Fields[%d].Name = %q, want %q", i, input.Fields[i].Name, exp.name)
		}
		if input.Fields[i].Required != exp.required {
			t.Errorf("Fields[%d].Required = %v, want %v", i, input.Fields[i].Required, exp.required)
		}
	}
}

// ---------------------------------------------------------------------------
// PollAuth
// ---------------------------------------------------------------------------

func TestAdapter_PollAuth_Pending(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef:    "test-ref",
		CDPContext: nil,
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
		CDPContext: "not-a-map",
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err == nil {
		t.Error("expected error for invalid CDPContext type")
	}
}

func TestAdapter_PollAuth_MissingFields(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	tests := []struct {
		name   string
		creds  map[string]string
	}{
		{
			name: "missing site_url",
			creds: map[string]string{"username": "admin", "app_password": "pass"},
		},
		{
			name: "missing username",
			creds: map[string]string{"site_url": "https://example.com", "app_password": "pass"},
		},
		{
			name: "missing app_password",
			creds: map[string]string{"site_url": "https://example.com", "username": "admin"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			session := &platform.AuthSession{
				AuthRef:    "test-ref",
				CDPContext: tt.creds,
			}
			_, err := a.PollAuth(context.Background(), session, key)
			if err == nil {
				t.Error("expected error for missing required fields")
			}
		})
	}
}

func TestAdapter_PollAuth_ValidCredentials(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify Basic Auth header is set.
		username, password, ok := r.BasicAuth()
		if !ok {
			t.Error("expected Basic Auth header")
		}
		if username != "admin" {
			t.Errorf("username = %q, want %q", username, "admin")
		}
		if password != "test-app-password" {
			t.Errorf("password = %q, want %q", password, "test-app-password")
		}
		if !strings.Contains(r.URL.Path, "/wp-json/wp/v2/users/me") {
			t.Errorf("expected users/me endpoint, got %s", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"id":   1,
			"name": "admin",
		})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"site_url":     server.URL,
			"username":     "admin",
			"app_password": "test-app-password",
		},
	}

	encrypted, err := a.PollAuth(context.Background(), session, key)
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if encrypted == nil {
		t.Fatal("encrypted should not be nil on success")
	}

	// Decrypt and verify the auth data.
	authJSON, err := llm.DecryptAPIKey(encrypted, key)
	if err != nil {
		t.Fatalf("DecryptAPIKey: %v", err)
	}

	var authData wpAuthData
	if err := json.Unmarshal([]byte(authJSON), &authData); err != nil {
		t.Fatalf("unmarshal auth data: %v", err)
	}
	if authData.SiteURL != server.URL {
		t.Errorf("SiteURL = %q, want %q", authData.SiteURL, server.URL)
	}
	if authData.Username != "admin" {
		t.Errorf("Username = %q, want %q", authData.Username, "admin")
	}
	if authData.AppPassword != "test-app-password" {
		t.Errorf("AppPassword = %q, want %q", authData.AppPassword, "test-app-password")
	}
}

func TestAdapter_PollAuth_InvalidCredentials(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"site_url":     server.URL,
			"username":     "bad-user",
			"app_password": "bad-pass",
		},
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err == nil {
		t.Error("expected error for invalid credentials")
	}
}

func TestAdapter_PollAuth_TrailingSlashStripped(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "//") {
			t.Errorf("URL path should not have double slashes: %s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{"id": 1})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	session := &platform.AuthSession{
		AuthRef: "test-ref",
		CDPContext: map[string]string{
			"site_url":     server.URL + "/", // Trailing slash.
			"username":     "admin",
			"app_password": "pass",
		},
	}

	_, err := a.PollAuth(context.Background(), session, key)
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Publish
// ---------------------------------------------------------------------------

func TestAdapter_Publish(t *testing.T) {
	var receivedBody map[string]interface{}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		username, password, ok := r.BasicAuth()
		if !ok {
			t.Error("expected Basic Auth header")
		}
		if username != "admin" {
			t.Errorf("username = %q, want %q", username, "admin")
		}
		if password != "app-pass" {
			t.Errorf("password = %q, want %q", password, "app-pass")
		}
		if r.Header.Get("Content-Type") != "application/json" {
			t.Errorf("Content-Type = %q, want application/json", r.Header.Get("Content-Type"))
		}
		if !strings.Contains(r.URL.Path, "/wp-json/wp/v2/posts") {
			t.Errorf("expected posts endpoint, got %s", r.URL.Path)
		}

		if err := json.NewDecoder(r.Body).Decode(&receivedBody); err != nil {
			t.Errorf("decode body: %v", err)
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"id":     42,
			"link":   "https://example.com/?p=42",
			"status": "publish",
		})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{
		SiteURL:     server.URL,
		Username:    "admin",
		AppPassword: "app-pass",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	result, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "Test Post",
		Content: "Hello WordPress",
		Tags:    []string{"go", "testing"},
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if result.PlatformURL != "https://example.com/?p=42" {
		t.Errorf("PlatformURL = %q, want %q", result.PlatformURL, "https://example.com/?p=42")
	}
	if result.PlatformID != "42" {
		t.Errorf("PlatformID = %q, want %q", result.PlatformID, "42")
	}
	if receivedBody["title"] != "Test Post" {
		t.Errorf("body title = %v, want %q", receivedBody["title"], "Test Post")
	}
	if receivedBody["content"] != "Hello WordPress" {
		t.Errorf("body content = %v, want %q", receivedBody["content"], "Hello WordPress")
	}
	if receivedBody["status"] != "publish" {
		t.Errorf("body status = %v, want %q", receivedBody["status"], "publish")
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
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	_, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "Test",
		Content: "Content",
	})
	if err == nil {
		t.Error("expected error when endpoint returns non-201")
	}
}

// ---------------------------------------------------------------------------
// CheckStatus
// ---------------------------------------------------------------------------

func TestAdapter_CheckStatus_Live(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "publish"})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "42")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "live" {
		t.Errorf("status = %q, want %q", status, "live")
	}
}

func TestAdapter_CheckStatus_Removed(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "42")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "removed" {
		t.Errorf("status = %q, want %q", status, "removed")
	}
}

func TestAdapter_CheckStatus_Trash(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "trash"})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "42")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "removed" {
		t.Errorf("status = %q, want %q", status, "removed")
	}
}

func TestAdapter_CheckStatus_BadAuthData(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	status, err := a.CheckStatus(context.Background(), []byte("corrupted"), key, "42")
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

func TestAdapter_RevokeAuth_CorruptedData(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	// RevokeAuth tries to decrypt auth data; corrupted data should return an error.
	err := a.RevokeAuth(context.Background(), []byte("corrupted"), key)
	if err == nil {
		t.Error("expected error when decrypting corrupted auth data")
	}
}

func TestAdapter_RevokeAuth_Success_WithAnyNotePasswords(t *testing.T) {
	var listCalled, deleteCalled bool

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.Contains(r.URL.Path, "/application-passwords") && r.Method == http.MethodGet:
			listCalled = true
			// Verify Basic Auth is set.
			username, _, ok := r.BasicAuth()
			if !ok {
				t.Error("expected Basic Auth header")
			}
			if username != "admin" {
				t.Errorf("username = %q, want %q", username, "admin")
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode([]map[string]string{
				{"uuid": "uuid-1", "name": "AnyNote App"},
				{"uuid": "uuid-2", "name": "Other App"},
			})

		case strings.Contains(r.URL.Path, "/application-passwords/uuid-1") && r.Method == http.MethodDelete:
			deleteCalled = true
			username, _, ok := r.BasicAuth()
			if !ok {
				t.Error("expected Basic Auth header on delete")
			}
			if username != "admin" {
				t.Errorf("username = %q, want %q", username, "admin")
			}
			w.WriteHeader(http.StatusNoContent)

		default:
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{
		SiteURL:     server.URL,
		Username:    "admin",
		AppPassword: "app-pass",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	err := a.RevokeAuth(context.Background(), encrypted, key)
	if err != nil {
		t.Fatalf("RevokeAuth: %v", err)
	}
	if !listCalled {
		t.Error("expected list application-passwords endpoint to be called")
	}
	if !deleteCalled {
		t.Error("expected delete endpoint to be called for AnyNote password")
	}
}

func TestAdapter_RevokeAuth_NonOKStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{
		SiteURL:     server.URL,
		Username:    "admin",
		AppPassword: "app-pass",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	// Non-OK status should return nil (graceful degradation).
	err := a.RevokeAuth(context.Background(), encrypted, key)
	if err != nil {
		t.Errorf("RevokeAuth should return nil on non-OK status, got: %v", err)
	}
}

func TestAdapter_RevokeAuth_MalformedJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("not-valid-json"))
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{
		SiteURL:     server.URL,
		Username:    "admin",
		AppPassword: "app-pass",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	// Malformed JSON response should return nil (graceful degradation).
	err := a.RevokeAuth(context.Background(), encrypted, key)
	if err != nil {
		t.Errorf("RevokeAuth should return nil on malformed JSON, got: %v", err)
	}
}

func TestAdapter_RevokeAuth_NoMatchingPasswords(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode([]map[string]string{
			{"uuid": "uuid-1", "name": "Some Other App"},
			{"uuid": "uuid-2", "name": "WordPress Mobile"},
		})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{
		SiteURL:     server.URL,
		Username:    "admin",
		AppPassword: "app-pass",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	err := a.RevokeAuth(context.Background(), encrypted, key)
	if err != nil {
		t.Fatalf("RevokeAuth: %v", err)
	}
}

func TestAdapter_RevokeAuth_ConnectionError(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{
		SiteURL:     "http://127.0.0.1:1", // Unreachable port.
		Username:    "admin",
		AppPassword: "app-pass",
	}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	// Connection error should return nil (graceful degradation).
	err := a.RevokeAuth(context.Background(), encrypted, key)
	if err != nil {
		t.Errorf("RevokeAuth should return nil on connection error, got: %v", err)
	}
}

// ---------------------------------------------------------------------------
// CheckStatus: additional branches
// ---------------------------------------------------------------------------

func TestAdapter_CheckStatus_Draft(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "draft"})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "42")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "live" {
		t.Errorf("status = %q, want %q for draft", status, "live")
	}
}

func TestAdapter_CheckStatus_Pending(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "pending"})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "42")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "live" {
		t.Errorf("status = %q, want %q for pending", status, "live")
	}
}

func TestAdapter_CheckStatus_UnknownStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "future"})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "42")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "unknown" {
		t.Errorf("status = %q, want %q for unknown post status", status, "unknown")
	}
}

func TestAdapter_CheckStatus_OtherHTTPStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, err := a.CheckStatus(context.Background(), encrypted, key, "42")
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "unknown" {
		t.Errorf("status = %q, want %q for server error", status, "unknown")
	}
}

func TestAdapter_CheckStatus_ConnectionError(t *testing.T) {
	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: "http://127.0.0.1:1", Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	status, _ := a.CheckStatus(context.Background(), encrypted, key, "42")
	if status != "unknown" {
		t.Errorf("status = %q, want %q on connection error", status, "unknown")
	}
}

// ---------------------------------------------------------------------------
// Publish: no tags branch
// ---------------------------------------------------------------------------

func TestAdapter_Publish_NoTags(t *testing.T) {
	var receivedBody map[string]interface{}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewDecoder(r.Body).Decode(&receivedBody)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"id":     99,
			"link":   "https://example.com/?p=99",
			"status": "publish",
		})
	}))
	defer server.Close()

	a := NewAdapter()
	key := newTestKey()

	authData := wpAuthData{SiteURL: server.URL, Username: "admin", AppPassword: "pass"}
	authJSON, _ := json.Marshal(authData)
	encrypted, _ := llm.EncryptAPIKey(string(authJSON), key)

	result, err := a.Publish(context.Background(), encrypted, key, platform.PublishParams{
		Title:   "No Tags Post",
		Content: "Content without tags",
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if result.PlatformID != "99" {
		t.Errorf("PlatformID = %q, want %q", result.PlatformID, "99")
	}
	// Verify tags was NOT sent in the body.
	if _, hasTags := receivedBody["tags"]; hasTags {
		t.Error("tags should not be present when no tags provided")
	}
}
