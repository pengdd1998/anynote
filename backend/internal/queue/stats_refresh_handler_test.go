package queue

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/platform"
)

// mockStatsAdapter wraps a base adapter and optionally implements
// platform.StatsFetcher.
type mockStatsAdapter struct {
	mockPlatformAdapter
	fetchStatsFn func(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformPostID string) (*platform.PostStats, error)
}

func (m *mockStatsAdapter) FetchStats(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformPostID string) (*platform.PostStats, error) {
	if m.fetchStatsFn != nil {
		return m.fetchStatsFn(ctx, encryptedAuth, masterKey, platformPostID)
	}
	return &platform.PostStats{}, nil
}

// statsMockLogRepo is a PublishLogRepository double with hooks for the
// stats refresh handler tests.
type statsMockLogRepo struct {
	logs    []domain.PublishLog
	inserts []struct {
		publishID uuid.UUID
		views     int
		likes     int
		comments  int
	}
	insertErr error
	fetchErr  error
	trimmed   []uuid.UUID
}

func (m *statsMockLogRepo) Create(ctx context.Context, log *domain.PublishLog) error {
	return nil
}

func (m *statsMockLogRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.PublishLog, error) {
	return nil, errors.New("not found")
}

func (m *statsMockLogRepo) GetByIDAndUser(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*domain.PublishLog, error) {
	return nil, errors.New("not found")
}

func (m *statsMockLogRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	return nil, nil
}

func (m *statsMockLogRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error {
	return nil
}

func (m *statsMockLogRepo) UpdateStatusWithPostID(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string, platformPostID string) error {
	return nil
}

func (m *statsMockLogRepo) LatestPostStats(ctx context.Context, publishID uuid.UUID) (*domain.PostStatsSnapshot, error) {
	return nil, nil
}

func (m *statsMockLogRepo) InsertPostStats(ctx context.Context, publishID uuid.UUID, views, likes, comments int, fetchedAt time.Time) error {
	if m.insertErr != nil {
		return m.insertErr
	}
	m.inserts = append(m.inserts, struct {
		publishID uuid.UUID
		views     int
		likes     int
		comments  int
	}{publishID, views, likes, comments})
	return nil
}

func (m *statsMockLogRepo) ListRecentPublishedWithPostID(ctx context.Context, days int) ([]domain.PublishLog, error) {
	if m.fetchErr != nil {
		return nil, m.fetchErr
	}
	return m.logs, nil
}

func (m *statsMockLogRepo) TrimPostStats(ctx context.Context, publishID uuid.UUID, keep int) error {
	m.trimmed = append(m.trimmed, publishID)
	return nil
}

func TestStatsRefreshHandler_RefreshesCapableAdapters(t *testing.T) {
	publishID := uuid.New()
	userID := uuid.New()

	logRepo := &statsMockLogRepo{
		logs: []domain.PublishLog{
			{ID: publishID, UserID: userID, Platform: "mock", Status: "published", PlatformPostID: "post-123"},
		},
	}
	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return &domain.PlatformConnection{UserID: uid, Platform: p, EncryptedAuth: []byte("enc")}, nil
		},
	}
	registry := platform.NewRegistry()
	registry.Register("mock", &mockStatsAdapter{
		fetchStatsFn: func(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformPostID string) (*platform.PostStats, error) {
			if platformPostID != "post-123" {
				t.Errorf("FetchStats platformPostID = %q, want %q", platformPostID, "post-123")
			}
			return &platform.PostStats{Views: 100, Likes: 20, Comments: 3}, nil
		},
	})

	handler := NewStatsRefreshHandler(registry, logRepo, platformRepo, []byte("0123456789abcdef0123456789abcdef"))
	if err := handler.HandleRefreshPostStats(context.Background(), nil); err != nil {
		t.Fatalf("HandleRefreshPostStats returned error: %v", err)
	}

	if len(logRepo.inserts) != 1 {
		t.Fatalf("inserts = %d, want 1", len(logRepo.inserts))
	}
	got := logRepo.inserts[0]
	if got.publishID != publishID || got.views != 100 || got.likes != 20 || got.comments != 3 {
		t.Errorf("insert = %+v, want publish %s with 100/20/3", got, publishID)
	}
	if len(logRepo.trimmed) != 1 || logRepo.trimmed[0] != publishID {
		t.Errorf("trimmed = %v, want [%s]", logRepo.trimmed, publishID)
	}
}

