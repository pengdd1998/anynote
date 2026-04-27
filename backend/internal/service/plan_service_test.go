package service

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock PlanRepo
// ---------------------------------------------------------------------------

type mockPlanRepo struct {
	plan          string
	planErr       error
	storageUsage  int64
	storageErr    error
	noteCount     int
	noteCountErr  error
	setPlanErr    error
	setPlanCalled bool
	setPlanArg    string
}

func (m *mockPlanRepo) GetPlan(_ context.Context, _ uuid.UUID) (string, error) {
	if m.planErr != nil {
		return "", m.planErr
	}
	return m.plan, nil
}

func (m *mockPlanRepo) SetPlan(_ context.Context, _ uuid.UUID, plan string) error {
	m.setPlanCalled = true
	m.setPlanArg = plan
	return m.setPlanErr
}

func (m *mockPlanRepo) GetStorageUsage(_ context.Context, _ uuid.UUID) (int64, error) {
	if m.storageErr != nil {
		return 0, m.storageErr
	}
	return m.storageUsage, nil
}

func (m *mockPlanRepo) GetNoteCount(_ context.Context, _ uuid.UUID) (int, error) {
	if m.noteCountErr != nil {
		return 0, m.noteCountErr
	}
	return m.noteCount, nil
}

// ---------------------------------------------------------------------------
// Mock QuotaReader
// ---------------------------------------------------------------------------

type mockQuotaReader struct {
	quota *domain.UserQuota
	err   error
}

func (m *mockQuotaReader) GetByUserID(_ context.Context, _ uuid.UUID) (*domain.UserQuota, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.quota, nil
}

// ---------------------------------------------------------------------------
// Tests: GetUserPlan
// ---------------------------------------------------------------------------

func TestPlanService_GetUserPlan_FreePlanWithUsage(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:         "free",
		storageUsage: 50 * 1024 * 1024, // 50 MB
		noteCount:    42,
	}
	quotaRepo := &mockQuotaReader{
		quota: &domain.UserQuota{
			DailyAIUsed: 10,
		},
	}

	svc := NewPlanService(planRepo, quotaRepo)
	info, err := svc.GetUserPlan(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetUserPlan: %v", err)
	}

	if info.Plan != domain.PlanFree {
		t.Errorf("Plan = %q, want %q", info.Plan, domain.PlanFree)
	}
	freeLimits := domain.PlanLimitsMap[domain.PlanFree]
	if info.Limits != freeLimits {
		t.Errorf("Limits = %+v, want %+v", info.Limits, freeLimits)
	}
	if info.AIDailyUsed != 10 {
		t.Errorf("AIDailyUsed = %d, want 10", info.AIDailyUsed)
	}
	if info.StorageBytes != 50*1024*1024 {
		t.Errorf("StorageBytes = %d, want %d", info.StorageBytes, 50*1024*1024)
	}
	if info.NoteCount != 42 {
		t.Errorf("NoteCount = %d, want 42", info.NoteCount)
	}
}

func TestPlanService_GetUserPlan_LifetimePlan(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:         "lifetime",
		storageUsage: 10 * 1024 * 1024 * 1024, // 10 GB
		noteCount:    5000,
	}
	quotaRepo := &mockQuotaReader{
		quota: &domain.UserQuota{DailyAIUsed: 200},
	}

	svc := NewPlanService(planRepo, quotaRepo)
	info, err := svc.GetUserPlan(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetUserPlan: %v", err)
	}

	if info.Plan != domain.PlanLifetime {
		t.Errorf("Plan = %q, want %q", info.Plan, domain.PlanLifetime)
	}
	ltLimits := domain.PlanLimitsMap[domain.PlanLifetime]
	if info.Limits != ltLimits {
		t.Errorf("Limits should match lifetime plan limits")
	}
}

func TestPlanService_GetUserPlan_PlanRepoError(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		planErr: errors.New("db connection lost"),
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	_, err := svc.GetUserPlan(context.Background(), userID)
	if err == nil {
		t.Error("expected error when plan repo fails")
	}
}

