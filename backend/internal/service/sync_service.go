package service

import (
	"context"
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
	blobRepo SyncBlobRepository
}

func NewSyncService(blobRepo SyncBlobRepository) SyncService {
	return &syncService{blobRepo: blobRepo}
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
