package service

import (
	"context"
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
}

func NewQuotaService(quotaRepo QuotaRepository) QuotaService {
	return &quotaService{quotaRepo: quotaRepo}
}

func (s *quotaService) GetQuota(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
	// Reset quota if needed (daily reset)
	_ = s.quotaRepo.ResetIfNeeded(ctx, userID)

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
	_ = s.quotaRepo.ResetIfNeeded(ctx, userID)
	return s.quotaRepo.IncrementUsage(ctx, userID)
}