func TestPlanService_GetUserPlan_QuotaRepoError_GracefulDegradation(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:       "free",
		noteCount:  5,
	}
	quotaRepo := &mockQuotaReader{
		err: errors.New("quota lookup failed"),
	}

	svc := NewPlanService(planRepo, quotaRepo)
	info, err := svc.GetUserPlan(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetUserPlan should not fail when quota repo errors: %v", err)
	}
	if info.AIDailyUsed != 0 {
		t.Errorf("AIDailyUsed = %d, want 0 on quota error", info.AIDailyUsed)
	}
}

func TestPlanService_GetUserPlan_StorageRepoError_GracefulDegradation(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:       "free",
		storageErr: errors.New("storage lookup failed"),
		noteCount:  5,
	}
	quotaRepo := &mockQuotaReader{quota: &domain.UserQuota{DailyAIUsed: 0}}

	svc := NewPlanService(planRepo, quotaRepo)
	info, err := svc.GetUserPlan(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetUserPlan should not fail when storage repo errors: %v", err)
	}
	if info.StorageBytes != 0 {
		t.Errorf("StorageBytes = %d, want 0 on storage error", info.StorageBytes)
	}
}

func TestPlanService_GetUserPlan_NoteCountError_GracefulDegradation(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:          "free",
		storageUsage:  1024,
		noteCountErr:  errors.New("count failed"),
	}
	quotaRepo := &mockQuotaReader{quota: &domain.UserQuota{}}

	svc := NewPlanService(planRepo, quotaRepo)
	info, err := svc.GetUserPlan(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetUserPlan should not fail when note count errors: %v", err)
	}
	if info.NoteCount != 0 {
		t.Errorf("NoteCount = %d, want 0 on note count error", info.NoteCount)
	}
}

// ---------------------------------------------------------------------------
// Tests: CheckLimit
// ---------------------------------------------------------------------------

func TestPlanService_CheckLimit_AIDailyUnderQuota(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{
		quota: &domain.UserQuota{DailyAIUsed: 10}, // free limit is 50
	}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "ai_daily")
	if err != nil {
		t.Errorf("CheckLimit(ai_daily) = %v, want nil", err)
	}
}

func TestPlanService_CheckLimit_AIDailyAtQuota(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{
		quota: &domain.UserQuota{DailyAIUsed: 50}, // free limit is 50
	}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "ai_daily")
	if !errors.Is(err, ErrPlanLimitExceeded) {
		t.Errorf("CheckLimit(ai_daily) = %v, want ErrPlanLimitExceeded", err)
	}
}

func TestPlanService_CheckLimit_AIDailyOverQuota(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{
		quota: &domain.UserQuota{DailyAIUsed: 100},
	}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "ai_daily")
	if !errors.Is(err, ErrPlanLimitExceeded) {
		t.Errorf("CheckLimit(ai_daily) = %v, want ErrPlanLimitExceeded", err)
	}
}

func TestPlanService_CheckLimit_AIDailyUnlimited(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "lifetime"} // lifetime has AIDailyQuota = -1
	quotaRepo := &mockQuotaReader{
		quota: &domain.UserQuota{DailyAIUsed: 9999},
	}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "ai_daily")
	if err != nil {
		t.Errorf("CheckLimit(ai_daily) with lifetime plan = %v, want nil (unlimited)", err)
	}
}

func TestPlanService_CheckLimit_AIDailyQuotaRepoError_GracefulDegradation(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{err: errors.New("quota lookup failed")}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "ai_daily")
	if err != nil {
		t.Errorf("CheckLimit(ai_daily) with quota error = %v, want nil (graceful degradation)", err)
	}
}

func TestPlanService_CheckLimit_StorageUnderLimit(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:         "free",
		storageUsage: 50 * 1024 * 1024, // 50 MB, limit is 100 MB
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "storage")
	if err != nil {
		t.Errorf("CheckLimit(storage) = %v, want nil", err)
	}
}

