package service

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

type PlatformService interface {
	List(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error)
	Connect(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error)
	Disconnect(ctx context.Context, userID uuid.UUID, platform string) error
	Verify(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error)
}

type PlatformConnectionRepository interface {
	ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error)
	GetByPlatform(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error)
	Create(ctx context.Context, conn *domain.PlatformConnection) error
	Delete(ctx context.Context, id uuid.UUID) error
	Update(ctx context.Context, conn *domain.PlatformConnection) error
}

type platformService struct {
	platformRepo PlatformConnectionRepository
}

func NewPlatformService(platformRepo PlatformConnectionRepository) PlatformService {
	return &platformService{platformRepo: platformRepo}
}

func (s *platformService) List(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error) {
	return s.platformRepo.ListByUser(ctx, userID)
}

func (s *platformService) Connect(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error) {
	// Check if already connected
	existing, _ := s.platformRepo.GetByPlatform(ctx, userID, platform)
	if existing != nil {
		return nil, fmt.Errorf("platform already connected")
	}

	conn := &domain.PlatformConnection{
		ID:       uuid.New(),
		UserID:   userID,
		Platform: platform,
		Status:   "active",
	}

	if err := s.platformRepo.Create(ctx, conn); err != nil {
		return nil, err
	}

	// In production: start platform-specific auth flow (QR code for XHS, OAuth for others)
	return conn, nil
}

func (s *platformService) Disconnect(ctx context.Context, userID uuid.UUID, platform string) error {
	conn, err := s.platformRepo.GetByPlatform(ctx, userID, platform)
	if err != nil {
		return fmt.Errorf("platform not connected")
	}

	return s.platformRepo.Delete(ctx, conn.ID)
}

func (s *platformService) Verify(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error) {
	conn, err := s.platformRepo.GetByPlatform(ctx, userID, platform)
	if err != nil {
		return nil, fmt.Errorf("platform not connected")
	}

	// In production: verify cookies/tokens are still valid via platform adapter
	// For now, just return the connection
	return conn, nil
}
