package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
	"github.com/anynote/backend/internal/testutil"
)

// ---------------------------------------------------------------------------
// Mock NotificationService
// ---------------------------------------------------------------------------

type mockNotificationService struct {
	listFn      func(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, error)
	unreadFn    func(ctx context.Context, userID string) (int, error)
	markReadFn  func(ctx context.Context, id, userID string) error
	markAllFn   func(ctx context.Context, userID string) error
}

func (m *mockNotificationService) CreateNotification(_ context.Context, _, _, _, _ string, _ json.RawMessage) error {
	return nil
}

func (m *mockNotificationService) ListNotifications(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, error) {
	if m.listFn != nil {
		return m.listFn(ctx, userID, limit, offset)
	}
	return []domain.Notification{}, nil
}

func (m *mockNotificationService) GetUnreadCount(ctx context.Context, userID string) (int, error) {
	if m.unreadFn != nil {
		return m.unreadFn(ctx, userID)
	}
	return 0, nil
}

func (m *mockNotificationService) MarkRead(ctx context.Context, id, userID string) error {
	if m.markReadFn != nil {
		return m.markReadFn(ctx, id, userID)
	}
	return nil
}

func (m *mockNotificationService) MarkAllRead(ctx context.Context, userID string) error {
	if m.markAllFn != nil {
		return m.markAllFn(ctx, userID)
	}
	return nil
}

func (m *mockNotificationService) GetNotificationPreferences(_ context.Context, _ string) (json.RawMessage, error) {
	return json.RawMessage(`{"pushNotifications":true,"reminderNotifications":true}`), nil
}

func (m *mockNotificationService) UpdateNotificationPreferences(_ context.Context, _ string, prefs json.RawMessage) error {
	return nil
}

// ---------------------------------------------------------------------------
// Router setup helper
// ---------------------------------------------------------------------------

func setupNotificationRouter(svc service.NotificationService) *chi.Mux {
	r := chi.NewRouter()
	h := NewNotificationHandler(svc)
	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testutil.DefaultTestJWTSecret))
		r.Get("/api/v1/notifications", h.ListNotifications)
		r.Get("/api/v1/notifications/unread-count", h.GetUnreadCount)
		r.Post("/api/v1/notifications/read-all", h.MarkAllRead)
		r.Post("/api/v1/notifications/{id}/read", h.MarkRead)
	})
	return r
}

// ---------------------------------------------------------------------------
// Tests: ListNotifications
// ---------------------------------------------------------------------------

