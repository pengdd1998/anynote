package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ErrProfileNotFound is returned when a public profile does not exist or is not enabled.
var ErrProfileNotFound = errors.New("profile not found or not public")

// ProfileRepo defines the data access interface for profile operations.
type ProfileRepo interface {
	GetPublicProfile(ctx context.Context, username string) (*domain.PublicProfile, error)
	UpdateProfile(ctx context.Context, userID uuid.UUID, displayName string, bio string, publicEnabled bool) error
	GetProfileByUserID(ctx context.Context, userID uuid.UUID) (*domain.PublicProfile, error)
}

// ProfileService provides profile management business logic.
type ProfileService interface {
	GetPublicProfile(ctx context.Context, username string) (*domain.PublicProfile, error)
	UpdateProfile(ctx context.Context, userID uuid.UUID, displayName string, bio string, publicEnabled bool) error
	GetOwnProfile(ctx context.Context, userID uuid.UUID) (*domain.PublicProfile, error)
}

type profileService struct {
	profileRepo ProfileRepo
}

// NewProfileService creates a new profile service.
func NewProfileService(profileRepo ProfileRepo) ProfileService {
	return &profileService{profileRepo: profileRepo}
}

// GetPublicProfile returns the public profile for the given username.
func (s *profileService) GetPublicProfile(ctx context.Context, username string) (*domain.PublicProfile, error) {
	profile, err := s.profileRepo.GetPublicProfile(ctx, username)
	if err != nil {
		return nil, ErrProfileNotFound
	}
	return profile, nil
}

// UpdateProfile updates the authenticated user's profile.
func (s *profileService) UpdateProfile(ctx context.Context, userID uuid.UUID, displayName string, bio string, publicEnabled bool) error {
	return s.profileRepo.UpdateProfile(ctx, userID, displayName, bio, publicEnabled)
}

// GetOwnProfile returns the profile for the given user ID.
func (s *profileService) GetOwnProfile(ctx context.Context, userID uuid.UUID) (*domain.PublicProfile, error) {
	return s.profileRepo.GetProfileByUserID(ctx, userID)
}