func TestPlanService_CheckLimit_StorageAtLimit(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:         "free",
		storageUsage: 100 * 1024 * 1024, // exactly 100 MB = limit
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "storage")
	if !errors.Is(err, ErrPlanLimitExceeded) {
		t.Errorf("CheckLimit(storage) = %v, want ErrPlanLimitExceeded", err)
	}
}

func TestPlanService_CheckLimit_StorageUnlimited(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:         "lifetime",
		storageUsage: 1_000_000_000_000, // 1 TB
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "storage")
	if err != nil {
		t.Errorf("CheckLimit(storage) with lifetime = %v, want nil (unlimited)", err)
	}
}

func TestPlanService_CheckLimit_StorageRepoError_GracefulDegradation(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:       "free",
		storageErr: errors.New("storage lookup failed"),
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "storage")
	if err != nil {
		t.Errorf("CheckLimit(storage) with repo error = %v, want nil (graceful degradation)", err)
	}
}

func TestPlanService_CheckLimit_NotesUnderLimit(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:       "free",
		noteCount:  100, // limit is 500
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "notes")
	if err != nil {
		t.Errorf("CheckLimit(notes) = %v, want nil", err)
	}
}

func TestPlanService_CheckLimit_NotesAtLimit(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:      "free",
		noteCount: 500, // exactly the limit
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "notes")
	if !errors.Is(err, ErrPlanLimitExceeded) {
		t.Errorf("CheckLimit(notes) = %v, want ErrPlanLimitExceeded", err)
	}
}

func TestPlanService_CheckLimit_NotesUnlimited(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:      "lifetime",
		noteCount: 100000,
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "notes")
	if err != nil {
		t.Errorf("CheckLimit(notes) with lifetime = %v, want nil (unlimited)", err)
	}
}

func TestPlanService_CheckLimit_NotesRepoError_GracefulDegradation(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:          "free",
		noteCountErr:  errors.New("count failed"),
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.CheckLimit(context.Background(), userID, "notes")
	if err != nil {
		t.Errorf("CheckLimit(notes) with repo error = %v, want nil (graceful degradation)", err)
	}
}

func TestPlanService_CheckLimit_Publish(t *testing.T) {
	tests := []struct {
		name    string
		plan    string
		wantErr error
	}{
		{"free_can_publish", "free", nil},
		{"pro_can_publish", "pro", nil},
		{"lifetime_can_publish", "lifetime", nil},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			planRepo := &mockPlanRepo{plan: tc.plan}
			quotaRepo := &mockQuotaReader{}
			svc := NewPlanService(planRepo, quotaRepo)

			err := svc.CheckLimit(context.Background(), uuid.New(), "publish")
			if !errors.Is(err, tc.wantErr) {
				t.Errorf("CheckLimit(publish) plan=%q = %v, want %v", tc.plan, err, tc.wantErr)
			}
		})
	}
}

func TestPlanService_CheckLimit_Collaborate(t *testing.T) {
	tests := []struct {
		name    string
		plan    string
		wantErr error
	}{
		{"free_cannot_collaborate", "free", ErrPlanLimitExceeded},
		{"pro_can_collaborate", "pro", nil},
		{"lifetime_can_collaborate", "lifetime", nil},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			planRepo := &mockPlanRepo{plan: tc.plan}
			quotaRepo := &mockQuotaReader{}
			svc := NewPlanService(planRepo, quotaRepo)

			err := svc.CheckLimit(context.Background(), uuid.New(), "collaborate")
			if !errors.Is(err, tc.wantErr) {
				t.Errorf("CheckLimit(collaborate) plan=%q = %v, want %v", tc.plan, err, tc.wantErr)
			}
		})
	}
}

func TestPlanService_CheckLimit_UnknownType(t *testing.T) {
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{}
	svc := NewPlanService(planRepo, quotaRepo)

	err := svc.CheckLimit(context.Background(), uuid.New(), "unknown_limit")
	if err == nil {
		t.Error("CheckLimit(unknown) = nil, want error")
	}
	if errors.Is(err, ErrPlanLimitExceeded) {
		t.Error("CheckLimit(unknown) should not be ErrPlanLimitExceeded")
	}
}

