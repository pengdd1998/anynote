package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/service"
)

// DeviceTokenRepository persists device push-notification tokens.
type DeviceTokenRepository struct {
	pool *pgxpool.Pool
}

// NewDeviceTokenRepository creates a new DeviceTokenRepository.
func NewDeviceTokenRepository(pool *pgxpool.Pool) *DeviceTokenRepository {
	return &DeviceTokenRepository{pool: pool}
}

func (r *DeviceTokenRepository) Create(ctx context.Context, id uuid.UUID, userID string, token string, platform string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO device_tokens (id, user_id, token, platform)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (token) DO UPDATE SET user_id = $2, platform = $4, updated_at = NOW()`,
		id.String(), userID, token, platform,
	)
	return err
}

func (r *DeviceTokenRepository) DeleteByToken(ctx context.Context, token string) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM device_tokens WHERE token = $1`, token)
	return err
}

// DeleteByUser removes all device tokens for a given user.
// The device_tokens table uses a TEXT user_id without a foreign key, so it is
// not covered by ON DELETE CASCADE and must be cleaned up explicitly.
func (r *DeviceTokenRepository) DeleteByUser(ctx context.Context, userID string) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM device_tokens WHERE user_id = $1`, userID)
	return err
}

func (r *DeviceTokenRepository) ListByUser(ctx context.Context, userID string) ([]service.DeviceTokenEntry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, token, platform, created_at
		 FROM device_tokens WHERE user_id = $1 ORDER BY created_at DESC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []service.DeviceTokenEntry
	for rows.Next() {
		var e service.DeviceTokenEntry
		var idStr string
		if err := rows.Scan(&idStr, &e.UserID, &e.Token, &e.Platform, &e.CreatedAt); err != nil {
			return nil, err
		}
		e.ID, _ = uuid.Parse(idStr)
		entries = append(entries, e)
	}
	return entries, rows.Err()
}
