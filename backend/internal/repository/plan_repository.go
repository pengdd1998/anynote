package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PlanRepository manages user plan data in the database.
type PlanRepository struct {
	pool *pgxpool.Pool
}

// NewPlanRepository creates a new PlanRepository.
func NewPlanRepository(pool *pgxpool.Pool) *PlanRepository {
	return &PlanRepository{pool: pool}
}

const planFree = "free"

// GetPlan returns the current plan string for the given user.
// Returns "free" when the user has no explicit plan set.
func (r *PlanRepository) GetPlan(ctx context.Context, userID uuid.UUID) (string, error) {
	var plan string
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(plan, 'free') FROM users WHERE id = $1`, userID,
	).Scan(&plan)
	if err != nil {
		return planFree, fmt.Errorf("get plan: %w", err)
	}
	return plan, nil
}

// SetPlan updates the plan for the given user.
func (r *PlanRepository) SetPlan(ctx context.Context, userID uuid.UUID, plan string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE users SET plan = $1, updated_at = NOW() WHERE id = $2`,
		plan, userID,
	)
	if err != nil {
		return fmt.Errorf("set plan: %w", err)
	}
	return nil
}

// GetStorageUsage returns the total bytes used by all sync blobs for the user.
func (r *PlanRepository) GetStorageUsage(ctx context.Context, userID uuid.UUID) (int64, error) {
	var total int64
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(blob_size), 0) FROM sync_blobs WHERE user_id = $1`,
		userID,
	).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("get storage usage: %w", err)
	}
	return total, nil
}

// GetNoteCount returns the number of note-type sync blobs for the user.
func (r *PlanRepository) GetNoteCount(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM sync_blobs WHERE user_id = $1 AND item_type = 'note'`,
		userID,
	).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("get note count: %w", err)
	}
	return count, nil
}
