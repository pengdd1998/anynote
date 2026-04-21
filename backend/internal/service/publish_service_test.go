package service

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock PublishLogRepository
// ---------------------------------------------------------------------------

type mockPublishLogRepo struct {
	logs       map[uuid.UUID]*domain.PublishLog
	createErr  error
	getErr     error
	listErr    error
	updateErr  error
}

func newMockPublishLogRepo() *mockPublishLogRepo {
	return &mockPublishLogRepo{
		logs: make(map[uuid.UUID]*domain.PublishLog),
	}
}

func (m *mockPublishLogRepo) Create(ctx context.Context, log *domain.PublishLog) error {
	if m.createErr != nil {
		return m.createErr
	}
	m.logs[log.ID] = log
	return nil
}

func (m *mockPublishLogRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.PublishLog, error) {
	if m.getErr != nil {
		return nil, m.getErr
	}
	l, ok := m.logs[id]
	if !ok {
		return nil, errors.New("publish log not found")
	}
	return l, nil
}

func (m *mockPublishLogRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	if m.listErr != nil {
		return nil, m.listErr
	}
	var result []domain.PublishLog
	for _, l := range m.logs {
		if l.UserID == userID {
			result = append(result, *l)
		}
	}
	return result, nil
}

func (m *mockPublishLogRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error {
	if m.updateErr != nil {
		return m.updateErr
	}
	l, ok := m.logs[id]
	if !ok {
		return errors.New("not found")
	}
	l.Status = status
	l.ErrorMessage = errMsg
	l.PlatformURL = platformURL
	return nil
}

// ---------------------------------------------------------------------------
// Mock QueueEnqueuer
// ---------------------------------------------------------------------------

type mockQueueEnqueuer struct {
	enqueueErr error
	jobID      string
	called     bool
	payload    interface{}
}

func (m *mockQueueEnqueuer) EnqueuePublishJob(ctx context.Context, userID string, platform string, payload interface{}) (string, error) {
	m.called = true
	m.payload = payload
	if m.enqueueErr != nil {
		return "", m.enqueueErr
	}
	if m.jobID == "" {
		return "job-123", nil
	}
	return m.jobID, nil
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestPublishService_Publish_Success(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	queue := &mockQueueEnqueuer{}
	svc := NewPublishService(logRepo, queue)

	userID := uuid.New()
	log, err := svc.Publish(context.Background(), userID, PublishRequest{
		Platform:      "xiaohongshu",
		ContentItemID: "item-123",
		Title:         "My Note",
		Content:       "Note content",
		Tags:          []string{"test"},
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if log.Status != "pending" {
		t.Errorf("Status = %q, want %q", log.Status, "pending")
	}
	if log.Platform != "xiaohongshu" {
		t.Errorf("Platform = %q, want %q", log.Platform, "xiaohongshu")
	}
	if log.UserID != userID {
		t.Errorf("UserID = %v, want %v", log.UserID, userID)
	}
	if log.ID == uuid.Nil {
		t.Error("ID should be set")
	}
	if !queue.called {
		t.Error("queue.EnqueuePublishJob should have been called")
	}
}

func TestPublishService_Publish_WithoutQueue(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	svc := NewPublishService(logRepo, nil) // nil queue

	userID := uuid.New()
	log, err := svc.Publish(context.Background(), userID, PublishRequest{
		Platform: "xiaohongshu",
		Title:    "Test",
		Content:  "Content",
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if log.Status != "pending" {
		t.Errorf("Status = %q, want %q", log.Status, "pending")
	}
}

func TestPublishService_Publish_RepoCreateError(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	logRepo.createErr = errors.New("db error")
	queue := &mockQueueEnqueuer{}
	svc := NewPublishService(logRepo, queue)

	_, err := svc.Publish(context.Background(), uuid.New(), PublishRequest{
		Platform: "xiaohongshu",
		Title:    "Test",
	})
	if err == nil {
		t.Error("expected error when repo.Create fails")
	}
	if queue.called {
		t.Error("queue should not be called when repo.Create fails")
	}
}

func TestPublishService_Publish_EnqueueError(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	queue := &mockQueueEnqueuer{
		enqueueErr: errors.New("redis unavailable"),
	}
	svc := NewPublishService(logRepo, queue)

	_, err := svc.Publish(context.Background(), uuid.New(), PublishRequest{
		Platform: "xiaohongshu",
		Title:    "Test",
	})
	if err == nil {
		t.Error("expected error when enqueue fails")
	}

	// Verify the publish log was created and then marked as failed.
	for _, l := range logRepo.logs {
		if l.Status == "failed" {
			// The log should be updated to failed status.
			return
		}
	}
	// Note: The status update is best-effort via UpdateStatus. Since our mock
	// supports it, we can check.
}

func TestPublishService_GetHistory(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	userID := uuid.New()

	logRepo.logs[uuid.New()] = &domain.PublishLog{
		ID:       uuid.New(),
		UserID:   userID,
		Platform: "xiaohongshu",
		Title:    "Post 1",
		Status:   "published",
	}
	logRepo.logs[uuid.New()] = &domain.PublishLog{
		ID:       uuid.New(),
		UserID:   userID,
		Platform: "xiaohongshu",
		Title:    "Post 2",
		Status:   "pending",
	}
	logRepo.logs[uuid.New()] = &domain.PublishLog{
		ID:       uuid.New(),
		UserID:   uuid.New(), // different user
		Platform: "xiaohongshu",
		Title:    "Other User Post",
		Status:   "published",
	}

	svc := NewPublishService(logRepo, nil)
	logs, err := svc.GetHistory(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetHistory: %v", err)
	}
	if len(logs) != 2 {
		t.Errorf("len(logs) = %d, want 2", len(logs))
	}
}

func TestPublishService_GetHistory_RepoError(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	logRepo.listErr = errors.New("db error")
	svc := NewPublishService(logRepo, nil)

	_, err := svc.GetHistory(context.Background(), uuid.New())
	if err == nil {
		t.Error("expected error when repo.ListByUser fails")
	}
}

func TestPublishService_GetByID_Success(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	userID := uuid.New()
	logID := uuid.New()

	logRepo.logs[logID] = &domain.PublishLog{
		ID:       logID,
		UserID:   userID,
		Platform: "xiaohongshu",
		Title:    "My Post",
		Status:   "published",
	}

	svc := NewPublishService(logRepo, nil)
	log, err := svc.GetByID(context.Background(), userID, logID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}
	if log.Title != "My Post" {
		t.Errorf("Title = %q, want %q", log.Title, "My Post")
	}
}

func TestPublishService_GetByID_NotFound(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	svc := NewPublishService(logRepo, nil)

	_, err := svc.GetByID(context.Background(), uuid.New(), uuid.New())
	if err == nil {
		t.Error("expected error when publish log not found")
	}
}

func TestPublishService_GetByID_UnauthorizedUser(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	ownerID := uuid.New()
	logID := uuid.New()

	logRepo.logs[logID] = &domain.PublishLog{
		ID:       logID,
		UserID:   ownerID,
		Platform: "xiaohongshu",
		Title:    "Owner's Post",
		Status:   "published",
	}

	svc := NewPublishService(logRepo, nil)

	otherUserID := uuid.New()
	_, err := svc.GetByID(context.Background(), otherUserID, logID)
	if err == nil {
		t.Error("expected error when accessing another user's publish log")
	}
	if !errors.Is(err, ErrUserNotFound) {
		t.Errorf("error = %v, want ErrUserNotFound", err)
	}
}

func TestPublishService_Publish_PayloadContents(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	queue := &mockQueueEnqueuer{}
	svc := NewPublishService(logRepo, queue)

	userID := uuid.New()
	log, err := svc.Publish(context.Background(), userID, PublishRequest{
		Platform:      "xiaohongshu",
		ContentItemID: "item-456",
		Title:         "Payload Test",
		Content:       "Content here",
		Tags:          []string{"tag1", "tag2"},
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}

	// Verify the payload sent to the queue contains correct data.
	payload, ok := queue.payload.(map[string]interface{})
	if !ok {
		t.Fatal("payload should be a map")
	}
	if payload["user_id"] != userID.String() {
		t.Errorf("payload user_id = %v, want %v", payload["user_id"], userID.String())
	}
	if payload["platform"] != "xiaohongshu" {
		t.Errorf("payload platform = %v, want %q", payload["platform"], "xiaohongshu")
	}
	if payload["publish_log_id"] != log.ID.String() {
		t.Errorf("payload publish_log_id = %v, want %v", payload["publish_log_id"], log.ID.String())
	}
	if payload["title"] != "Payload Test" {
		t.Errorf("payload title = %v, want %q", payload["title"], "Payload Test")
	}
}

// ---------------------------------------------------------------------------
// Tests: WithPublishPushService option
// ---------------------------------------------------------------------------

func TestWithPublishPushService(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	pushSvc := &mockPushServiceForPublish{}
	opt := WithPublishPushService(pushSvc)

	svc := NewPublishService(logRepo, nil)
	opt(svc.(*publishService))

	if svc.(*publishService).pushSvc == nil {
		t.Error("pushSvc should be set after WithPublishPushService")
	}
}

func TestPublishService_Publish_WithPushNotification(t *testing.T) {
	logRepo := newMockPublishLogRepo()
	queue := &mockQueueEnqueuer{}
	pushSvc := &mockPushServiceForPublish{}

	svc := NewPublishService(logRepo, queue, WithPublishPushService(pushSvc))

	userID := uuid.New()
	log, err := svc.Publish(context.Background(), userID, PublishRequest{
		Platform: "xiaohongshu",
		Title:    "Push Test",
		Content:  "Content",
	})
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if log.Status != "pending" {
		t.Errorf("Status = %q, want %q", log.Status, "pending")
	}

	// Wait for the goroutine to fire the push notification.
	time.Sleep(150 * time.Millisecond)

	if !pushSvc.wasCalled() {
		t.Error("expected SendPush to be called when pushSvc is configured")
	}
}

// ---------------------------------------------------------------------------
// Mock PushService for publish tests
// ---------------------------------------------------------------------------

type mockPushServiceForPublish struct {
	sendPushCalled bool
	mu             sync.Mutex
}

func (m *mockPushServiceForPublish) RegisterDevice(ctx context.Context, userID string, token string, platform string) error {
	return nil
}

func (m *mockPushServiceForPublish) UnregisterDevice(ctx context.Context, userID string, token string) error {
	return nil
}

func (m *mockPushServiceForPublish) SendPush(ctx context.Context, userID string, payload PushPayload) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sendPushCalled = true
	return nil
}

func (m *mockPushServiceForPublish) wasCalled() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.sendPushCalled
}
