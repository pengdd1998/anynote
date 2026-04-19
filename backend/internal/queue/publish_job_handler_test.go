package queue

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/hibiken/asynq"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/platform"
)

// ---------------------------------------------------------------------------
// Mocks for publish job handler dependencies
// ---------------------------------------------------------------------------

type mockPublishLogRepo struct {
	updateStatusFn func(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error
}

func (m *mockPublishLogRepo) Create(ctx context.Context, log *domain.PublishLog) error {
	return nil
}

func (m *mockPublishLogRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.PublishLog, error) {
	return nil, nil
}

func (m *mockPublishLogRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	return nil, nil
}

func (m *mockPublishLogRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error {
	if m.updateStatusFn != nil {
		return m.updateStatusFn(ctx, id, status, errMsg, platformURL)
	}
	return nil
}

type mockPlatformConnRepo struct {
	getByPlatformFn func(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error)
}

func (m *mockPlatformConnRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error) {
	return nil, nil
}

func (m *mockPlatformConnRepo) GetByPlatform(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error) {
	if m.getByPlatformFn != nil {
		return m.getByPlatformFn(ctx, userID, platform)
	}
	return nil, errors.New("not found")
}

func (m *mockPlatformConnRepo) Create(ctx context.Context, conn *domain.PlatformConnection) error {
	return nil
}

func (m *mockPlatformConnRepo) Delete(ctx context.Context, id uuid.UUID) error {
	return nil
}

func (m *mockPlatformConnRepo) Update(ctx context.Context, conn *domain.PlatformConnection) error {
	return nil
}

type mockPlatformAdapter struct {
	publishFn func(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error)
}

func (m *mockPlatformAdapter) Name() string { return "mock" }

func (m *mockPlatformAdapter) StartAuth(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
	return nil, nil, nil
}

func (m *mockPlatformAdapter) PollAuth(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
	return nil, nil
}

func (m *mockPlatformAdapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
	if m.publishFn != nil {
		return m.publishFn(ctx, encryptedAuth, masterKey, params)
	}
	return &platform.PublishResult{PlatformURL: "https://mock.example.com/post/1", PlatformID: "post-1"}, nil
}

func (m *mockPlatformAdapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	return "live", nil
}

func (m *mockPlatformAdapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	return nil
}

// ---------------------------------------------------------------------------
// Tests: HandleTask — successful publish flow
// ---------------------------------------------------------------------------

func TestPublishJobHandler_HandleTask_Success(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()
	masterKey := []byte("0123456789abcdef0123456789abcdef")

	var capturedStatus string
	publishRepo := &mockPublishLogRepo{
		updateStatusFn: func(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error {
			capturedStatus = status
			return nil
		},
	}

	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return &domain.PlatformConnection{
				ID:            uuid.New(),
				UserID:        uid,
				Platform:      p,
				EncryptedAuth: []byte("encrypted-auth-data"),
			}, nil
		},
	}

	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{
		publishFn: func(ctx context.Context, encryptedAuth []byte, mk []byte, params platform.PublishParams) (*platform.PublishResult, error) {
			if params.Title != "Test Title" {
				t.Errorf("Title = %q, want %q", params.Title, "Test Title")
			}
			if params.Content != "Test Content" {
				t.Errorf("Content = %q, want %q", params.Content, "Test Content")
			}
			return &platform.PublishResult{
				PlatformURL: "https://example.com/post/123",
				PlatformID:  "post-123",
			}, nil
		},
	}
	registry.Register("mock", adapter)

	h := NewPublishJobHandler(registry, publishRepo, platformRepo, masterKey)

	payload := PublishJobPayload{
		UserID:       userID.String(),
		Platform:     "mock",
		PublishLogID: logID.String(),
		Title:        "Test Title",
		Content:      "Test Content",
		Tags:         []string{"test"},
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePublish, data)

	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Fatalf("HandleTask: %v", err)
	}

	// The last status should be "published" (set by the final UpdateStatus).
	// Note: the handler calls UpdateStatus multiple times: "publishing", then "published".
	// Since our mock only captures the latest, it should be "published".
	if capturedStatus != "published" {
		t.Errorf("final status = %q, want %q", capturedStatus, "published")
	}
}

func TestPublishJobHandler_HandleTask_UnsupportedPlatform(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()

	publishRepo := &mockPublishLogRepo{}
	platformRepo := &mockPlatformConnRepo{}
	registry := platform.NewRegistry() // empty registry, no adapters

	h := NewPublishJobHandler(registry, publishRepo, platformRepo, nil)

	payload := PublishJobPayload{
		UserID:       userID.String(),
		Platform:     "nonexistent",
		PublishLogID: logID.String(),
		Title:        "Test",
		Content:      "Content",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePublish, data)

	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Errorf("unsupported platform should be non-retriable (nil error), got: %v", err)
	}
}

func TestPublishJobHandler_HandleTask_PlatformNotConnected(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()

	publishRepo := &mockPublishLogRepo{}
	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return nil, errors.New("no connection found")
		},
	}
	registry := platform.NewRegistry()
	registry.Register("mock", &mockPlatformAdapter{})

	h := NewPublishJobHandler(registry, publishRepo, platformRepo, nil)

	payload := PublishJobPayload{
		UserID:       userID.String(),
		Platform:     "mock",
		PublishLogID: logID.String(),
		Title:        "Test",
		Content:      "Content",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePublish, data)

	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Errorf("platform not connected should be non-retriable (nil error), got: %v", err)
	}
}