func TestNotificationHandler_ListNotifications_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{
		listFn: func(_ context.Context, uid string, limit, offset int) ([]domain.Notification, error) {
			return []domain.Notification{
				{ID: "n1", UserID: uid, Type: "system", Title: "Welcome", Body: "Hello"},
			}, nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications?limit=10&offset=0", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]interface{}
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	notifications, ok := resp["notifications"].([]interface{})
	if !ok || len(notifications) != 1 {
		t.Errorf("expected 1 notification, got %v", resp["notifications"])
	}
}

func TestNotificationHandler_ListNotifications_DefaultPagination(t *testing.T) {
	userID := uuid.New()
	var capturedLimit, capturedOffset int
	svc := &mockNotificationService{
		listFn: func(_ context.Context, _ string, limit, offset int) ([]domain.Notification, error) {
			capturedLimit = limit
			capturedOffset = offset
			return []domain.Notification{}, nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedLimit != 20 {
		t.Errorf("default limit = %d, want 20", capturedLimit)
	}
	if capturedOffset != 0 {
		t.Errorf("default offset = %d, want 0", capturedOffset)
	}
}

func TestNotificationHandler_ListNotifications_CustomPagination(t *testing.T) {
	userID := uuid.New()
	var capturedLimit, capturedOffset int
	svc := &mockNotificationService{
		listFn: func(_ context.Context, _ string, limit, offset int) ([]domain.Notification, error) {
			capturedLimit = limit
			capturedOffset = offset
			return []domain.Notification{}, nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications?limit=50&offset=100", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedLimit != 50 {
		t.Errorf("limit = %d, want 50", capturedLimit)
	}
	if capturedOffset != 100 {
		t.Errorf("offset = %d, want 100", capturedOffset)
	}
}

func TestNotificationHandler_ListNotifications_InvalidLimit(t *testing.T) {
	userID := uuid.New()
	var capturedLimit int
	svc := &mockNotificationService{
		listFn: func(_ context.Context, _ string, limit, _ int) ([]domain.Notification, error) {
			capturedLimit = limit
			return []domain.Notification{}, nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications?limit=abc", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	// Should fall back to default 20.
	if capturedLimit != 20 {
		t.Errorf("limit with invalid param = %d, want 20 (default)", capturedLimit)
	}
}

func TestNotificationHandler_ListNotifications_Unauthorized(t *testing.T) {
	svc := &mockNotificationService{}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestNotificationHandler_ListNotifications_ServiceError(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{
		listFn: func(_ context.Context, _ string, _, _ int) ([]domain.Notification, error) {
			return nil, errors.New("db error")
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestNotificationHandler_ListNotifications_PassesUserID(t *testing.T) {
	userID := uuid.New()
	var capturedUserID string
	svc := &mockNotificationService{
		listFn: func(_ context.Context, uid string, _, _ int) ([]domain.Notification, error) {
			capturedUserID = uid
			return []domain.Notification{}, nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedUserID != userID.String() {
		t.Errorf("service received userID = %q, want %q", capturedUserID, userID.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GetUnreadCount
// ---------------------------------------------------------------------------

func TestNotificationHandler_GetUnreadCount_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{
		unreadFn: func(_ context.Context, _ string) (int, error) {
			return 5, nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications/unread-count", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]interface{}
	json.NewDecoder(rec.Body).Decode(&resp)
	count := resp["unread_count"].(float64)
	if count != 5 {
		t.Errorf("unread_count = %v, want 5", count)
	}
}

func TestNotificationHandler_GetUnreadCount_Zero(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications/unread-count", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]interface{}
	json.NewDecoder(rec.Body).Decode(&resp)
	count := resp["unread_count"].(float64)
	if count != 0 {
		t.Errorf("unread_count = %v, want 0", count)
	}
}

func TestNotificationHandler_GetUnreadCount_Unauthorized(t *testing.T) {
	svc := &mockNotificationService{}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications/unread-count", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestNotificationHandler_GetUnreadCount_ServiceError(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{
		unreadFn: func(_ context.Context, _ string) (int, error) {
			return 0, errors.New("db error")
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications/unread-count", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: MarkRead
// ---------------------------------------------------------------------------

func TestNotificationHandler_MarkRead_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/n123/read", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestNotificationHandler_MarkRead_PassesCorrectArgs(t *testing.T) {
	userID := uuid.New()
	var capturedID, capturedUserID string
	svc := &mockNotificationService{
		markReadFn: func(_ context.Context, id, uid string) error {
			capturedID = id
			capturedUserID = uid
			return nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/notif-456/read", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedID != "notif-456" {
		t.Errorf("notification ID = %q, want notif-456", capturedID)
	}
	if capturedUserID != userID.String() {
		t.Errorf("userID = %q, want %q", capturedUserID, userID.String())
	}
}

func TestNotificationHandler_MarkRead_NotFound(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{
		markReadFn: func(_ context.Context, _, _ string) error {
			return service.ErrNotificationNotFound
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/nonexistent/read", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestNotificationHandler_MarkRead_Unauthorized(t *testing.T) {
	svc := &mockNotificationService{}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/n1/read", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

// ---------------------------------------------------------------------------
// Tests: MarkAllRead
// ---------------------------------------------------------------------------

func TestNotificationHandler_MarkAllRead_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/read-all", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestNotificationHandler_MarkAllRead_PassesUserID(t *testing.T) {
	userID := uuid.New()
	var capturedUserID string
	svc := &mockNotificationService{
		markAllFn: func(_ context.Context, uid string) error {
			capturedUserID = uid
			return nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/read-all", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedUserID != userID.String() {
		t.Errorf("service received userID = %q, want %q", capturedUserID, userID.String())
	}
}

func TestNotificationHandler_MarkAllRead_ServiceError(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{
		markAllFn: func(_ context.Context, _ string) error {
			return errors.New("db error")
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/read-all", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestNotificationHandler_MarkAllRead_Unauthorized(t *testing.T) {
	svc := &mockNotificationService{}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/read-all", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

// ---------------------------------------------------------------------------
// Tests: Multiple notifications listing
// ---------------------------------------------------------------------------

func TestNotificationHandler_ListNotifications_Multiple(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{
		listFn: func(_ context.Context, _ string, _, _ int) ([]domain.Notification, error) {
			return []domain.Notification{
				{ID: "n1", Type: "system", Title: "T1", Body: "B1"},
				{ID: "n2", Type: "payment", Title: "T2", Body: "B2"},
				{ID: "n3", Type: "reminder", Title: "T3", Body: "B3"},
			}, nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications?limit=3", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]interface{}
	json.NewDecoder(rec.Body).Decode(&resp)
	notifications := resp["notifications"].([]interface{})
	if len(notifications) != 3 {
		t.Errorf("expected 3 notifications, got %d", len(notifications))
	}
	// Verify pagination metadata.
	if resp["limit"].(float64) != 3 {
		t.Errorf("limit = %v, want 3", resp["limit"])
	}
}

// ---------------------------------------------------------------------------
// Tests: Cross-user isolation
// ---------------------------------------------------------------------------

func TestNotificationHandler_ListNotifications_CrossUserIsolation(t *testing.T) {
	userA := uuid.New()
	userB := uuid.New()

	var capturedUserID string
	svc := &mockNotificationService{
		listFn: func(_ context.Context, uid string, _, _ int) ([]domain.Notification, error) {
			capturedUserID = uid
			return []domain.Notification{}, nil
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userA.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedUserID == userB.String() {
		t.Error("service received user B's ID when user A's token was used")
	}
	if capturedUserID != userA.String() {
		t.Errorf("service received userID = %q, want %q", capturedUserID, userA.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: Edge cases
// ---------------------------------------------------------------------------

func TestNotificationHandler_MarkRead_ServiceInternalError(t *testing.T) {
	userID := uuid.New()
	svc := &mockNotificationService{
		markReadFn: func(_ context.Context, _, _ string) error {
			return fmt.Errorf("unexpected db error")
		},
	}
	router := setupNotificationRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/n1/read", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d; body: %s", rec.Code, rec.Body.String())
	}
}
