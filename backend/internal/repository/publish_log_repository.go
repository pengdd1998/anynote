package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

type PublishLogRepository struct {
	pool *pgxpool.Pool
}

func NewPublishLogRepository(pool *pgxpool.Pool) *PublishLogRepository {
	return &PublishLogRepository{pool: pool}
}

func (r *PublishLogRepository) Create(ctx context.Context, log *domain.PublishLog) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO publish_logs (id, user_id, platform, platform_conn_id, content_item_id, title, content, status)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		log.ID, log.UserID, log.Platform, log.PlatformConnID, log.ContentItemID, log.Title, log.Content, log.Status,
	)
	return err
}

func (r *PublishLogRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.PublishLog, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, user_id, platform, platform_conn_id, content_item_id, title, content, status, platform_url, error_message, published_at, created_at
		 FROM publish_logs WHERE id = $1`, id,
	)

	var l domain.PublishLog
	err := row.Scan(&l.ID, &l.UserID, &l.Platform, &l.PlatformConnID, &l.ContentItemID, &l.Title, &l.Content, &l.Status, &l.PlatformURL, &l.ErrorMessage, &l.PublishedAt, &l.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &l, nil
}

func (r *PublishLogRepository) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, platform, platform_conn_id, content_item_id, title, content, status, platform_url, error_message, published_at, created_at
		 FROM publish_logs WHERE user_id = $1 ORDER BY created_at DESC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []domain.PublishLog
	for rows.Next() {
		var l domain.PublishLog
		if err := rows.Scan(&l.ID, &l.UserID, &l.Platform, &l.PlatformConnID, &l.ContentItemID, &l.Title, &l.Content, &l.Status, &l.PlatformURL, &l.ErrorMessage, &l.PublishedAt, &l.CreatedAt); err != nil {
			return nil, err
		}
		logs = append(logs, l)
	}
	return logs, rows.Err()
}

func (r *PublishLogRepository) UpdateStatus(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE publish_logs SET
		     status = $3,
		     error_message = $4,
		     platform_url = $5,
		     published_at = CASE WHEN $3 = 'published' THEN NOW() ELSE published_at END
		 WHERE id = $1`,
		id, uuid.Nil, status, errMsg, platformURL,
	)
	return err
}

func (r *PublishLogRepository) GetByIDAndUser(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*domain.PublishLog, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, user_id, platform, platform_conn_id, content_item_id, title, content, status, platform_url, error_message, published_at, created_at
		 FROM publish_logs WHERE id = $1 AND user_id = $2`, id, userID,
	)

	var l domain.PublishLog
	err := row.Scan(&l.ID, &l.UserID, &l.Platform, &l.PlatformConnID, &l.ContentItemID, &l.Title, &l.Content, &l.Status, &l.PlatformURL, &l.ErrorMessage, &l.PublishedAt, &l.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &l, nil
}
