package service

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Zero-cost mock: SyncBlobRepository (all methods return immediately)
// ---------------------------------------------------------------------------

type zeroCostSyncBlobRepo struct {
	blobs100 []domain.SyncBlob
}

func newZeroCostSyncBlobRepo() *zeroCostSyncBlobRepo {
	blobs := make([]domain.SyncBlob, 100)
	for i := range blobs {
		blobs[i] = domain.SyncBlob{
			ID:            uuid.New(),
			UserID:        uuid.Nil,
			ItemType:      "note",
			ItemID:        uuid.New(),
			Version:       i + 1,
			EncryptedData: make([]byte, 1024),
			BlobSize:      1024,
			CreatedAt:     time.Now(),
			UpdatedAt:     time.Now(),
		}
	}
	return &zeroCostSyncBlobRepo{blobs100: blobs}
}

func (r *zeroCostSyncBlobRepo) PullSince(_ context.Context, _ uuid.UUID, _ int) ([]domain.SyncBlob, error) {
	return nil, nil
}

func (r *zeroCostSyncBlobRepo) PullSincePaginated(_ context.Context, _ uuid.UUID, _ int, limit int) ([]domain.SyncBlob, error) {
	if limit > len(r.blobs100) {
		return r.blobs100, nil
	}
	return r.blobs100[:limit], nil
}

func (r *zeroCostSyncBlobRepo) HasMoreSince(_ context.Context, _ uuid.UUID, _ int) (bool, error) {
	return false, nil
}

func (r *zeroCostSyncBlobRepo) Upsert(_ context.Context, _ *domain.SyncBlob) (bool, error) {
	return true, nil
}

func (r *zeroCostSyncBlobRepo) BatchUpsert(_ context.Context, blobs []*domain.SyncBlob) []domain.BatchUpsertResult {
	results := make([]domain.BatchUpsertResult, len(blobs))
	for i, b := range blobs {
		results[i] = domain.BatchUpsertResult{
			ItemID:        b.ItemID,
			ItemType:      b.ItemType,
			ClientVersion: b.Version,
			Accepted:      true,
			ServerVersion: b.Version,
		}
	}
	return results
}

func (r *zeroCostSyncBlobRepo) GetLatestVersion(_ context.Context, _ uuid.UUID) (int, error) {
	return 100, nil
}

func (r *zeroCostSyncBlobRepo) CountItems(_ context.Context, _ uuid.UUID) (int, error) {
	return 100, nil
}

func (r *zeroCostSyncBlobRepo) GetLastUpdated(_ context.Context, _ uuid.UUID) (time.Time, error) {
	return time.Now(), nil
}

func (r *zeroCostSyncBlobRepo) GetStatusSummary(_ context.Context, _ uuid.UUID) (domain.SyncStatusSummary, error) {
	return domain.SyncStatusSummary{LatestVersion: 100, TotalItems: 100, LastUpdated: time.Now()}, nil
}

func (r *zeroCostSyncBlobRepo) GetItemsByType(_ context.Context, _ uuid.UUID) (map[string]int, error) {
	return map[string]int{"note": 80, "tag": 20}, nil
}

func (r *zeroCostSyncBlobRepo) GetConflictCount(_ context.Context, _ uuid.UUID) (int64, error) {
	return 0, nil
}

func (r *zeroCostSyncBlobRepo) InsertOperationLog(_ context.Context, _ *domain.SyncOperationLog) error {
	return nil
}

func (r *zeroCostSyncBlobRepo) BatchInsertOperationLogs(_ context.Context, _ []domain.SyncOperationLog) error {
	return nil
}

func (r *zeroCostSyncBlobRepo) ListTagsByType(_ context.Context, _ uuid.UUID, _ string) ([]domain.TagListItem, error) {
	return nil, nil
}

func (r *zeroCostSyncBlobRepo) BatchDelete(_ context.Context, _ uuid.UUID, _ []uuid.UUID) (int, error) {
	return 0, nil
}

func (r *zeroCostSyncBlobRepo) GetOperationCounts(_ context.Context, _ uuid.UUID) (int64, int64, error) {
	return 10, 20, nil
}

// ---------------------------------------------------------------------------
// Zero-cost mock: QuotaRepository
// ---------------------------------------------------------------------------

type zeroCostQuotaRepo struct{}

func (r *zeroCostQuotaRepo) GetByUserID(_ context.Context, _ uuid.UUID) (*domain.UserQuota, error) {
	return &domain.UserQuota{
		UserID:       uuid.Nil,
		Plan:         "free",
		DailyAILimit: 50,
		DailyAIUsed:  10,
		QuotaResetAt: time.Now().Add(24 * time.Hour),
		UpdatedAt:    time.Now(),
	}, nil
}

func (r *zeroCostQuotaRepo) Create(_ context.Context, _ *domain.UserQuota) error {
	return nil
}

func (r *zeroCostQuotaRepo) IncrementUsage(_ context.Context, _ uuid.UUID) error {
	return nil
}

func (r *zeroCostQuotaRepo) ResetIfNeeded(_ context.Context, _ uuid.UUID) error {
	return nil
}

// ---------------------------------------------------------------------------
// Zero-cost mock: SharedNoteRepository
// ---------------------------------------------------------------------------

type zeroCostShareRepo struct{}

func (r *zeroCostShareRepo) Create(_ context.Context, _ *domain.SharedNote) error {
	return nil
}

func (r *zeroCostShareRepo) GetByID(_ context.Context, _ string) (*domain.SharedNote, error) {
	return nil, nil
}

func (r *zeroCostShareRepo) IncrementViewCount(_ context.Context, _ string) error {
	return nil
}

