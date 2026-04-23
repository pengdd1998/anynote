package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

// ProfileRepository manages user profile data.
type ProfileRepository struct {
	pool *pgxpool.Pool
}

// NewProfileRepository creates a new ProfileRepository.
func NewProfileRepository(pool *pgxpool.Pool) *ProfileRepository {
	return &ProfileRepository{pool: pool}
}

// GetPublicProfile returns the public profile for a given username.
// Only returns data when public_profile_enabled is true.
func (r *ProfileRepository) GetPublicProfile(ctx context.Context, username string) (*domain.PublicProfile, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT username, COALESCE(display_name, ''), COALESCE(bio, ''),
		        COALESCE(plan, 'free'), COALESCE(public_profile_enabled, false)
		 FROM users WHERE username = $1 AND COALESCE(public_profile_enabled, false) = true`,
		username,
	)

	var p domain.PublicProfile
	err := row.Scan(&p.Username, &p.DisplayName, &p.Bio, &p.Plan, &p.PublicEnabled)
	if err != nil {
		return nil, fmt.Errorf("get public profile: %w", err)
	}
	return &p, nil
}

// UpdateProfile updates the display name, bio, and public profile flag for the given user.
func (r *ProfileRepository) UpdateProfile(ctx context.Context, userID uuid.UUID, displayName string, bio string, publicEnabled bool) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE users SET display_name = $1, bio = $2, public_profile_enabled = $3, updated_at = NOW()
		 WHERE id = $4`,
		displayName, bio, publicEnabled, userID,
	)
	if err != nil {
		return fmt.Errorf("update profile: %w", err)
	}
	return nil
}

// GetProfileByUserID returns the profile data for the given user ID.
func (r *ProfileRepository) GetProfileByUserID(ctx context.Context, userID uuid.UUID) (*domain.PublicProfile, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT username, COALESCE(display_name, ''), COALESCE(bio, ''),
		        COALESCE(plan, 'free'), COALESCE(public_profile_enabled, false)
		 FROM users WHERE id = $1`,
		userID,
	)

	var p domain.PublicProfile
	err := row.Scan(&p.Username, &p.DisplayName, &p.Bio, &p.Plan, &p.PublicEnabled)
	if err != nil {
		return nil, fmt.Errorf("get profile by user id: %w", err)
	}
	return &p, nil
}