func TestPlanService_CheckLimit_PlanRepoError(t *testing.T) {
	planRepo := &mockPlanRepo{planErr: errors.New("db error")}
	quotaRepo := &mockQuotaReader{}
	svc := NewPlanService(planRepo, quotaRepo)

	err := svc.CheckLimit(context.Background(), uuid.New(), "ai_daily")
	if err == nil {
		t.Error("CheckLimit with plan repo error = nil, want error")
	}
}

// ---------------------------------------------------------------------------
// Tests: UpgradePlan
// ---------------------------------------------------------------------------

func TestPlanService_UpgradePlan_FreeToPro(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.UpgradePlan(context.Background(), userID, domain.PlanPro, "payment-ref-123")
	if err != nil {
		t.Fatalf("UpgradePlan: %v", err)
	}
	if !planRepo.setPlanCalled {
		t.Error("SetPlan should have been called")
	}
	if planRepo.setPlanArg != "pro" {
		t.Errorf("SetPlan arg = %q, want %q", planRepo.setPlanArg, "pro")
	}
}

func TestPlanService_UpgradePlan_FreeToLifetime(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.UpgradePlan(context.Background(), userID, domain.PlanLifetime, "lifetime-payment")
	if err != nil {
		t.Fatalf("UpgradePlan: %v", err)
	}
	if planRepo.setPlanArg != "lifetime" {
		t.Errorf("SetPlan arg = %q, want %q", planRepo.setPlanArg, "lifetime")
	}
}

func TestPlanService_UpgradePlan_InvalidPlan(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.UpgradePlan(context.Background(), userID, domain.Plan("enterprise"), "pay-ref")
	if !errors.Is(err, ErrInvalidPlan) {
		t.Errorf("UpgradePlan with invalid plan = %v, want ErrInvalidPlan", err)
	}
	if planRepo.setPlanCalled {
		t.Error("SetPlan should NOT have been called for invalid plan")
	}
}

func TestPlanService_UpgradePlan_EmptyPlan(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "free"}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.UpgradePlan(context.Background(), userID, domain.Plan(""), "pay-ref")
	if !errors.Is(err, ErrInvalidPlan) {
		t.Errorf("UpgradePlan with empty plan = %v, want ErrInvalidPlan", err)
	}
}

func TestPlanService_UpgradePlan_CannotDowngradeFromLifetime(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "lifetime"}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.UpgradePlan(context.Background(), userID, domain.PlanPro, "pay-ref")
	if err == nil {
		t.Error("expected error when downgrading from lifetime")
	}
	if planRepo.setPlanCalled {
		t.Error("SetPlan should NOT have been called when downgrading from lifetime")
	}
}

func TestPlanService_UpgradePlan_CanReSelectLifetime(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{plan: "lifetime"}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.UpgradePlan(context.Background(), userID, domain.PlanLifetime, "pay-ref")
	if err != nil {
		t.Fatalf("UpgradePlan(lifetime -> lifetime) = %v, want nil", err)
	}
	if !planRepo.setPlanCalled {
		t.Error("SetPlan should have been called")
	}
}

func TestPlanService_UpgradePlan_PlanRepoGetError(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		planErr: errors.New("db error"),
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.UpgradePlan(context.Background(), userID, domain.PlanPro, "pay-ref")
	if err == nil {
		t.Error("expected error when plan repo GetPlan fails")
	}
}

func TestPlanService_UpgradePlan_SetPlanError(t *testing.T) {
	userID := uuid.New()
	planRepo := &mockPlanRepo{
		plan:       "free",
		setPlanErr: errors.New("write failed"),
	}
	quotaRepo := &mockQuotaReader{}

	svc := NewPlanService(planRepo, quotaRepo)
	err := svc.UpgradePlan(context.Background(), userID, domain.PlanPro, "pay-ref")
	if err == nil {
		t.Error("expected error when SetPlan fails")
	}
}