func (r *zeroCostShareRepo) DeleteExpired(_ context.Context) (int64, error) {
	return 0, nil
}

func (r *zeroCostShareRepo) ListByUser(_ context.Context, _ uuid.UUID) ([]domain.SharedNote, error) {
	return nil, nil
}

func (r *zeroCostShareRepo) ListPublic(_ context.Context, _, _ int) ([]domain.DiscoverFeedItem, error) {
	return nil, nil
}

func (r *zeroCostShareRepo) React(_ context.Context, _ string, _ uuid.UUID, _ string) (*domain.ReactResponse, error) {
	return nil, nil
}

func (r *zeroCostShareRepo) GetUserReaction(_ context.Context, _ string, _ uuid.UUID) (map[string]bool, error) {
	return nil, nil
}

// ---------------------------------------------------------------------------
// Benchmark: RateLimiter.Allow — 1000 concurrent keys
// ---------------------------------------------------------------------------

func BenchmarkRateLimiter_Allow(b *testing.B) {
	rl := NewRateLimiter(100, time.Minute)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		key := fmt.Sprintf("key-%d", i%1000)
		rl.Allow(key)
	}
}

// ---------------------------------------------------------------------------
// Benchmark: RateLimiter eviction — 10,000 expired windows
// ---------------------------------------------------------------------------

func BenchmarkRateLimiter_Eviction(b *testing.B) {
	// Pre-populate with 10,000 expired windows.
	rl := newRateLimiterWithEvict(100, time.Millisecond, 0)
	for i := 0; i < 10000; i++ {
		key := fmt.Sprintf("expired-key-%d", i)
		rl.windows[key] = &slidingWindow{
			timestamps: []time.Time{time.Now().Add(-time.Hour)},
		}
	}

	// Add a few valid windows so the map is mixed.
	for i := 0; i < 50; i++ {
		key := fmt.Sprintf("valid-key-%d", i)
		rl.windows[key] = &slidingWindow{
			timestamps: []time.Time{time.Now()},
		}
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		rl.evictLocked(time.Now())
	}
}

// ---------------------------------------------------------------------------
// Benchmark: SyncService.Push — 100 blobs
// ---------------------------------------------------------------------------

func BenchmarkSyncService_Push_100Blobs(b *testing.B) {
	items := make([]domain.SyncPushItem, 100)
	for i := range items {
		data := make([]byte, 1024)
		for j := range data {
			data[j] = byte(i + j)
		}
		items[i] = domain.SyncPushItem{
			ItemID:        uuid.New(),
			ItemType:      "note",
			Version:       i + 1,
			EncryptedData: data,
			BlobSize:      len(data),
		}
	}

	mockRepo := newZeroCostSyncBlobRepo()
	svc := NewSyncService(mockRepo)
	req := domain.SyncPushRequest{Blobs: items}

	ctx := context.Background()
	userID := uuid.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := svc.Push(ctx, userID, req)
		if err != nil {
			b.Fatal(err)
		}
	}
}

// ---------------------------------------------------------------------------
// Benchmark: SyncService.Push — 1000 blobs
// ---------------------------------------------------------------------------

func BenchmarkSyncService_Push_1000Blobs(b *testing.B) {
	items := make([]domain.SyncPushItem, 1000)
	for i := range items {
		data := make([]byte, 1024)
		for j := range data {
			data[j] = byte(i + j)
		}
		items[i] = domain.SyncPushItem{
			ItemID:        uuid.New(),
			ItemType:      "note",
			Version:       i + 1,
			EncryptedData: data,
			BlobSize:      len(data),
		}
	}

	mockRepo := newZeroCostSyncBlobRepo()
	svc := NewSyncService(mockRepo)
	req := domain.SyncPushRequest{Blobs: items}

	ctx := context.Background()
	userID := uuid.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := svc.Push(ctx, userID, req)
		if err != nil {
			b.Fatal(err)
		}
	}
}

// ---------------------------------------------------------------------------
// Benchmark: SyncService.Pull — 100 blobs returned
// ---------------------------------------------------------------------------

func BenchmarkSyncService_Pull(b *testing.B) {
	mockRepo := newZeroCostSyncBlobRepo()
	svc := NewSyncService(mockRepo)

	ctx := context.Background()
	userID := uuid.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := svc.Pull(ctx, userID, 0, 100, 0)
		if err != nil {
			b.Fatal(err)
		}
	}
}

// ---------------------------------------------------------------------------
// Benchmark: QuotaService.GetQuota
// ---------------------------------------------------------------------------

func BenchmarkQuotaService_GetQuota(b *testing.B) {
	mockRepo := &zeroCostQuotaRepo{}
	svc := NewQuotaService(mockRepo)

	ctx := context.Background()
	userID := uuid.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := svc.GetQuota(ctx, userID)
		if err != nil {
			b.Fatal(err)
		}
	}
}

// ---------------------------------------------------------------------------
// Benchmark: ShareService.CreateShare — random ID generation
// ---------------------------------------------------------------------------

func BenchmarkShareService_CreateShare(b *testing.B) {
	mockRepo := &zeroCostShareRepo{}
	svc := NewShareService(mockRepo)

	ctx := context.Background()
	userID := uuid.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := domain.CreateShareRequest{
			EncryptedContent: "benchmark-encrypted-content-payload",
			EncryptedTitle:   "benchmark-encrypted-title",
			ShareKeyHash:     "benchmark-key-hash",
			HasPassword:      false,
		}
		_, err := svc.CreateShare(ctx, userID, req)
		if err != nil {
			b.Fatal(err)
		}
	}
}