func TestStatsRefreshHandler_SkipsAdaptersWithoutStats(t *testing.T) {
	logRepo := &statsMockLogRepo{
		logs: []domain.PublishLog{
			{ID: uuid.New(), UserID: uuid.New(), Platform: "mock", Status: "published", PlatformPostID: "post-123"},
		},
	}
	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return &domain.PlatformConnection{EncryptedAuth: []byte("enc")}, nil
		},
	}
	registry := platform.NewRegistry()
	registry.Register("mock", &mockPlatformAdapter{})

	handler := NewStatsRefreshHandler(registry, logRepo, platformRepo, nil)
	if err := handler.HandleRefreshPostStats(context.Background(), nil); err != nil {
		t.Fatalf("HandleRefreshPostStats returned error: %v", err)
	}
	if len(logRepo.inserts) != 0 {
		t.Errorf("inserts = %d, want 0 (adapter cannot fetch stats)", len(logRepo.inserts))
	}
}

func TestStatsRefreshHandler_SkipsDisconnectedPlatforms(t *testing.T) {
	logRepo := &statsMockLogRepo{
		logs: []domain.PublishLog{
			{ID: uuid.New(), UserID: uuid.New(), Platform: "mock", Status: "published", PlatformPostID: "post-123"},
		},
	}
	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return nil, errors.New("not found")
		},
	}
	registry := platform.NewRegistry()
	registry.Register("mock", &mockStatsAdapter{})

	handler := NewStatsRefreshHandler(registry, logRepo, platformRepo, nil)
	if err := handler.HandleRefreshPostStats(context.Background(), nil); err != nil {
		t.Fatalf("HandleRefreshPostStats returned error: %v", err)
	}
	if len(logRepo.inserts) != 0 {
		t.Errorf("inserts = %d, want 0 (no connection)", len(logRepo.inserts))
	}
}

func TestStatsRefreshHandler_FetchFailureDoesNotAbort(t *testing.T) {
	failID := uuid.New()
	okID := uuid.New()

	logRepo := &statsMockLogRepo{
		logs: []domain.PublishLog{
			{ID: failID, UserID: uuid.New(), Platform: "mock", Status: "published", PlatformPostID: "bad"},
			{ID: okID, UserID: uuid.New(), Platform: "mock", Status: "published", PlatformPostID: "good"},
		},
	}
	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return &domain.PlatformConnection{EncryptedAuth: []byte("enc")}, nil
		},
	}
	registry := platform.NewRegistry()
	registry.Register("mock", &mockStatsAdapter{
		fetchStatsFn: func(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformPostID string) (*platform.PostStats, error) {
			if platformPostID == "bad" {
				return nil, errors.New("scrape failed")
			}
			return &platform.PostStats{Views: 1}, nil
		},
	})

	handler := NewStatsRefreshHandler(registry, logRepo, platformRepo, nil)
	if err := handler.HandleRefreshPostStats(context.Background(), nil); err != nil {
		t.Fatalf("HandleRefreshPostStats returned error: %v", err)
	}
	if len(logRepo.inserts) != 1 || logRepo.inserts[0].publishID != okID {
		t.Errorf("inserts = %+v, want one insert for %s", logRepo.inserts, okID)
	}
}

func TestStatsRefreshHandler_ListErrorPropagates(t *testing.T) {
	logRepo := &statsMockLogRepo{fetchErr: errors.New("db down")}
	handler := NewStatsRefreshHandler(platform.NewRegistry(), logRepo, &mockPlatformConnRepo{}, nil)
	if err := handler.HandleRefreshPostStats(context.Background(), nil); err == nil {
		t.Fatal("expected error when listing fails")
	}
}

func TestStatsRefreshHandler_SkipsUnknownPlatformsAndInsertFailures(t *testing.T) {
	okID := uuid.New()
	logRepo := &statsMockLogRepo{
		insertErr: errors.New("insert failed"),
		logs: []domain.PublishLog{
			// Platform "unknown" is not registered: skipped silently.
			{ID: uuid.New(), UserID: uuid.New(), Platform: "unknown", Status: "published", PlatformPostID: "x"},
			// Fetch succeeds but insert fails: logged and skipped.
			{ID: okID, UserID: uuid.New(), Platform: "mock", Status: "published", PlatformPostID: "y"},
		},
	}
	platformRepo := &mockPlatformConnRepo{
		getByPlatformFn: func(ctx context.Context, uid uuid.UUID, p string) (*domain.PlatformConnection, error) {
			return &domain.PlatformConnection{EncryptedAuth: []byte("enc")}, nil
		},
	}
	registry := platform.NewRegistry()
	registry.Register("mock", &mockStatsAdapter{})

	handler := NewStatsRefreshHandler(registry, logRepo, platformRepo, nil)
	if err := handler.HandleRefreshPostStats(context.Background(), nil); err != nil {
		t.Fatalf("HandleRefreshPostStats returned error: %v", err)
	}
	if len(logRepo.inserts) != 0 {
		t.Errorf("inserts = %d, want 0 (insert failure)", len(logRepo.inserts))
	}
}
