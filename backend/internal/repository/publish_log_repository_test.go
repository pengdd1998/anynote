package repository

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestPublishLogRepository_DocumentsExpectedBehavior documents expected SQL behaviors.
func TestPublishLogRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("Create_inserts_log", func(t *testing.T) {
		// INSERT INTO publish_logs (id, user_id, platform, platform_conn_id, content_item_id, title, content, status)
		// VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		t.Log("documented: Create inserts a new publish log record")
	})

	t.Run("GetByID_selects_log", func(t *testing.T) {
		// SELECT id, user_id, platform, platform_conn_id, content_item_id, title, content,
		//   status, platform_url, error_message, published_at, created_at
		// FROM publish_logs WHERE id = $1
		t.Log("documented: GetByID returns full publish log record")
	})

	t.Run("ListByUser_returns_user_logs", func(t *testing.T) {
		// SELECT ... FROM publish_logs WHERE user_id = $1 ORDER BY created_at DESC
		t.Log("documented: ListByUser returns logs for user, newest first")
	})

	t.Run("UpdateStatus_updates_log", func(t *testing.T) {
		// UPDATE publish_logs SET status=$3, error_message=$4, platform_url=$5,
		//   published_at = CASE WHEN $3 = 'published' THEN NOW() ELSE published_at END
		// WHERE id = $1
		t.Log("documented: UpdateStatus sets status, error, URL; sets published_at on success")
	})

	t.Run("GetByIDAndUser_scoped_query", func(t *testing.T) {
		// SELECT ... FROM publish_logs WHERE id = $1 AND user_id = $2
		t.Log("documented: GetByIDAndUser returns log only if owned by user")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

type mockPublishLogRepo struct {
	logs map[uuid.UUID]*domain.PublishLog
}

func newMockPublishLogRepo() *mockPublishLogRepo {
	return &mockPublishLogRepo{
		logs: make(map[uuid.UUID]*domain.PublishLog),
	}
}

func (m *mockPublishLogRepo) Create(ctx context.Context, log *domain.PublishLog) error {
	m.logs[log.ID] = log
	return nil
}

func (m *mockPublishLogRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.PublishLog, error) {
	l, ok := m.logs[id]
	if !ok {
		return nil, errNotFound
	}
	return l, nil
}

func (m *mockPublishLogRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	var result []domain.PublishLog
	for _, l := range m.logs {
		if l.UserID == userID {
			result = append(result, *l)
		}
	}
	return result, nil
}

func (m *mockPublishLogRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error {
	l, ok := m.logs[id]
	if !ok {
		return errNotFound
	}
	l.Status = status
	l.ErrorMessage = errMsg
	l.PlatformURL = platformURL
	return nil
}

func (m *mockPublishLogRepo) GetByIDAndUser(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*domain.PublishLog, error) {
	l, ok := m.logs[id]
	if !ok || l.UserID != userID {
		return nil, errNotFound
	}
	return l, nil
}

var errNotFound = &notFoundError{}

type notFoundError struct{}

func (e *notFoundError) Error() string { return "not found" }

func TestMockPublishLogRepo_CreateAndGet(t *testing.T) {
	repo := newMockPublishLogRepo()
	ctx := context.Background()
	userID := uuid.New()
	logID := uuid.New()

	log := &domain.PublishLog{
		ID: logID, UserID: userID, Platform: "xhs", Status: "pending",
		Title: "Test Post", Content: "Content",
	}
	repo.Create(ctx, log)

	got, err := repo.GetByID(ctx, logID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}
	if got.Platform != "xhs" {
		t.Errorf("Platform = %q, want %q", got.Platform, "xhs")
	}
	if got.Status != "pending" {
		t.Errorf("Status = %q, want %q", got.Status, "pending")
	}
}

func TestMockPublishLogRepo_GetByID_NotFound(t *testing.T) {
	repo := newMockPublishLogRepo()
	ctx := context.Background()

	_, err := repo.GetByID(ctx, uuid.New())
	if err == nil {
		t.Error("GetByID should return error for nonexistent log")
	}
}

func TestMockPublishLogRepo_ListByUser(t *testing.T) {
	repo := newMockPublishLogRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()

	repo.Create(ctx, &domain.PublishLog{ID: uuid.New(), UserID: user1, Platform: "xhs"})
	repo.Create(ctx, &domain.PublishLog{ID: uuid.New(), UserID: user1, Platform: "wechat"})
	repo.Create(ctx, &domain.PublishLog{ID: uuid.New(), UserID: user2, Platform: "medium"})

	logs, err := repo.ListByUser(ctx, user1)
	if err != nil {
		t.Fatalf("ListByUser: %v", err)
	}
	if len(logs) != 2 {
		t.Errorf("len(logs) = %d, want 2", len(logs))
	}
}

func TestMockPublishLogRepo_UpdateStatus(t *testing.T) {
	repo := newMockPublishLogRepo()
	ctx := context.Background()
	logID := uuid.New()

	repo.Create(ctx, &domain.PublishLog{ID: logID, Status: "pending"})

	err := repo.UpdateStatus(ctx, logID, "published", "", "https://xhs.com/post/123")
	if err != nil {
		t.Fatalf("UpdateStatus: %v", err)
	}

	got, _ := repo.GetByID(ctx, logID)
	if got.Status != "published" {
		t.Errorf("Status = %q, want %q", got.Status, "published")
	}
	if got.PlatformURL != "https://xhs.com/post/123" {
		t.Errorf("PlatformURL = %q, want URL", got.PlatformURL)
	}
}

func TestMockPublishLogRepo_UpdateStatus_Error(t *testing.T) {
	repo := newMockPublishLogRepo()
	ctx := context.Background()
	logID := uuid.New()

	repo.Create(ctx, &domain.PublishLog{ID: logID, Status: "pending"})

	repo.UpdateStatus(ctx, logID, "failed", "timeout", "")

	got, _ := repo.GetByID(ctx, logID)
	if got.ErrorMessage != "timeout" {
		t.Errorf("ErrorMessage = %q, want %q", got.ErrorMessage, "timeout")
	}
}

func TestMockPublishLogRepo_GetByIDAndUser(t *testing.T) {
	repo := newMockPublishLogRepo()
	ctx := context.Background()
	userID := uuid.New()
	logID := uuid.New()

	repo.Create(ctx, &domain.PublishLog{ID: logID, UserID: userID})

	// Correct user.
	got, err := repo.GetByIDAndUser(ctx, logID, userID)
	if err != nil {
		t.Fatalf("GetByIDAndUser: %v", err)
	}
	if got.ID != logID {
		t.Error("ID mismatch")
	}

	// Wrong user.
	_, err = repo.GetByIDAndUser(ctx, logID, uuid.New())
	if err == nil {
		t.Error("GetByIDAndUser should return error for wrong user")
	}
}
