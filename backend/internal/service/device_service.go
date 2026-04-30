package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// DeviceRepository defines the persistence operations for device identity records.
type DeviceRepository interface {
	RegisterDevice(ctx context.Context, userID, deviceID, deviceName, platform string) (*domain.Device, error)
	ListDevices(ctx context.Context, userID string) ([]*domain.Device, error)
	DeleteDevice(ctx context.Context, userID, deviceID string) error
	UpdateLastSeen(ctx context.Context, userID, deviceID string) error
}

// DeviceService handles device identity management.
type DeviceService interface {
	RegisterDevice(ctx context.Context, userID uuid.UUID, deviceID, deviceName, platform string) (*domain.Device, error)
	ListDevices(ctx context.Context, userID uuid.UUID) ([]*domain.Device, error)
	DeleteDevice(ctx context.Context, userID uuid.UUID, deviceID string) error
}

type deviceService struct {
	repo DeviceRepository
}

// NewDeviceService creates a new DeviceService.
func NewDeviceService(repo DeviceRepository) DeviceService {
	return &deviceService{repo: repo}
}

func (s *deviceService) RegisterDevice(ctx context.Context, userID uuid.UUID, deviceID, deviceName, platform string) (*domain.Device, error) {
	return s.repo.RegisterDevice(ctx, userID.String(), deviceID, deviceName, platform)
}

func (s *deviceService) ListDevices(ctx context.Context, userID uuid.UUID) ([]*domain.Device, error) {
	return s.repo.ListDevices(ctx, userID.String())
}

func (s *deviceService) DeleteDevice(ctx context.Context, userID uuid.UUID, deviceID string) error {
	return s.repo.DeleteDevice(ctx, userID.String(), deviceID)
}