func TestPublishJobHandler_HandleTask_NoAuthData(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()

	publishRepo := &mockPublishLogRepo{}
	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return &domain.PlatformConnection{
				ID:            uuid.New(),
				UserID:        uid,
				Platform:      p,
				EncryptedAuth: []byte{}, // empty auth
			}, nil
		},
	}
	registry := platform.NewRegistry()
	registry.Register("mock", &mockPlatformAdapter{})

	h := NewPublishJobHandler(registry, publishRepo, platformRepo, nil)

	payload := PublishJobPayload{
		UserID:       userID.String(),
		Platform:     "mock",
		PublishLogID: logID.String(),
		Title:        "Test",
		Content:      "Content",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePublish, data)

	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Errorf("no auth data should be non-retriable (nil error), got: %v", err)
	}
}

func TestPublishJobHandler_HandleTask_PublishFails(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()
	masterKey := []byte("0123456789abcdef0123456789abcdef")

	publishRepo := &mockPublishLogRepo{}
	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return &domain.PlatformConnection{
				ID:            uuid.New(),
				UserID:        uid,
				Platform:      p,
				EncryptedAuth: []byte("auth-data"),
			}, nil
		},
	}
	registry := platform.NewRegistry()
	registry.Register("mock", &mockPlatformAdapter{
		publishFn: func(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
			return nil, errors.New("publish timeout")
		},
	})

	h := NewPublishJobHandler(registry, publishRepo, platformRepo, masterKey)

	payload := PublishJobPayload{
		UserID:       userID.String(),
		Platform:     "mock",
		PublishLogID: logID.String(),
		Title:        "Test",
		Content:      "Content",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePublish, data)

	err := h.HandleTask(context.Background(), task)
	// Publish failure should be retriable (return error to asynq)
	if err == nil {
		t.Error("expected retriable error when publish fails")
	}
}

func TestPublishJobHandler_HandleTask_UpdateStatusError(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()
	masterKey := []byte("0123456789abcdef0123456789abcdef")

	// The handler calls UpdateStatus multiple times; we report error on the
	// "publishing" status update but the handler continues anyway.
	callCount := 0
	publishRepo := &mockPublishLogRepo{
		updateStatusFn: func(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error {
			callCount++
			if status == "publishing" {
				return errors.New("db temporarily unavailable")
			}
			return nil
		},
	}

	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return &domain.PlatformConnection{
				ID:            uuid.New(),
				UserID:        uid,
				Platform:      p,
				EncryptedAuth: []byte("auth"),
			}, nil
		},
	}

	registry := platform.NewRegistry()
	registry.Register("mock", &mockPlatformAdapter{})

	h := NewPublishJobHandler(registry, publishRepo, platformRepo, masterKey)

	payload := PublishJobPayload{
		UserID:       userID.String(),
		Platform:     "mock",
		PublishLogID: logID.String(),
		Title:        "Test",
		Content:      "Content",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePublish, data)

	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Fatalf("HandleTask should succeed even when UpdateStatus fails on intermediate step: %v", err)
	}
	if callCount < 2 {
		t.Errorf("UpdateStatus called %d times, expected at least 2", callCount)
	}
}

// ---------------------------------------------------------------------------
// Tests: PublishJobPayload serialization
// ---------------------------------------------------------------------------

func TestPublishJobPayload_Serialization(t *testing.T) {
	payload := PublishJobPayload{
		UserID:           uuid.New().String(),
		Platform:         "xiaohongshu",
		PublishLogID:     uuid.New().String(),
		Title:            "Test Note",
		Content:          "Some content",
		Tags:             []string{"tag1", "tag2"},
		EncryptedAuthRef: "enc-ref-123",
	}

	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded PublishJobPayload
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.UserID != payload.UserID {
		t.Errorf("UserID = %q, want %q", decoded.UserID, payload.UserID)
	}
	if decoded.Platform != payload.Platform {
		t.Errorf("Platform = %q, want %q", decoded.Platform, payload.Platform)
	}
	if decoded.Title != payload.Title {
		t.Errorf("Title = %q, want %q", decoded.Title, payload.Title)
	}
	if decoded.Content != payload.Content {
		t.Errorf("Content = %q, want %q", decoded.Content, payload.Content)
	}
	if len(decoded.Tags) != 2 {
		t.Fatalf("Tags len = %d, want 2", len(decoded.Tags))
	}
	if decoded.Tags[0] != "tag1" || decoded.Tags[1] != "tag2" {
		t.Errorf("Tags = %v, want [tag1, tag2]", decoded.Tags)
	}
	if decoded.EncryptedAuthRef != payload.EncryptedAuthRef {
		t.Errorf("EncryptedAuthRef = %q, want %q", decoded.EncryptedAuthRef, payload.EncryptedAuthRef)
	}
}

func TestPublishJobPayload_EmptyTags(t *testing.T) {
	payload := PublishJobPayload{
		UserID:       uuid.New().String(),
		Platform:     "xiaohongshu",
		PublishLogID: uuid.New().String(),
		Title:        "No Tags",
		Content:      "Content",
	}

	data, _ := json.Marshal(payload)
	var decoded PublishJobPayload
	json.Unmarshal(data, &decoded)

	if decoded.Tags != nil {
		t.Errorf("Tags should be nil when not provided, got %v", decoded.Tags)
	}
}
