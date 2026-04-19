package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock QuotaRepository
// ---------------------------------------------------------------------------

type mockQuotaRepo struct {
	getByUserIDFn     func(ctx context.Context, userID uuid.UUID) (*domain.UserQuota, error)
	createFn          func(ctx context.Context, quota *domain.UserQuota) error
	incrementUsageFn  func(ctx context.Context, userID uuid.UUID) error
	resetIfNeededFn   func(ctx context.Context, userID uuid.UUID) error
}

func (m *mockQuotaRepo) GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.UserQuota, error) {
	if m.getByUserIDFn != nil {
		return m.getByUserIDFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockQuotaRepo) Create(ctx context.Context, quota *domain.UserQuota) error {
	if m.createFn != nil {
		return m.createFn(ctx, quota)
	}
	return errors.New("not implemented")
}

func (m *mockQuotaRepo) IncrementUsage(ctx context.Context, userID uuid.UUID) error {
	if m.incrementUsageFn != nil {
		return m.incrementUsageFn(ctx, userID)
	}
	return errors.New("not implemented")
}

func (m *mockQuotaRepo) ResetIfNeeded(ctx context.Context, userID uuid.UUID) error {
	if m.resetIfNeededFn != nil {
		return m.resetIfNeededFn(ctx, userID)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Tests: NewQuotaService
// ---------------------------------------------------------------------------

func TestNewQuotaService(t *testing.T) {
	repo := &mockQuotaRepo{}
	svc := NewQuotaService(repo)
	if svc == nil {
		t.Fatal("NewQuotaService returned nil")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetQuota
// ---------------------------------------------------------------------------

func TestQuotaService_GetQuota_Success(t *testing.T) {
	userID := uuid.New()
	resetAt := time.Now().Add(24 * time.Hour)

	repo := &mockQuotaRepo{
		getByUserIDFn: func(ctx context.Context, uid uuid.UUID) (*domain.UserQuota, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			return &domain.UserQuota{
				UserID:       userID,
				Plan:         "pro",
				DailyAILimit: 500,
				DailyAIUsed:  42,
				QuotaResetAt: resetAt,
			}, nil
		},
	}

	svc := NewQuotaService(repo)
	resp, err := svc.GetQuota(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetQuota: %v", err)
	}
	if resp.Plan != "pro" {
		t.Errorf("Plan = %q, want %q", resp.Plan, "pro")
	}
	if resp.DailyLimit != 500 {
		t.Errorf("DailyLimit = %d, want 500", resp.DailyLimit)
	}
	if resp.DailyUsed != 42 {
		t.Errorf("DailyUsed = %d, want 42", resp.DailyUsed)
	}
}

func TestQuotaService_GetQuota_RepoError(t *testing.T) {
	userID := uuid.New()

	repo := &mockQuotaRepo{
		getByUserIDFn: func(ctx context.Context, uid uuid.UUID) (*domain.UserQuota, error) {
			return nil, errors.New("database error")
		},
	}

	svc := NewQuotaService(repo)
	resp, err := svc.GetQuota(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetQuota should not return error on repo failure: %v", err)
	}
	// Should return default free quota
	if resp.Plan != "free" {
		t.Errorf("Plan = %q, want %q", resp.Plan, "free")
	}
	if resp.DailyLimit != 50 {
		t.Errorf("DailyLimit = %d, want 50", resp.DailyLimit)
	}
	if resp.DailyUsed != 0 {
		t.Errorf("DailyUsed = %d, want 0", resp.DailyUsed)
	}
}

func TestQuotaService_GetQuota_ResetsQuota(t *testing.T) {
	userID := uuid.New()
	resetCalled := false

	repo := &mockQuotaRepo{
		resetIfNeededFn: func(ctx context.Context, uid uuid.UUID) error {
			resetCalled = true
			return nil
		},
		getByUserIDFn: func(ctx context.Context, uid uuid.UUID) (*domain.UserQuota, error) {
			return &domain.UserQuota{
				UserID:       userID,
				Plan:         "free",
				DailyAILimit: 50,
				DailyAIUsed:  10,
				QuotaResetAt: time.Now().Add(24 * time.Hour),
			}, nil
		},
	}

	svc := NewQuotaService(repo)
	_, err := svc.GetQuota(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetQuota: %v", err)
	}
	if !resetCalled {
		t.Error("expected ResetIfNeeded to be called")
	}
}

// ---------------------------------------------------------------------------
// Tests: IncrementUsage
// ---------------------------------------------------------------------------

func TestQuotaService_IncrementUsage_Success(t *testing.T) {
	userID := uuid.New()
	resetCalled := false
	incrementCalled := false

	repo := &mockQuotaRepo{
		resetIfNeededFn: func(ctx context.Context, uid uuid.UUID) error {
			resetCalled = true
			return nil
		},
		incrementUsageFn: func(ctx context.Context, uid uuid.UUID) error {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			incrementCalled = true
			return nil
		},
	}

	svc := NewQuotaService(repo)
	err := svc.IncrementUsage(context.Background(), userID)
	if err != nil {
		t.Fatalf("IncrementUsage: %v", err)
	}
	if !resetCalled {
		t.Error("expected ResetIfNeeded to be called")
	}
	if !incrementCalled {
		t.Error("expected IncrementUsage to be called")
	}
}

func TestQuotaService_IncrementUsage_IncrementError(t *testing.T) {
	userID := uuid.New()

	repo := &mockQuotaRepo{
		incrementUsageFn: func(ctx context.Context, uid uuid.UUID) error {
			return errors.New("quota exceeded")
		},
	}

	svc := NewQuotaService(repo)
	err := svc.IncrementUsage(context.Background(), userID)
	if err == nil {
		t.Error("expected error when IncrementUsage fails")
	}
}

func TestQuotaService_IncrementUsage_ResetErrorIgnored(t *testing.T) {
	userID := uuid.New()
	incrementCalled := false

	repo := &mockQuotaRepo{
		resetIfNeededFn: func(ctx context.Context, uid uuid.UUID) error {
			return errors.New("reset failed")
		},
		incrementUsageFn: func(ctx context.Context, uid uuid.UUID) error {
			incrementCalled = true
			return nil
		},
	}

	svc := NewQuotaService(repo)
	err := svc.IncrementUsage(context.Background(), userID)
	if err != nil {
		t.Fatalf("IncrementUsage should not fail when reset fails: %v", err)
	}
	if !incrementCalled {
		t.Error("expected IncrementUsage to still be called")
	}
}

// ---------------------------------------------------------------------------
// Tests: Plan limit constants
// ---------------------------------------------------------------------------

func TestQuotaPlanLimits(t *testing.T) {
	limits := map[string]int{
		"free":      50,
		"pro":       500,
		"lifetime":  500,
	}

	for plan, expectedLimit := range limits {
		t.Run(plan, func(t *testing.T) {
			if limits[plan] != expectedLimit {
				t.Errorf("plan %q limit = %d, want %d", plan, limits[plan], expectedLimit)
			}
		})
	}
}
