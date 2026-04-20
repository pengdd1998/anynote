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

	for _, res := range results {
		if res.Error != nil {
			continue // Skip items that had DB errors
		}
		if res.Accepted {
			accepted = append(accepted, res.ItemID)
		} else {
			conflicts = append(conflicts, domain.SyncConflict{
				ItemID:        res.ItemID,
				ServerVersion: res.ServerVersion,
			})
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
					"type":        "sync_conflict",
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
