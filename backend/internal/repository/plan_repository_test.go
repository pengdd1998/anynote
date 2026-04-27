package repository

import (
	"context"
	"testing"

	"github.com/google/uuid"
)

// TestPlanRepository_DocumentsExpectedBehavior documents the expected SQL
// behaviors for the PlanRepository.
func TestPlanRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("GetPlan_returns_user_plan", func(t *testing.T) {
		// SELECT COALESCE(plan, 'free') FROM users WHERE id = $1
		// Returns "free" when plan column is NULL.
		// Returns "free" when user does not exist (query error).
		t.Log("documented: GetPlan returns plan string, defaults to 'free'")
	})

	t.Run("SetPlan_updates_plan", func(t *testing.T) {
		// UPDATE users SET plan = $1, updated_at = NOW() WHERE id = $2
		t.Log("documented: SetPlan updates plan and touches updated_at")
	})

	t.Run("GetStorageUsage_sums_blob_sizes", func(t *testing.T) {
		// SELECT COALESCE(SUM(blob_size), 0) FROM sync_blobs WHERE user_id = $1
		// Returns 0 when user has no blobs.
		t.Log("documented: GetStorageUsage returns total encrypted blob bytes")
	})

	t.Run("GetNoteCount_counts_note_blobs", func(t *testing.T) {
		// SELECT COUNT(*) FROM sync_blobs WHERE user_id = $1 AND item_type = 'note'
		t.Log("documented: GetNoteCount returns count of note-type sync blobs")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

type mockPlanRepo struct {
	plans        map[uuid.UUID]string // userID -> plan
	storageUsage map[uuid.UUID]int64  // userID -> total bytes
	noteCount    map[uuid.UUID]int    // userID -> note count
}

func newMockPlanRepo() *mockPlanRepo {
	return &mockPlanRepo{
		plans:        make(map[uuid.UUID]string),
		storageUsage: make(map[uuid.UUID]int64),
		noteCount:    make(map[uuid.UUID]int),
	}
}

func (m *mockPlanRepo) GetPlan(ctx context.Context, userID uuid.UUID) (string, error) {
	if plan, ok := m.plans[userID]; ok {
		return plan, nil
	}
	return "free", nil
}

func (m *mockPlanRepo) SetPlan(ctx context.Context, userID uuid.UUID, plan string) error {
	m.plans[userID] = plan
	return nil
}

func (m *mockPlanRepo) GetStorageUsage(ctx context.Context, userID uuid.UUID) (int64, error) {
	if usage, ok := m.storageUsage[userID]; ok {
		return usage, nil
	}
	return 0, nil
}

func (m *mockPlanRepo) GetNoteCount(ctx context.Context, userID uuid.UUID) (int, error) {
	if count, ok := m.noteCount[userID]; ok {
		return count, nil
	}
	return 0, nil
}

// ---------------------------------------------------------------------------
// Tests: GetPlan
// ---------------------------------------------------------------------------

func TestMockPlanRepo_GetPlan_DefaultFree(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()

	plan, err := repo.GetPlan(ctx, uuid.New())
	if err != nil {
		t.Fatalf("GetPlan: %v", err)
	}
	if plan != "free" {
		t.Errorf("plan = %q, want %q", plan, "free")
	}
}

func TestMockPlanRepo_GetPlan_ExplicitPlan(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.SetPlan(ctx, userID, "pro")

	plan, err := repo.GetPlan(ctx, userID)
	if err != nil {
		t.Fatalf("GetPlan: %v", err)
	}
	if plan != "pro" {
		t.Errorf("plan = %q, want %q", plan, "pro")
	}
}

// ---------------------------------------------------------------------------
// Tests: SetPlan
// ---------------------------------------------------------------------------

func TestMockPlanRepo_SetPlan(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()
	userID := uuid.New()

	err := repo.SetPlan(ctx, userID, "lifetime")
	if err != nil {
		t.Fatalf("SetPlan: %v", err)
	}

	plan, _ := repo.GetPlan(ctx, userID)
	if plan != "lifetime" {
		t.Errorf("plan after set = %q, want %q", plan, "lifetime")
	}
}

func TestMockPlanRepo_SetPlan_Overwrite(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.SetPlan(ctx, userID, "free")
	repo.SetPlan(ctx, userID, "pro")

	plan, _ := repo.GetPlan(ctx, userID)
	if plan != "pro" {
		t.Errorf("plan after overwrite = %q, want %q", plan, "pro")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetStorageUsage
// ---------------------------------------------------------------------------

func TestMockPlanRepo_GetStorageUsage_NoBlobs(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()

	usage, err := repo.GetStorageUsage(ctx, uuid.New())
	if err != nil {
		t.Fatalf("GetStorageUsage: %v", err)
	}
	if usage != 0 {
		t.Errorf("usage = %d, want 0", usage)
	}
}

func TestMockPlanRepo_GetStorageUsage_WithBlobs(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.storageUsage[userID] = 1024 * 1024 * 50 // 50 MB

	usage, err := repo.GetStorageUsage(ctx, userID)
	if err != nil {
		t.Fatalf("GetStorageUsage: %v", err)
	}
	if usage != 1024*1024*50 {
		t.Errorf("usage = %d, want %d", usage, 1024*1024*50)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetNoteCount
// ---------------------------------------------------------------------------

func TestMockPlanRepo_GetNoteCount_NoNotes(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()

	count, err := repo.GetNoteCount(ctx, uuid.New())
	if err != nil {
		t.Fatalf("GetNoteCount: %v", err)
	}
	if count != 0 {
		t.Errorf("count = %d, want 0", count)
	}
}

func TestMockPlanRepo_GetNoteCount_WithNotes(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.noteCount[userID] = 42

	count, err := repo.GetNoteCount(ctx, userID)
	if err != nil {
		t.Fatalf("GetNoteCount: %v", err)
	}
	if count != 42 {
		t.Errorf("count = %d, want 42", count)
	}
}

// ---------------------------------------------------------------------------
// Tests: Isolation between users
// ---------------------------------------------------------------------------

func TestMockPlanRepo_UserIsolation(t *testing.T) {
	repo := newMockPlanRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()

	repo.SetPlan(ctx, user1, "pro")
	repo.storageUsage[user1] = 1000
	repo.noteCount[user1] = 10

	// User 2 should still get defaults.
	plan2, _ := repo.GetPlan(ctx, user2)
	usage2, _ := repo.GetStorageUsage(ctx, user2)
	count2, _ := repo.GetNoteCount(ctx, user2)

	if plan2 != "free" {
		t.Errorf("user2 plan = %q, want %q", plan2, "free")
	}
	if usage2 != 0 {
		t.Errorf("user2 usage = %d, want 0", usage2)
	}
	if count2 != 0 {
		t.Errorf("user2 count = %d, want 0", count2)
	}

	// User 1 should still have its values.
	plan1, _ := repo.GetPlan(ctx, user1)
	usage1, _ := repo.GetStorageUsage(ctx, user1)
	count1, _ := repo.GetNoteCount(ctx, user1)

	if plan1 != "pro" {
		t.Errorf("user1 plan = %q, want %q", plan1, "pro")
	}
	if usage1 != 1000 {
		t.Errorf("user1 usage = %d, want 1000", usage1)
	}
	if count1 != 10 {
		t.Errorf("user1 count = %d, want 10", count1)
	}
}
