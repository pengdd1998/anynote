package service

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock NotificationRepo
// ---------------------------------------------------------------------------

type mockNotificationRepo struct {
	notifications map[string]*domain.Notification // keyed by id
	userNotifs    map[string][]string             // userID -> []notifID
	createErr     error
	markReadErr   error
	markAllErr    error
	deleteErr     error
	unreadCount   int
	unreadErr     error
}

func newMockNotificationRepo() *mockNotificationRepo {
	return &mockNotificationRepo{
		notifications: make(map[string]*domain.Notification),
		userNotifs:    make(map[string][]string),
	}
}

func (m *mockNotificationRepo) Create(_ context.Context, n *domain.Notification) error {
	if m.createErr != nil {
		return m.createErr
	}
	n.ID = "notif-" + n.Type + "-" + n.UserID[:4]
	n.CreatedAt = time.Now()
	m.notifications[n.ID] = n
	m.userNotifs[n.UserID] = append(m.userNotifs[n.UserID], n.ID)
	return nil
}

func (m *mockNotificationRepo) GetByUser(_ context.Context, userID string, limit, offset int) ([]domain.Notification, error) {
	ids := m.userNotifs[userID]
	var result []domain.Notification
	for _, id := range ids {
		if n, ok := m.notifications[id]; ok {
			result = append(result, *n)
		}
	}
	// Apply limit/offset.
	if offset > len(result) {
		return []domain.Notification{}, nil
	}
	result = result[offset:]
	if limit < len(result) {
		result = result[:limit]
	}
	return result, nil
}

func (m *mockNotificationRepo) GetUnreadCount(_ context.Context, _ string) (int, error) {
	if m.unreadErr != nil {
		return 0, m.unreadErr
	}
	return m.unreadCount, nil
}

func (m *mockNotificationRepo) MarkRead(_ context.Context, _, _ string) error {
	return m.markReadErr
}

func (m *mockNotificationRepo) MarkAllRead(_ context.Context, _ string) error {
	return m.markAllErr
}

func (m *mockNotificationRepo) Delete(_ context.Context, _, _ string) error {
	return m.deleteErr
}

func (m *mockNotificationRepo) GetNotificationPreferences(_ context.Context, _ string) (json.RawMessage, error) {
	return json.RawMessage(`{"pushNotifications":true,"reminderNotifications":true}`), nil
}

func (m *mockNotificationRepo) UpdateNotificationPreferences(_ context.Context, _ string, _ json.RawMessage) error {
	return nil
}

// ---------------------------------------------------------------------------
// Tests: CreateNotification
// ---------------------------------------------------------------------------

func TestNotificationService_CreateNotification_System(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	err := svc.CreateNotification(context.Background(), "user-1", "system", "Welcome", "Hello!", nil)
	if err != nil {
		t.Fatalf("CreateNotification: %v", err)
	}

	if len(repo.notifications) != 1 {
		t.Errorf("expected 1 notification, got %d", len(repo.notifications))
	}
}

func TestNotificationService_CreateNotification_WithJSONData(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	data := json.RawMessage(`{"note_id":"abc123"}`)
	err := svc.CreateNotification(context.Background(), "user-1", "reminder", "Reminder", "Check this", data)
	if err != nil {
		t.Fatalf("CreateNotification: %v", err)
	}
}

func TestNotificationService_CreateNotification_NilDataDefaults(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	err := svc.CreateNotification(context.Background(), "user-1", "system", "Title", "Body", nil)
	if err != nil {
		t.Fatalf("CreateNotification: %v", err)
	}

	// Find the created notification.
	for _, n := range repo.notifications {
		if string(n.Data) != `{}` {
			t.Errorf("Data = %q, want {}", string(n.Data))
		}
	}
}

func TestNotificationService_CreateNotification_InvalidType(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	err := svc.CreateNotification(context.Background(), "user-1", "invalid_type", "Title", "Body", nil)
	if err == nil {
		t.Error("expected error for invalid notification type")
	}
}

func TestNotificationService_CreateNotification_AllValidTypes(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	validTypes := []string{"sync_conflict", "share_received", "reminder", "system", "payment", "publish_started", "publish_completed", "collab_invite"}
	for _, nType := range validTypes {
		err := svc.CreateNotification(context.Background(), "user-1", nType, "Title", "Body", nil)
		if err != nil {
			t.Errorf("type %q: %v", nType, err)
		}
	}

	if len(repo.notifications) != len(validTypes) {
		t.Errorf("expected %d notifications, got %d", len(validTypes), len(repo.notifications))
	}
}

