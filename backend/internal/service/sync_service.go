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
	Pull(ctx context.Context, userID uuid.UUID, sinceVersion int) (*domain.SyncPullResponse, error)
	Push(ctx context.Context, userID uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error)
	GetStatus(ctx context.Context, userID uuid.UUID) (*domain.SyncStatusResponse, error)
}

type SyncBlobRepository interface {
	PullSince(ctx context.Context, userID uuid.UUID, sinceVersion int) ([]domain.SyncBlob, error)
	Upsert(ctx context.Context, blob *domain.SyncBlob) (accepted bool, err error)
	GetLatestVersion(ctx context.Context, userID uuid.UUID) (int, error)
	CountItems(ctx context.Context, userID uuid.UUID) (int, error)
	GetLastUpdated(ctx context.Context, userID uuid.UUID) (time.Time, error)
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

func (s *syncService) Pull(ctx context.Context, userID uuid.UUID, sinceVersion int) (*domain.SyncPullResponse, error) {
	blobs, err := s.blobRepo.PullSince(ctx, userID, sinceVersion)
	if err != nil {
		return nil, err
	}

	latestVersion, _ := s.blobRepo.GetLatestVersion(ctx, userID)

	return &domain.SyncPullResponse{
		Blobs:         blobs,
		LatestVersion: latestVersion,
	}, nil
}

func (s *syncService) Push(ctx context.Context, userID uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
	var accepted []uuid.UUID
	var conflicts []domain.SyncConflict

	for _, item := range req.Blobs {
		blob := &domain.SyncBlob{
			UserID:        userID,
			ItemType:      item.ItemType,
			ItemID:        item.ItemID,
			Version:       item.Version,
			EncryptedData: item.EncryptedData,
			BlobSize:      item.BlobSize,
			UpdatedAt:     time.Now(),
		}

		ok, err := s.blobRepo.Upsert(ctx, blob)
		if err != nil {
			continue // Skip problematic items
		}

		if ok {
			accepted = append(accepted, item.ItemID)
		} else {
			conflicts = append(conflicts, domain.SyncConflict{
				ItemID:        item.ItemID,
				ServerVersion: blob.Version,
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
	latestVersion, _ := s.blobRepo.GetLatestVersion(ctx, userID)
	totalItems, _ := s.blobRepo.CountItems(ctx, userID)
	lastSynced, _ := s.blobRepo.GetLastUpdated(ctx, userID)

	return &domain.SyncStatusResponse{
		LatestVersion: latestVersion,
		TotalItems:    totalItems,
		LastSyncedAt:  lastSynced,
	}, nil
}
