package service

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

type SyncService interface {
	Pull(ctx context.Context, userID uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error)
	Push(ctx context.Context, userID uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error)
	GetStatus(ctx context.Context, userID uuid.UUID) (*domain.SyncStatusResponse, error)
	GetStats(ctx context.Context, userID uuid.UUID) (*domain.SyncStatsResponse, error)
	ListTags(ctx context.Context, userID uuid.UUID) (*domain.ListTagsResponse, error)
	BatchDelete(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (*domain.BatchDeleteResponse, error)
	GetProgress(ctx context.Context, userID uuid.UUID) (*domain.SyncProgressResponse, error)
}

type SyncBlobRepository interface {
	PullSince(ctx context.Context, userID uuid.UUID, sinceVersion int) ([]domain.SyncBlob, error)
	PullSincePaginated(ctx context.Context, userID uuid.UUID, sinceVersion int, limit int) ([]domain.SyncBlob, error)
	HasMoreSince(ctx context.Context, userID uuid.UUID, sinceVersion int) (bool, error)
	Upsert(ctx context.Context, blob *domain.SyncBlob) (accepted bool, err error)
	BatchUpsert(ctx context.Context, blobs []*domain.SyncBlob) []domain.BatchUpsertResult
	GetLatestVersion(ctx context.Context, userID uuid.UUID) (int, error)
	CountItems(ctx context.Context, userID uuid.UUID) (int, error)
	GetLastUpdated(ctx context.Context, userID uuid.UUID) (time.Time, error)
	GetStatusSummary(ctx context.Context, userID uuid.UUID) (domain.SyncStatusSummary, error)
	GetItemsByType(ctx context.Context, userID uuid.UUID) (map[string]int, error)
	GetConflictCount(ctx context.Context, userID uuid.UUID) (int64, error)
	InsertOperationLog(ctx context.Context, log *domain.SyncOperationLog) error
	BatchInsertOperationLogs(ctx context.Context, logs []domain.SyncOperationLog) error
	ListTagsByType(ctx context.Context, userID uuid.UUID, itemType string) ([]domain.TagListItem, error)
	BatchDelete(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (int, error)
	GetOperationCounts(ctx context.Context, userID uuid.UUID) (pushCount, pullCount int64, err error)
}

type syncService struct {
	blobRepo   SyncBlobRepository
	pushSvc    PushService // optional; nil means no push notifications
}

func NewSyncService(blobRepo SyncBlobRepository, opts ...SyncServiceOption) SyncService {
	svc := &syncService{blobRepo: blobRepo}
	for _, opt := range opts {
		opt(svc)
	}
	return svc
}

// SyncServiceOption configures a syncService during construction.
type SyncServiceOption func(*syncService)

// WithPushService sets the push notification service for sync events.
func WithPushService(pushSvc PushService) SyncServiceOption {
	return func(s *syncService) { s.pushSvc = pushSvc }
}

func (s *syncService) Pull(ctx context.Context, userID uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
	// Use cursor as the effective sinceVersion when provided.
	effectiveSince := sinceVersion
	if cursor > 0 {
		effectiveSince = cursor
	}

	blobs, err := s.blobRepo.PullSincePaginated(ctx, userID, effectiveSince, limit)
	if err != nil {
		return nil, err
	}

	latestVersion, _ := s.blobRepo.GetLatestVersion(ctx, userID)

	// Determine next cursor and whether there are more pages.
	var nextCursor int
	var hasMore bool

	if len(blobs) > 0 {
		nextCursor = blobs[len(blobs)-1].Version

		// Check if there are rows beyond what we just fetched.
		more, err := s.blobRepo.HasMoreSince(ctx, userID, nextCursor)
		if err == nil {
			hasMore = more
		}
	}

	return &domain.SyncPullResponse{
		Blobs:         blobs,
		LatestVersion: latestVersion,
		HasMore:       hasMore,
		NextCursor:    nextCursor,
	}, nil
}

func (s *syncService) Push(ctx context.Context, userID uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
	var accepted []uuid.UUID
	var conflicts []domain.SyncConflict

	if len(req.Blobs) == 0 {
		return &domain.SyncPushResponse{Accepted: accepted, Conflicts: conflicts}, nil
	}

	// Build blob slice for batch upsert.
	blobs := make([]*domain.SyncBlob, len(req.Blobs))
	for i, item := range req.Blobs {
		blobs[i] = &domain.SyncBlob{
			UserID:        userID,
			ItemType:      item.ItemType,
			ItemID:        item.ItemID,
			Version:       item.Version,
			EncryptedData: item.EncryptedData,
			BlobSize:      item.BlobSize,
			UpdatedAt:     time.Now(),
		}
	}

	// Execute batch upsert in a single database round-trip.
	results := s.blobRepo.BatchUpsert(ctx, blobs)

	// Build operation logs for all items.
	var opLogs []domain.SyncOperationLog
	now := time.Now()

	for _, res := range results {
		if res.Error != nil {
			continue // Skip items that had DB errors
		}
		if res.Accepted {
			accepted = append(accepted, res.ItemID)
			opLogs = append(opLogs, domain.SyncOperationLog{
				ID:            uuid.New(),
				UserID:        userID,
				OperationType: "push",
				ItemType:      res.ItemType,
				ItemID:        res.ItemID,
				Version:       res.ClientVersion,
				CreatedAt:     now,
			})
		} else {
			conflicts = append(conflicts, domain.SyncConflict{
				ItemID:        res.ItemID,
				ItemType:      res.ItemType,
				ServerVersion: res.ServerVersion,
				ClientVersion: res.ClientVersion,
			})
			// version=0 is used as a sentinel to indicate a conflict was logged.
			opLogs = append(opLogs, domain.SyncOperationLog{
				ID:            uuid.New(),
				UserID:        userID,
				OperationType: "push",
				ItemType:      res.ItemType,
				ItemID:        res.ItemID,
				Version:       0,
				CreatedAt:     now,
			})
		}
	}

	// Log operations in a single batch round-trip.
	if len(opLogs) > 0 {
		if err := s.blobRepo.BatchInsertOperationLogs(ctx, opLogs); err != nil {
			slog.Error("failed to batch insert operation logs", "user_id", userID.String(), "error", err)
			// Non-fatal: operation logging failure should not block the push response.
		}
	}

	// Trigger push notification if there are sync conflicts.
	// The user's other devices should be alerted to re-sync.
	if len(conflicts) > 0 && s.pushSvc != nil {
		go func() {
			payload := PushPayload{
				Title:    "Sync Conflict Detected",
				Body:     fmt.Sprintf("%d item(s) had conflicts during sync", len(conflicts)),
				Priority: "high",
				Data: map[string]interface{}{
					"type":          "sync_conflict",
					"conflict_count": len(conflicts),
				},
			}
			if err := s.pushSvc.SendPush(context.Background(), userID.String(), payload); err != nil {
				slog.Error("failed to send sync conflict push", "user_id", userID.String(), "error", err)
			}
		}()
	}

	return &domain.SyncPushResponse{
		Accepted:  accepted,
		Conflicts: conflicts,
	}, nil
}

func (s *syncService) GetStatus(ctx context.Context, userID uuid.UUID) (*domain.SyncStatusResponse, error) {
	summary, _ := s.blobRepo.GetStatusSummary(ctx, userID)

	return &domain.SyncStatusResponse{
		LatestVersion: summary.LatestVersion,
		TotalItems:    summary.TotalItems,
		LastSyncedAt:  summary.LastUpdated,
	}, nil
}

func (s *syncService) GetStats(ctx context.Context, userID uuid.UUID) (*domain.SyncStatsResponse, error) {
	summary, err := s.blobRepo.GetStatusSummary(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get status summary: %w", err)
	}

	itemsByType, err := s.blobRepo.GetItemsByType(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get items by type: %w", err)
	}

	conflictCount, err := s.blobRepo.GetConflictCount(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get conflict count: %w", err)
	}

	return &domain.SyncStatsResponse{
		TotalItems:     summary.TotalItems,
		ItemsByType:    itemsByType,
		LastSyncedAt:   summary.LastUpdated,
		TotalConflicts: conflictCount,
	}, nil
}

func (s *syncService) ListTags(ctx context.Context, userID uuid.UUID) (*domain.ListTagsResponse, error) {
	tags, err := s.blobRepo.ListTagsByType(ctx, userID, "tag")
	if err != nil {
		return nil, fmt.Errorf("list tags: %w", err)
	}

	return &domain.ListTagsResponse{Tags: tags}, nil
}

func (s *syncService) BatchDelete(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (*domain.BatchDeleteResponse, error) {
	deleted, err := s.blobRepo.BatchDelete(ctx, userID, itemIDs)
	if err != nil {
		return nil, fmt.Errorf("batch delete: %w", err)
	}

	return &domain.BatchDeleteResponse{Deleted: deleted}, nil
}

func (s *syncService) GetProgress(ctx context.Context, userID uuid.UUID) (*domain.SyncProgressResponse, error) {
	summary, _ := s.blobRepo.GetStatusSummary(ctx, userID)

	conflictCount, err := s.blobRepo.GetConflictCount(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get conflict count: %w", err)
	}

	pushCount, pullCount, err := s.blobRepo.GetOperationCounts(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get operation counts: %w", err)
	}

	// Determine health status based on recent conflict ratio.
	healthStatus := "ok"
	totalOps := pushCount + pullCount
	if totalOps > 0 {
		conflictRatio := float64(conflictCount) / float64(totalOps)
		if conflictRatio > 0.1 {
			healthStatus = "errors"
		} else if conflictRatio > 0.01 {
			healthStatus = "warnings"
		}
	}

	return &domain.SyncProgressResponse{
		TotalItems:    summary.TotalItems,
		LatestVersion: summary.LatestVersion,
		LastSyncedAt:  summary.LastUpdated,
		ConflictCount: conflictCount,
		HealthStatus:  healthStatus,
		PushCount24h:  pushCount,
		PullCount24h:  pullCount,
	}, nil
}
