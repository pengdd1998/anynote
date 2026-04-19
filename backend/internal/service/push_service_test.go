package service

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
)

// ---------------------------------------------------------------------------
// Mock DeviceTokenRepository
// ---------------------------------------------------------------------------

type mockDeviceTokenRepo struct {
	tokens map[string]DeviceTokenEntry // keyed by token
	createErr error
	deleteErr error
	listErr   error
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
// SendPush tests
// ---------------------------------------------------------------------------

func TestPushService_SendPush_NoDevices(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	svc := NewPushService(repo)

	err := svc.SendPush(context.Background(), "user-no-devices", PushPayload{
		Title: "Test",
		Body:  "Message",
	})
	if err != nil {
		t.Fatalf("SendPush with no devices: %v", err)
	}
}

func TestPushService_SendPush_WithDevices(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	svc := NewPushService(repo)

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
	svc := NewPushService(repo)

	err := svc.SendPush(context.Background(), "user-123", PushPayload{
		Title: "Test",
		Body:  "Message",
	})
	if err == nil {
		t.Error("expected error when ListByUser fails")
	}
}

// ---------------------------------------------------------------------------
// RegisterDevice tests
// ---------------------------------------------------------------------------

func TestPushService_RegisterDevice(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	svc := NewPushService(repo)

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
	svc := NewPushService(repo)

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
	svc := NewPushService(repo)

	err := svc.UnregisterDevice(context.Background(), "token-to-remove")
	if err != nil {
		t.Fatalf("UnregisterDevice: %v", err)
	}

	if _, exists := repo.tokens["token-to-remove"]; exists {
		t.Error("token should have been deleted")
	}
}

func TestPushService_UnregisterDevice_RepoError(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	repo.deleteErr = errors.New("db error")
	svc := NewPushService(repo)

	err := svc.UnregisterDevice(context.Background(), "nonexistent-token")
	if err == nil {
		t.Error("expected error when repo.DeleteByToken fails")
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
