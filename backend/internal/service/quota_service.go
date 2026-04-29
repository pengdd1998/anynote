package service

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

type QuotaService interface {
	GetQuota(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error)
	IncrementUsage(ctx context.Context, userID uuid.UUID) error
}

type QuotaRepository interface {
	GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.UserQuota, error)
	Create(ctx context.Context, quota *domain.UserQuota) error
	IncrementUsage(ctx context.Context, userID uuid.UUID) error
	ResetIfNeeded(ctx context.Context, userID uuid.UUID) error
}

type quotaService struct {
	quotaRepo QuotaRepository
	// lastReset stores the UTC date (as "2006-01-02") when each user's quota
	// was last reset, so we skip unnecessary DB writes when the period has not
	// changed.  Protected by resetMu.
	lastReset sync.Map // map[string]string  (userID -> date string)
}

func NewQuotaService(quotaRepo QuotaRepository) QuotaService {
	return &quotaService{quotaRepo: quotaRepo}
}

// resetIfNeeded checks an in-memory cache before calling the repository.
// If the cached reset date for the user is already today (UTC), the call is
// skipped entirely, avoiding a database write on every request.
func (s *quotaService) resetIfNeeded(ctx context.Context, userID uuid.UUID) {
	today := time.Now().UTC().Format("2006-01-02")
	key := userID.String()

	if cached, ok := s.lastReset.Load(key); ok {
		if cachedStr, _ := cached.(string); cachedStr == today {
			return // Already reset today; no DB call needed.
		}
	}

	if resetErr := s.quotaRepo.ResetIfNeeded(ctx, userID); resetErr != nil {
		slog.Warn("quota: failed to check reset", "user_id", key, "error", resetErr)
		return
	}

	// Update the cache regardless of whether a reset actually occurred.
	// The SQL in ResetIfNeeded only writes when quota_reset_at is stale,
	// so a successful call means the reset date is now current.
	s.lastReset.Store(key, today)
}

func (s *quotaService) GetQuota(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
	// Reset quota if needed (daily reset)
	s.resetIfNeeded(ctx, userID)

	quota, err := s.quotaRepo.GetByUserID(ctx, userID)
	if err != nil {
		// Return default free quota
		return &domain.QuotaResponse{
			Plan:       "free",
			DailyLimit: 50,
			DailyUsed:  0,
			ResetAt:    time.Now().Add(24 * time.Hour),
		}, nil
	}

	return &domain.QuotaResponse{
		Plan:       quota.Plan,
		DailyLimit: quota.DailyAILimit,
		DailyUsed:  quota.DailyAIUsed,
		ResetAt:    quota.QuotaResetAt,
	}, nil
}

func (s *quotaService) IncrementUsage(ctx context.Context, userID uuid.UUID) error {
	s.resetIfNeeded(ctx, userID)
	return s.quotaRepo.IncrementUsage(ctx, userID)
}