func TestNotificationService_CreateNotification_RepoError(t *testing.T) {
	repo := newMockNotificationRepo()
	repo.createErr = errors.New("db error")
	svc := NewNotificationService(repo)

	err := svc.CreateNotification(context.Background(), "user-1", "system", "Title", "Body", nil)
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: ListNotifications
// ---------------------------------------------------------------------------

func TestNotificationService_ListNotifications_DefaultPagination(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	result, err := svc.ListNotifications(context.Background(), "user-1", 0, 0)
	if err != nil {
		t.Fatalf("ListNotifications: %v", err)
	}
	if result == nil {
		t.Error("result should not be nil")
	}
}

func TestNotificationService_ListNotifications_NegativeLimit(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	// Negative limit should be clamped to default 20.
	result, err := svc.ListNotifications(context.Background(), "user-1", -5, 0)
	if err != nil {
		t.Fatalf("ListNotifications: %v", err)
	}
	if result == nil {
		t.Error("result should not be nil")
	}
}

func TestNotificationService_ListNotifications_ExcessiveLimit(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	// Limit > 100 should be clamped to 100.
	result, err := svc.ListNotifications(context.Background(), "user-1", 500, 0)
	if err != nil {
		t.Fatalf("ListNotifications: %v", err)
	}
	if result == nil {
		t.Error("result should not be nil")
	}
}

func TestNotificationService_ListNotifications_NegativeOffset(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	result, err := svc.ListNotifications(context.Background(), "user-1", 20, -10)
	if err != nil {
		t.Fatalf("ListNotifications: %v", err)
	}
	if result == nil {
		t.Error("result should not be nil")
	}
}

func TestNotificationService_ListNotifications_EmptyResult(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	result, err := svc.ListNotifications(context.Background(), "nonexistent-user", 20, 0)
	if err != nil {
		t.Fatalf("ListNotifications: %v", err)
	}
	if len(result) != 0 {
		t.Errorf("expected 0 notifications, got %d", len(result))
	}
}

// ---------------------------------------------------------------------------
// Tests: GetUnreadCount
// ---------------------------------------------------------------------------

func TestNotificationService_GetUnreadCount(t *testing.T) {
	repo := newMockNotificationRepo()
	repo.unreadCount = 7
	svc := NewNotificationService(repo)

	count, err := svc.GetUnreadCount(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("GetUnreadCount: %v", err)
	}
	if count != 7 {
		t.Errorf("count = %d, want 7", count)
	}
}

func TestNotificationService_GetUnreadCount_Zero(t *testing.T) {
	repo := newMockNotificationRepo()
	repo.unreadCount = 0
	svc := NewNotificationService(repo)

	count, err := svc.GetUnreadCount(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("GetUnreadCount: %v", err)
	}
	if count != 0 {
		t.Errorf("count = %d, want 0", count)
	}
}

func TestNotificationService_GetUnreadCount_RepoError(t *testing.T) {
	repo := newMockNotificationRepo()
	repo.unreadErr = errors.New("db error")
	svc := NewNotificationService(repo)

	_, err := svc.GetUnreadCount(context.Background(), "user-1")
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: MarkRead
// ---------------------------------------------------------------------------

func TestNotificationService_MarkRead_Success(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	err := svc.MarkRead(context.Background(), "notif-1", "user-1")
	if err != nil {
		t.Fatalf("MarkRead: %v", err)
	}
}

func TestNotificationService_MarkRead_NotFound(t *testing.T) {
	repo := newMockNotificationRepo()
	repo.markReadErr = errors.New("not found")
	svc := NewNotificationService(repo)

	err := svc.MarkRead(context.Background(), "nonexistent", "user-1")
	if !errors.Is(err, ErrNotificationNotFound) {
		t.Errorf("expected ErrNotificationNotFound, got %v", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: MarkAllRead
// ---------------------------------------------------------------------------

func TestNotificationService_MarkAllRead_Success(t *testing.T) {
	repo := newMockNotificationRepo()
	svc := NewNotificationService(repo)

	err := svc.MarkAllRead(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("MarkAllRead: %v", err)
	}
}

func TestNotificationService_MarkAllRead_RepoError(t *testing.T) {
	repo := newMockNotificationRepo()
	repo.markAllErr = errors.New("db error")
	svc := NewNotificationService(repo)

	err := svc.MarkAllRead(context.Background(), "user-1")
	if err == nil {
		t.Error("expected error when repo fails")
	}
}
