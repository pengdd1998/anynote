package service

import (
	"context"
	"errors"
	"fmt"
	"testing"

	"github.com/google/uuid"
)

// ---------------------------------------------------------------------------
// Mock DeviceTokenRepository
// ---------------------------------------------------------------------------

type mockDeviceTokenRepo struct {
	tokens    map[string]DeviceTokenEntry // keyed by token
	createErr error
	deleteErr error
	listErr   error
	getErr    error
}

func newMockDeviceTokenRepo() *mockDeviceTokenRepo {
	return &mockDeviceTokenRepo{
		tokens: make(map[string]DeviceTokenEntry),
	}
}

func (m *mockDeviceTokenRepo) Create(ctx context.Context, id uuid.UUID, userID string, token string, platform string) error {
	if m.createErr != nil {
		return m.createErr
	}
	m.tokens[token] = DeviceTokenEntry{
		ID:       id,
		UserID:   userID,
		Token:    token,
		Platform: platform,
	}
	return nil
}

func (m *mockDeviceTokenRepo) DeleteByToken(ctx context.Context, token string) error {
	if m.deleteErr != nil {
		return m.deleteErr
	}
	delete(m.tokens, token)
	return nil
}

func (m *mockDeviceTokenRepo) GetByToken(ctx context.Context, token string) (*DeviceTokenEntry, error) {
	if m.getErr != nil {
		return nil, m.getErr
	}
	entry, ok := m.tokens[token]
	if !ok {
		return nil, fmt.Errorf("token not found: %s", token)
	}
	return &entry, nil
}

func (m *mockDeviceTokenRepo) ListByUser(ctx context.Context, userID string) ([]DeviceTokenEntry, error) {
	if m.listErr != nil {
		return nil, m.listErr
	}
	var entries []DeviceTokenEntry
	for _, e := range m.tokens {
		if e.UserID == userID {
			entries = append(entries, e)
		}
	}
	return entries, nil
}

// ---------------------------------------------------------------------------
// Mock FCMClient
// ---------------------------------------------------------------------------

// mockFCMClient records calls to Send for assertion in tests.
type mockFCMClient struct {
	calls []FCMMessage // all messages passed to Send
	sendErr map[string]error // token -> error; if set, Send returns this error
}

func newMockFCMClient() *mockFCMClient {
	return &mockFCMClient{
		sendErr: make(map[string]error),
	}
}

func (m *mockFCMClient) Send(ctx context.Context, message *FCMMessage) (string, error) {
	m.calls = append(m.calls, *message)
	if err, ok := m.sendErr[message.Token]; ok {
		return "", err
	}
	return "projects/test/messages/" + message.Token, nil
}

// ---------------------------------------------------------------------------
// SendPush tests -- log-only mode (nil FCM)
// ---------------------------------------------------------------------------

func TestPushService_SendPush_NoDevices(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	svc := NewPushService(repo, nil)

	err := svc.SendPush(context.Background(), "user-no-devices", PushPayload{
		Title: "Test",
		Body:  "Message",
	})
	if err != nil {
		t.Fatalf("SendPush with no devices: %v", err)
	}
}

func TestPushService_SendPush_LogOnly_WithDevices(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	svc := NewPushService(repo, nil)

	// Pre-register a device.
	userID := "user-123"
	repo.tokens["token-1"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "token-1",
		Platform: "android",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title:    "Hello",
		Body:     "World",
		Priority: "high",
	})
	if err != nil {
		t.Fatalf("SendPush: %v", err)
	}
}

func TestPushService_SendPush_ListError(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	repo.listErr = errors.New("db error")
	svc := NewPushService(repo, nil)

	err := svc.SendPush(context.Background(), "user-123", PushPayload{
		Title: "Test",
		Body:  "Message",
	})
	if err == nil {
		t.Error("expected error when ListByUser fails")
	}
}

// ---------------------------------------------------------------------------
// SendPush tests -- FCM mode
// ---------------------------------------------------------------------------

