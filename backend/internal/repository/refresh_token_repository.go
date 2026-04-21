package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// RefreshTokenRepository persists refresh token records for rotation and revocation.
type RefreshTokenRepository struct {
	pool *pgxpool.Pool
}

// NewRefreshTokenRepository creates a new RefreshTokenRepository.
func NewRefreshTokenRepository(pool *pgxpool.Pool) *RefreshTokenRepository {
	return &RefreshTokenRepository{pool: pool}
}

// Store persists a refresh token record with the given JWT ID (jti), user, and expiry.
func (r *RefreshTokenRepository) Store(ctx context.Context, userID uuid.UUID, tokenID string, expiresAt time.Time) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_id, expires_at)
		 VALUES ($1, $2, $3)`,
		userID, tokenID, expiresAt,
	)
	return err
}

// Revoke marks a refresh token as revoked by its JWT ID (jti).
// Returns whether the token was found and revoked.
func (r *RefreshTokenRepository) Revoke(ctx context.Context, tokenID string) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE refresh_tokens SET revoked = TRUE WHERE token_id = $1 AND revoked = FALSE`,
		tokenID,
	)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// IsRevoked checks whether a refresh token has been revoked.
func (r *RefreshTokenRepository) IsRevoked(ctx context.Context, tokenID string) (bool, error) {
	var revoked bool
	err := r.pool.QueryRow(ctx,
		`SELECT revoked FROM refresh_tokens WHERE token_id = $1`,
		tokenID,
	).Scan(&revoked)
	if err != nil {
		// Token not found in the table is treated as not revoked.
		// The JWT signature validation in the auth service handles invalid tokens.
		return false, nil
	}
	return revoked, nil
}

// RevokeAllForUser revokes every refresh token for a given user.
// Useful for "logout everywhere" or password change scenarios.
func (r *RefreshTokenRepository) RevokeAllForUser(ctx context.Context, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = $1 AND revoked = FALSE`,
		userID,
	)
	return err
}

// PurgeExpired removes expired token records older than the given threshold.
// Returns the number of purged records.
func (r *RefreshTokenRepository) PurgeExpired(ctx context.Context) (int64, error) {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM refresh_tokens WHERE expires_at < NOW()`,
	)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
