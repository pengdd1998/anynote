package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
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
		`SELECT id, user_id, platform, platform_conn_id, content_item_id, title, content, status, platform_url, COALESCE(platform_post_id, ''), error_message, published_at, created_at
		 FROM publish_logs WHERE id = $1`, id,
	)

	var l domain.PublishLog
	err := row.Scan(&l.ID, &l.UserID, &l.Platform, &l.PlatformConnID, &l.ContentItemID, &l.Title, &l.Content, &l.Status, &l.PlatformURL, &l.PlatformPostID, &l.ErrorMessage, &l.PublishedAt, &l.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &l, nil
}

func (r *PublishLogRepository) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, platform, platform_conn_id, content_item_id, title, content, status, platform_url, COALESCE(platform_post_id, ''), error_message, published_at, created_at
		 FROM publish_logs WHERE user_id = $1 ORDER BY created_at DESC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []domain.PublishLog
	for rows.Next() {
		var l domain.PublishLog
		if err := rows.Scan(&l.ID, &l.UserID, &l.Platform, &l.PlatformConnID, &l.ContentItemID, &l.Title, &l.Content, &l.Status, &l.PlatformURL, &l.PlatformPostID, &l.ErrorMessage, &l.PublishedAt, &l.CreatedAt); err != nil {
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

// UpdateStatusWithPostID behaves like UpdateStatus and additionally
// persists the platform's own post id (used by the stats refresher).
func (r *PublishLogRepository) UpdateStatusWithPostID(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string, platformPostID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE publish_logs SET
		     status = $3,
		     error_message = $4,
		     platform_url = $5,
		     platform_post_id = $6,
		     published_at = CASE WHEN $3 = 'published' THEN NOW() ELSE published_at END
		 WHERE id = $1`,
		id, uuid.Nil, status, errMsg, platformURL, platformPostID,
	)
	return err
}

func (r *PublishLogRepository) GetByIDAndUser(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*domain.PublishLog, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, user_id, platform, platform_conn_id, content_item_id, title, content, status, platform_url, COALESCE(platform_post_id, ''), error_message, published_at, created_at
		 FROM publish_logs WHERE id = $1 AND user_id = $2`, id, userID,
	)

	var l domain.PublishLog
	err := row.Scan(&l.ID, &l.UserID, &l.Platform, &l.PlatformConnID, &l.ContentItemID, &l.Title, &l.Content, &l.Status, &l.PlatformURL, &l.PlatformPostID, &l.ErrorMessage, &l.PublishedAt, &l.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &l, nil
}

// InsertPostStats stores one engagement snapshot for a published post.
func (r *PublishLogRepository) InsertPostStats(ctx context.Context, publishID uuid.UUID, views, likes, comments int, fetchedAt time.Time) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO post_stats (publish_id, views, likes, comments, fetched_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		publishID, views, likes, comments, fetchedAt,
	)
	return err
}

// LatestPostStats returns the most recent snapshot for a publish, or nil.
func (r *PublishLogRepository) LatestPostStats(ctx context.Context, publishID uuid.UUID) (*domain.PostStatsSnapshot, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT views, likes, comments, fetched_at FROM post_stats
		 WHERE publish_id = $1 ORDER BY fetched_at DESC LIMIT 1`,
		publishID,
	)
	var s domain.PostStatsSnapshot
	var views, likes, comments sql.NullInt64
	err := row.Scan(&views, &likes, &comments, &s.FetchedAt)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	s.Views = int(views.Int64)
	s.Likes = int(likes.Int64)
	s.Comments = int(comments.Int64)
	return &s, nil
}

// TrimPostStats keeps only the newest [keep] snapshots per publish.
func (r *PublishLogRepository) TrimPostStats(ctx context.Context, publishID uuid.UUID, keep int) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM post_stats WHERE publish_id = $1 AND id NOT IN (
		     SELECT id FROM post_stats WHERE publish_id = $1
		     ORDER BY fetched_at DESC LIMIT $2)`,
		publishID, keep,
	)
	return err
}

// ListRecentPublishedWithPostID returns published posts (newest first) that
// carry a platform post id, within [days] days — the stats refresher's input.
func (r *PublishLogRepository) ListRecentPublishedWithPostID(ctx context.Context, days int) ([]domain.PublishLog, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, platform, platform_conn_id, content_item_id, title, content, status, platform_url, COALESCE(platform_post_id, ''), error_message, published_at, created_at
		 FROM publish_logs
		 WHERE status = 'published' AND platform_post_id IS NOT NULL AND platform_post_id <> ''
		   AND created_at > NOW() - make_interval(days => $1)`,
		days,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []domain.PublishLog
	for rows.Next() {
		var l domain.PublishLog
		if err := rows.Scan(&l.ID, &l.UserID, &l.Platform, &l.PlatformConnID, &l.ContentItemID, &l.Title, &l.Content, &l.Status, &l.PlatformURL, &l.PlatformPostID, &l.ErrorMessage, &l.PublishedAt, &l.CreatedAt); err != nil {
			return nil, err
		}
		logs = append(logs, l)
	}
	return logs, rows.Err()
}

// SetPlatformPostID stores the platform's post id after a successful publish.
func (r *PublishLogRepository) SetPlatformPostID(ctx context.Context, id uuid.UUID, platformPostID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE publish_logs SET platform_post_id = $2 WHERE id = $1`,
		id, platformPostID,
	)
	return err
}
