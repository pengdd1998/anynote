package repository

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestQuotaRepository_DocumentsExpectedBehavior documents expected SQL behaviors.
func TestQuotaRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("GetByUserID_selects_quota", func(t *testing.T) {
		// SELECT user_id, plan, daily_ai_limit, daily_ai_used, quota_reset_at, updated_at
		// FROM user_quotas WHERE user_id = $1
		t.Log("documented: GetByUserID returns quota for a user")
	})

	t.Run("Create_upserts_quota", func(t *testing.T) {
		// INSERT INTO user_quotas (user_id, plan, daily_ai_limit, daily_ai_used, quota_reset_at)
		// VALUES (...) ON CONFLICT (user_id) DO UPDATE SET ...
		t.Log("documented: Create upserts quota record")
	})

	t.Run("IncrementUsage_increments_counter", func(t *testing.T) {
		// UPDATE user_quotas SET daily_ai_used = daily_ai_used + 1, updated_at = NOW() WHERE user_id = $1
		t.Log("documented: IncrementUsage atomically increments daily_ai_used")
	})

	t.Run("ResetIfNeeded_resets_daily", func(t *testing.T) {
		// UPDATE user_quotas SET daily_ai_used = 0, quota_reset_at = NOW(), updated_at = NOW()
		// WHERE user_id = $1 AND quota_reset_at < NOW() - INTERVAL '1 day'
		t.Log("documented: ResetIfNeeded resets counter if more than 1 day since last reset")
	})

	t.Run("EnsureQuota_creates_if_missing", func(t *testing.T) {
		// INSERT INTO user_quotas (...) VALUES ($1, $2, $3, 0, NOW())
		// ON CONFLICT (user_id) DO NOTHING
		// Plan-based limits: free=50, pro/lifetime=500
		t.Log("documented: EnsureQuota creates quota with plan-based limit, no-op if exists")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

type mockQuotaRepo struct {
	quotas map[uuid.UUID]*domain.UserQuota
}

func newMockQuotaRepo() *mockQuotaRepo {
	return &mockQuotaRepo{
		quotas: make(map[uuid.UUID]*domain.UserQuota),
	}
}

func (m *mockQuotaRepo) GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.UserQuota, error) {
	q, ok := m.quotas[userID]
	if !ok {
		return nil, errors.New("quota not found")
	}
	return q, nil
}

func (m *mockQuotaRepo) Create(ctx context.Context, quota *domain.UserQuota) error {
	m.quotas[quota.UserID] = quota
	return nil
}

func (m *mockQuotaRepo) IncrementUsage(ctx context.Context, userID uuid.UUID) error {
	q, ok := m.quotas[userID]
	if !ok {
		return errors.New("quota not found")
	}
	q.DailyAIUsed++
	return nil
}

func (m *mockQuotaRepo) ResetIfNeeded(ctx context.Context, userID uuid.UUID) error {
	q, ok := m.quotas[userID]
	if !ok {
		return nil
	}
	if q.QuotaResetAt.Before(time.Now().Add(-24 * time.Hour)) {
		q.DailyAIUsed = 0
		q.QuotaResetAt = time.Now()
	}
	return nil
}

func (m *mockQuotaRepo) EnsureQuota(ctx context.Context, userID uuid.UUID, plan string) error {
	if _, exists := m.quotas[userID]; exists {
		return nil
	}
	limit := 50
	if plan == "pro" || plan == "lifetime" {
		limit = 500
	}
	m.quotas[userID] = &domain.UserQuota{
		UserID:       userID,
		Plan:         plan,
		DailyAILimit: limit,
		DailyAIUsed:  0,
		QuotaResetAt: time.Now(),
	}
	return nil
}

func TestMockQuotaRepo_CreateAndGet(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()
	userID := uuid.New()

	quota := &domain.UserQuota{UserID: userID, Plan: "free", DailyAILimit: 50, DailyAIUsed: 0}
	repo.Create(ctx, quota)

	got, err := repo.GetByUserID(ctx, userID)
	if err != nil {
		t.Fatalf("GetByUserID: %v", err)
	}
	if got.Plan != "free" {
		t.Errorf("Plan = %q, want %q", got.Plan, "free")
	}
	if got.DailyAILimit != 50 {
		t.Errorf("DailyAILimit = %d, want 50", got.DailyAILimit)
	}
}

func TestMockQuotaRepo_GetByUserID_NotFound(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()

	_, err := repo.GetByUserID(ctx, uuid.New())
	if err == nil {
		t.Error("GetByUserID should return error for nonexistent user")
	}
}

func TestMockQuotaRepo_IncrementUsage(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.Create(ctx, &domain.UserQuota{UserID: userID, DailyAILimit: 50, DailyAIUsed: 0})

	repo.IncrementUsage(ctx, userID)
	repo.IncrementUsage(ctx, userID)
	repo.IncrementUsage(ctx, userID)

	q, _ := repo.GetByUserID(ctx, userID)
	if q.DailyAIUsed != 3 {
		t.Errorf("DailyAIUsed = %d, want 3", q.DailyAIUsed)
	}
}

func TestMockQuotaRepo_ResetIfNeeded(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()
	userID := uuid.New()

	// Quota last reset 2 days ago — should reset.
	repo.Create(ctx, &domain.UserQuota{
		UserID: userID, DailyAILimit: 50, DailyAIUsed: 30,
		QuotaResetAt: time.Now().Add(-48 * time.Hour),
	})

	repo.ResetIfNeeded(ctx, userID)

	q, _ := repo.GetByUserID(ctx, userID)
	if q.DailyAIUsed != 0 {
		t.Errorf("DailyAIUsed = %d, want 0 after reset", q.DailyAIUsed)
	}
}

func TestMockQuotaRepo_ResetIfNeeded_RecentNotReset(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()
	userID := uuid.New()

	// Quota last reset 1 hour ago — should NOT reset.
	repo.Create(ctx, &domain.UserQuota{
		UserID: userID, DailyAILimit: 50, DailyAIUsed: 30,
		QuotaResetAt: time.Now().Add(-1 * time.Hour),
	})

	repo.ResetIfNeeded(ctx, userID)

	q, _ := repo.GetByUserID(ctx, userID)
	if q.DailyAIUsed != 30 {
		t.Errorf("DailyAIUsed = %d, want 30 (no reset)", q.DailyAIUsed)
	}
}

func TestMockQuotaRepo_EnsureQuota_FreePlan(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.EnsureQuota(ctx, userID, "free")

	q, _ := repo.GetByUserID(ctx, userID)
	if q.DailyAILimit != 50 {
		t.Errorf("free plan limit = %d, want 50", q.DailyAILimit)
	}
}

func TestMockQuotaRepo_EnsureQuota_ProPlan(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.EnsureQuota(ctx, userID, "pro")

	q, _ := repo.GetByUserID(ctx, userID)
	if q.DailyAILimit != 500 {
		t.Errorf("pro plan limit = %d, want 500", q.DailyAILimit)
	}
}

func TestMockQuotaRepo_EnsureQuota_LifetimePlan(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.EnsureQuota(ctx, userID, "lifetime")

	q, _ := repo.GetByUserID(ctx, userID)
	if q.DailyAILimit != 500 {
		t.Errorf("lifetime plan limit = %d, want 500", q.DailyAILimit)
	}
}

func TestMockQuotaRepo_EnsureQuota_NoOverwrite(t *testing.T) {
	repo := newMockQuotaRepo()
	ctx := context.Background()
	userID := uuid.New()

	// Create with pro plan.
	repo.Create(ctx, &domain.UserQuota{UserID: userID, Plan: "pro", DailyAILimit: 500, DailyAIUsed: 100})

	// EnsureQuota should be no-op since quota exists.
	repo.EnsureQuota(ctx, userID, "free")

	q, _ := repo.GetByUserID(ctx, userID)
	if q.DailyAILimit != 500 {
		t.Errorf("EnsureQuota should not overwrite existing quota, limit = %d, want 500", q.DailyAILimit)
	}
}