func TestPushService_SendPush_FCM_MessageConstruction(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "user-456"
	repo.tokens["fcm-token-1"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "fcm-token-1",
		Platform: "ios",
	}
	repo.tokens["fcm-token-2"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "fcm-token-2",
		Platform: "android",
	}

	payload := PushPayload{
		Title:    "Note Updated",
		Body:     "Your shared note was edited",
		Priority: "high",
		Data: map[string]interface{}{
			"note_id": "abc-123",
			"action":  "edit",
		},
	}

	err := svc.SendPush(context.Background(), userID, payload)
	if err != nil {
		t.Fatalf("SendPush with FCM: %v", err)
	}

	// Both devices should have received a message.
	if len(fcm.calls) != 2 {
		t.Fatalf("expected 2 FCM calls, got %d", len(fcm.calls))
	}

	// Verify each call has the correct fields.
	tokensSeen := map[string]bool{}
	for _, call := range fcm.calls {
		tokensSeen[call.Token] = true

		if call.Title != payload.Title {
			t.Errorf("Title = %q, want %q", call.Title, payload.Title)
		}
		if call.Body != payload.Body {
			t.Errorf("Body = %q, want %q", call.Body, payload.Body)
		}
		if call.Priority != payload.Priority {
			t.Errorf("Priority = %q, want %q", call.Priority, payload.Priority)
		}
		// Data map values should be strings.
		if call.Data["note_id"] != "abc-123" {
			t.Errorf("Data[note_id] = %q, want %q", call.Data["note_id"], "abc-123")
		}
		if call.Data["action"] != "edit" {
			t.Errorf("Data[action] = %q, want %q", call.Data["action"], "edit")
		}
	}

	if !tokensSeen["fcm-token-1"] || !tokensSeen["fcm-token-2"] {
		t.Error("not all device tokens received messages", "seen", tokensSeen)
	}
}

func TestPushService_SendPush_FCM_NoDataPayload(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "user-789"
	repo.tokens["token-no-data"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "token-no-data",
		Platform: "android",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Simple",
		Body:  "No data",
	})
	if err != nil {
		t.Fatalf("SendPush: %v", err)
	}

	if len(fcm.calls) != 1 {
		t.Fatalf("expected 1 FCM call, got %d", len(fcm.calls))
	}
	if fcm.calls[0].Data != nil {
		t.Errorf("Data should be nil when payload has no data, got %v", fcm.calls[0].Data)
	}
}

func TestPushService_SendPush_FCM_StaleTokenCleanup(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()

	// Simulate FCM returning UNREGISTERED for stale-token.
	fcm.sendErr["stale-token"] = fmt.Errorf("UNREGISTERED error for stale-token")

	svc := NewPushService(repo, fcm)

	userID := "user-stale"
	repo.tokens["stale-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "stale-token",
		Platform: "android",
	}
	repo.tokens["valid-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "valid-token",
		Platform: "ios",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Test",
		Body:  "Cleanup",
	})
	if err != nil {
		t.Fatalf("SendPush: %v", err)
	}

	// Stale token should have been removed from the repo.
	if _, exists := repo.tokens["stale-token"]; exists {
		t.Error("stale token should have been deleted from repo")
	}

	// Valid token should remain.
	if _, exists := repo.tokens["valid-token"]; !exists {
		t.Error("valid token should still be in repo")
	}

	// Both tokens should have been attempted (2 FCM calls total).
	if len(fcm.calls) != 2 {
		t.Errorf("expected 2 FCM calls (stale + valid), got %d", len(fcm.calls))
	}
}

func TestPushService_SendPush_FCM_OtherError_NoCleanup(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()

	// Simulate a transient FCM error (not UNREGISTERED).
	fcm.sendErr["fail-token"] = fmt.Errorf("internal error for fail-token")

	svc := NewPushService(repo, fcm)

	userID := "user-fail"
	repo.tokens["fail-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "fail-token",
		Platform: "android",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Test",
		Body:  "Error",
	})
	if err != nil {
		t.Fatalf("SendPush should not return error for per-device failures: %v", err)
	}

	// Token should NOT be removed for non-UNREGISTERED errors.
	if _, exists := repo.tokens["fail-token"]; !exists {
		t.Error("token should NOT have been deleted for non-UNREGISTERED error")
	}
}

func TestPushService_SendPush_FCM_StaleToken_DeleteError(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	repo.deleteErr = errors.New("db delete error")
	fcm := newMockFCMClient()

	fcm.sendErr["stale-token"] = fmt.Errorf("UNREGISTERED")

	svc := NewPushService(repo, fcm)

	userID := "user-delerr"
	repo.tokens["stale-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "stale-token",
		Platform: "android",
	}

	// Should not return an error even if token deletion fails (logged only).
	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Test",
		Body:  "DeleteError",
	})
	if err != nil {
		t.Fatalf("SendPush should not fail when stale token deletion fails: %v", err)
	}
}

// ---------------------------------------------------------------------------
// RegisterDevice tests
// ---------------------------------------------------------------------------

