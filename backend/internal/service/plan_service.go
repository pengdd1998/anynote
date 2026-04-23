package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// Plan-related sentinel errors.
var (
	ErrPlanLimitExceeded = errors.New("plan limit exceeded")
	ErrInvalidPlan       = errors.New("invalid plan")
)

// PlanRepository defines the data access interface for plan operations.
type PlanRepo interface {
	GetPlan(ctx context.Context, userID uuid.UUID) (string, error)
	SetPlan(ctx context.Context, userID uuid.UUID, plan string) error
	GetStorageUsage(ctx context.Context, userID uuid.UUID) (int64, error)
	GetNoteCount(ctx context.Context, userID uuid.UUID) (int, error)
}

// QuotaReader defines the interface for reading AI quota data.
type QuotaReader interface {
	GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.UserQuota, error)
}

// PlanService provides plan management business logic.
type PlanService interface {
	GetUserPlan(ctx context.Context, userID uuid.UUID) (*domain.PlanInfo, error)
	CheckLimit(ctx context.Context, userID uuid.UUID, limitType string) error
	UpgradePlan(ctx context.Context, userID uuid.UUID, plan domain.Plan, paymentRef string) error
}

type planService struct {
	planRepo  PlanRepo
	quotaRepo QuotaReader
}

// NewPlanService creates a new plan service.
func NewPlanService(planRepo PlanRepo, quotaRepo QuotaReader) PlanService {
	return &planService{
		planRepo:  planRepo,
		quotaRepo: quotaRepo,
	}
}

// GetUserPlan returns the current plan and usage info for the given user.
func (s *planService) GetUserPlan(ctx context.Context, userID uuid.UUID) (*domain.PlanInfo, error) {
	planStr, err := s.planRepo.GetPlan(ctx, userID)
	if err != nil {
		return nil, err
	}
	plan := domain.Plan(planStr)
	limits := domain.GetPlanLimits(plan)

	// Get usage data (non-blocking: default to zero on error).
	var aiDailyUsed int
	if quota, err := s.quotaRepo.GetByUserID(ctx, userID); err == nil {
		aiDailyUsed = quota.DailyAIUsed
	}

	var storageBytes int64
	if usage, err := s.planRepo.GetStorageUsage(ctx, userID); err == nil {
		storageBytes = usage
	}

	var noteCount int
	if count, err := s.planRepo.GetNoteCount(ctx, userID); err == nil {
		noteCount = count
	}

	return &domain.PlanInfo{
		Plan:         plan,
		Limits:       limits,
		AIDailyUsed:  aiDailyUsed,
		StorageBytes: storageBytes,
		NoteCount:    noteCount,
	}, nil
}

// CheckLimit verifies whether the user is within the specified limit.
// Returns nil if the limit is not exceeded, or ErrPlanLimitExceeded otherwise.
func (s *planService) CheckLimit(ctx context.Context, userID uuid.UUID, limitType string) error {
	planStr, err := s.planRepo.GetPlan(ctx, userID)
	if err != nil {
		return err
	}
	plan := domain.Plan(planStr)
	limits := domain.GetPlanLimits(plan)

	switch limitType {
	case "ai_daily":
		// -1 means unlimited
		if limits.AIDailyQuota == -1 {
			return nil
		}
		quota, err := s.quotaRepo.GetByUserID(ctx, userID)
		if err != nil {
			return nil // graceful degradation
		}
		if quota.DailyAIUsed >= limits.AIDailyQuota {
			return ErrPlanLimitExceeded
		}
	case "storage":
		if limits.MaxStorageBytes == -1 {
			return nil
		}
		usage, err := s.planRepo.GetStorageUsage(ctx, userID)
		if err != nil {
			return nil // graceful degradation
		}
		if usage >= limits.MaxStorageBytes {
			return ErrPlanLimitExceeded
		}
	case "notes":
		if limits.MaxNotes == -1 {
			return nil
		}
		count, err := s.planRepo.GetNoteCount(ctx, userID)
		if err != nil {
			return nil // graceful degradation
		}
		if count >= limits.MaxNotes {
			return ErrPlanLimitExceeded
		}
	case "publish":
		if !limits.CanPublish {
			return ErrPlanLimitExceeded
		}
	case "collaborate":
		if !limits.CanCollaborate {
			return ErrPlanLimitExceeded
		}
	default:
		return fmt.Errorf("unknown limit type: %s", limitType)
	}
	return nil
}

// UpgradePlan changes the user's plan. In production this would verify payment;
// for now it accepts any valid plan as a stub.
func (s *planService) UpgradePlan(ctx context.Context, userID uuid.UUID, plan domain.Plan, paymentRef string) error {
	if !domain.ValidPlans[plan] {
		return ErrInvalidPlan
	}
	// Cannot downgrade from lifetime.
	currentPlan, err := s.planRepo.GetPlan(ctx, userID)
	if err != nil {
		return err
	}
	if domain.Plan(currentPlan) == domain.PlanLifetime && plan != domain.PlanLifetime {
		return fmt.Errorf("cannot downgrade from lifetime plan")
	}
	return s.planRepo.SetPlan(ctx, userID, string(plan))
}
