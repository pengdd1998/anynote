package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

type PlatformConnectionRepository struct {
	pool *pgxpool.Pool
}

func NewPlatformConnectionRepository(pool *pgxpool.Pool) *PlatformConnectionRepository {
	return &PlatformConnectionRepository{pool: pool}
}

func (r *PlatformConnectionRepository) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, platform, platform_uid, display_name, status, last_verified, created_at, updated_at
		 FROM platform_connections WHERE user_id = $1 ORDER BY created_at DESC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var conns []domain.PlatformConnection
	for rows.Next() {
		var c domain.PlatformConnection
		if err := rows.Scan(&c.ID, &c.UserID, &c.Platform, &c.PlatformUID, &c.DisplayName, &c.Status, &c.LastVerified, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		conns = append(conns, c)
	}
	return conns, rows.Err()
}

func (r *PlatformConnectionRepository) GetByPlatform(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, user_id, platform, platform_uid, display_name, status, last_verified, created_at, updated_at
		 FROM platform_connections WHERE user_id = $1 AND platform = $2`, userID, platform,
	)

	var c domain.PlatformConnection
	err := row.Scan(&c.ID, &c.UserID, &c.Platform, &c.PlatformUID, &c.DisplayName, &c.Status, &c.LastVerified, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *PlatformConnectionRepository) Create(ctx context.Context, conn *domain.PlatformConnection) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO platform_connections (id, user_id, platform, platform_uid, display_name, encrypted_auth, status)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		conn.ID, conn.UserID, conn.Platform, conn.PlatformUID, conn.DisplayName, []byte{}, conn.Status,
	)
	return err
}

func (r *PlatformConnectionRepository) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM platform_connections WHERE id = $1`, id)
	return err
}

func (r *PlatformConnectionRepository) Update(ctx context.Context, conn *domain.PlatformConnection) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE platform_connections SET
		     platform_uid = $3, display_name = $4, status = $5, last_verified = NOW(), updated_at = NOW()
		 WHERE id = $1 AND user_id = $2`,
		conn.ID, conn.UserID, conn.PlatformUID, conn.DisplayName, conn.Status,
	)
	return err
}