func TestPushService_RegisterDevice(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	svc := NewPushService(repo, nil)

	err := svc.RegisterDevice(context.Background(), "user-123", "new-token", "ios")
	if err != nil {
		t.Fatalf("RegisterDevice: %v", err)
	}

	if len(repo.tokens) != 1 {
		t.Fatalf("expected 1 token, got %d", len(repo.tokens))
	}
	entry, ok := repo.tokens["new-token"]
	if !ok {
		t.Fatal("token not found in repo")
	}
	if entry.UserID != "user-123" {
		t.Errorf("UserID = %q, want %q", entry.UserID, "user-123")
	}
	if entry.Platform != "ios" {
		t.Errorf("Platform = %q, want %q", entry.Platform, "ios")
	}
	if entry.ID == uuid.Nil {
		t.Error("ID should be set")
	}
}

func TestPushService_RegisterDevice_RepoError(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	repo.createErr = errors.New("db error")
	svc := NewPushService(repo, nil)

	err := svc.RegisterDevice(context.Background(), "user-123", "token", "android")
	if err == nil {
		t.Error("expected error when repo.Create fails")
	}
}

// ---------------------------------------------------------------------------
// UnregisterDevice tests
// ---------------------------------------------------------------------------

func TestPushService_UnregisterDevice(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	repo.tokens["token-to-remove"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   "user-123",
		Token:    "token-to-remove",
		Platform: "android",
	}
	svc := NewPushService(repo, nil)

	err := svc.UnregisterDevice(context.Background(), "user-123", "token-to-remove")
	if err != nil {
		t.Fatalf("UnregisterDevice: %v", err)
	}

	if _, exists := repo.tokens["token-to-remove"]; exists {
		t.Error("token should have been deleted")
	}
}

func TestPushService_UnregisterDevice_RepoError(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	repo.getErr = errors.New("db error")
	svc := NewPushService(repo, nil)

	err := svc.UnregisterDevice(context.Background(), "user-123", "nonexistent-token")
	if err == nil {
		t.Error("expected error when repo.GetByToken fails")
	}
}

func TestPushService_UnregisterDevice_WrongUser(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	repo.tokens["token-to-remove"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   "user-123",
		Token:    "token-to-remove",
		Platform: "android",
	}
	svc := NewPushService(repo, nil)

	err := svc.UnregisterDevice(context.Background(), "other-user", "token-to-remove")
	if err == nil {
		t.Error("expected error when user does not own the token")
	}
}

// ---------------------------------------------------------------------------
// tokenPrefix helper tests
// ---------------------------------------------------------------------------

func TestTokenPrefix(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"abcdefghijklmnop", "abcdefgh..."},
		{"short", "short"},
		{"exactly8", "exactly8"},
		{"", ""},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := tokenPrefix(tt.input)
			if got != tt.want {
				t.Errorf("tokenPrefix(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// convertDataToStringMap tests
// ---------------------------------------------------------------------------

func TestConvertDataToStringMap(t *testing.T) {
	tests := []struct {
		name string
		in   map[string]interface{}
		want map[string]string
	}{
		{
			name: "nil input",
			in:   nil,
			want: nil,
		},
		{
			name: "empty input",
			in:   map[string]interface{}{},
			want: nil,
		},
		{
			name: "string values",
			in:   map[string]interface{}{"key": "value"},
			want: map[string]string{"key": "value"},
		},
		{
			name: "integer value",
			in:   map[string]interface{}{"count": 42},
			want: map[string]string{"count": "42"},
		},
		{
			name: "mixed types",
			in:   map[string]interface{}{"id": "abc", "num": 7, "flag": true},
			want: map[string]string{"id": "abc", "num": "7", "flag": "true"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := convertDataToStringMap(tt.in)
			if tt.want == nil {
				if got != nil {
					t.Errorf("expected nil, got %v", got)
				}
				return
			}
			if len(got) != len(tt.want) {
				t.Fatalf("expected %d entries, got %d", len(tt.want), len(got))
			}
			for k, v := range tt.want {
				if got[k] != v {
					t.Errorf("got[%q] = %q, want %q", k, got[k], v)
				}
			}
		})
	}
}

// ---------------------------------------------------------------------------
// isUnregisteredError tests
// ---------------------------------------------------------------------------

func TestIsUnregisteredError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{"nil error", nil, false},
		{"UNREGISTERED", fmt.Errorf("UNREGISTERED"), true},
		{"unregistered lowercase", fmt.Errorf("device UNREGISTERED by FCM"), true},
		{"invalid-registration-token", fmt.Errorf("invalid-registration-token"), true},
		{"NotRegistered (APNs style)", fmt.Errorf("NotRegistered"), true},
		{"unrelated error", fmt.Errorf("internal server error"), false},
		{"quota exceeded", fmt.Errorf("quota-exceeded"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isUnregisteredError(tt.err)
			if got != tt.want {
				t.Errorf("isUnregisteredError(%v) = %v, want %v", tt.err, got, tt.want)
			}
		})
	}
}
