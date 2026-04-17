package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

type QuotaRepository struct {
	pool *pgxpool.Pool
}

func NewQuotaRepository(pool *pgxpool.Pool) *QuotaRepository {
	return &QuotaRepository{pool: pool}
}

func (r *QuotaRepository) GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.UserQuota, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT user_id, plan, daily_ai_limit, daily_ai_used, quota_reset_at, updated_at
		 FROM user_quotas WHERE user_id = $1`, userID,
	)

	var q domain.UserQuota
	err := row.Scan(&q.UserID, &q.Plan, &q.DailyAILimit, &q.DailyAIUsed, &q.QuotaResetAt, &q.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &q, nil
}

func (r *QuotaRepository) Create(ctx context.Context, quota *domain.UserQuota) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_quotas (user_id, plan, daily_ai_limit, daily_ai_used, quota_reset_at)
		 VALUES ($1, $2, $3, $4, $5)
		 ON CONFLICT (user_id) DO UPDATE SET
		     plan = EXCLUDED.plan,
		     daily_ai_limit = EXCLUDED.daily_ai_limit,
		     daily_ai_used = EXCLUDED.daily_ai_used,
		     quota_reset_at = EXCLUDED.quota_reset_at,
		     updated_at = NOW()`,
		quota.UserID, quota.Plan, quota.DailyAILimit, quota.DailyAIUsed, quota.QuotaResetAt,
	)
	return err
}

func (r *QuotaRepository) IncrementUsage(ctx context.Context, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE user_quotas
		 SET daily_ai_used = daily_ai_used + 1, updated_at = NOW()
		 WHERE user_id = $1`, userID,
	)
	return err
}

func (r *QuotaRepository) ResetIfNeeded(ctx context.Context, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE user_quotas
		 SET daily_ai_used = 0, quota_reset_at = NOW(), updated_at = NOW()
		 WHERE user_id = $1 AND quota_reset_at < NOW() - INTERVAL '1 day'`, userID,
	)
	return err
}

// EnsureQuota creates a quota record if one doesn't exist for the user.
func (r *QuotaRepository) EnsureQuota(ctx context.Context, userID uuid.UUID, plan string) error {
	limit := 50
	if plan == "pro" || plan == "lifetime" {
		limit = 500
	}

	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_quotas (user_id, plan, daily_ai_limit, daily_ai_used, quota_reset_at)
		 VALUES ($1, $2, $3, 0, NOW())
		 ON CONFLICT (user_id) DO NOTHING`,
		userID, plan, limit,
	)
	return err
}
