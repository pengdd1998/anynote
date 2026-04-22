//go:build integration

package repository

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/testutil"
)

// sharedNoteTestRepo returns a SharedNoteRepository backed by the shared
// integration pool. It truncates dependent tables before each test.
func sharedNoteTestRepo(t *testing.T) *SharedNoteRepository {
	t.Helper()
	pool := ensurePool(t)
	testutil.CleanTable(t, pool,
		"note_reactions",
		"note_comments",
		"shared_notes",
		"users",
	)
	return NewSharedNoteRepository(pool)
}

// seedSharedNoteUser creates a test user and returns the UUID.
func seedSharedNoteUser(t *testing.T) uuid.UUID {
	t.Helper()
	pool := ensurePool(t)
	id := uuid.New()
	email := fmt.Sprintf("sn-%s@example.com", id.String()[:8])
	username := fmt.Sprintf("snuser_%s", id.String()[:8])
	testutil.SeedUser(t, pool, id.String(), email, username)
	return id
}

// makeTestSharedNote creates a SharedNote domain object for testing.
func makeTestSharedNote(userID uuid.UUID, isPublic bool, expiresAt *time.Time) *domain.SharedNote {
	id := uuid.New().String()
	return &domain.SharedNote{
		ID:               id,
		EncryptedContent: "encrypted-content-" + id[:8],
		EncryptedTitle:   "encrypted-title-" + id[:8],
		ShareKeyHash:     "hash-" + id[:8],
		HasPassword:      false,
		IsPublic:         isPublic,
		ExpiresAt:        expiresAt,
		ViewCount:        0,
		MaxViews:         nil,
		ReactionHeart:    0,
		ReactionBookmark: 0,
		CreatedBy:        userID,
	}
}

// ---------------------------------------------------------------------------
// Tests: Create + GetByID
// ---------------------------------------------------------------------------

func TestSharedNote_CreateAndGet(t *testing.T) {
	repo := sharedNoteTestRepo(t)
	ctx := context.Background()
	userID := seedSharedNoteUser(t)

	note := makeTestSharedNote(userID, false, nil)

	// Create the shared note.
	if err := repo.Create(ctx, note); err != nil {
		t.Fatalf("Create: %v", err)
	}

	// Fetch by ID and verify fields.
	got, err := repo.GetByID(ctx, note.ID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}

	if got.ID != note.ID {
		t.Errorf("ID = %q, want %q", got.ID, note.ID)
	}
	if got.EncryptedContent != note.EncryptedContent {
		t.Errorf("EncryptedContent mismatch")
	}
	if got.EncryptedTitle != note.EncryptedTitle {
		t.Errorf("EncryptedTitle mismatch")
	}
	if got.ShareKeyHash != note.ShareKeyHash {
		t.Errorf("ShareKeyHash mismatch")
	}
	if got.HasPassword != note.HasPassword {
		t.Errorf("HasPassword = %v, want %v", got.HasPassword, note.HasPassword)
	}
	if got.IsPublic != note.IsPublic {
		t.Errorf("IsPublic = %v, want %v", got.IsPublic, note.IsPublic)
	}
	if got.CreatedBy != note.CreatedBy {
		t.Errorf("CreatedBy = %v, want %v", got.CreatedBy, note.CreatedBy)
	}
	if got.ViewCount != 0 {
		t.Errorf("ViewCount = %d, want 0", got.ViewCount)
	}
	if got.ExpiresAt != nil {
		t.Errorf("ExpiresAt should be nil, got %v", got.ExpiresAt)
	}
	if got.CreatedAt.IsZero() {
		t.Error("CreatedAt should not be zero")
	}
}

// ---------------------------------------------------------------------------
// Tests: DeleteExpired
// ---------------------------------------------------------------------------

func TestSharedNote_DeleteExpired(t *testing.T) {
	repo := sharedNoteTestRepo(t)
	ctx := context.Background()
	userID := seedSharedNoteUser(t)

	// Create an expired note (expires in the past).
	pastExpiry := time.Now().Add(-1 * time.Hour).UTC()
	expired := makeTestSharedNote(userID, true, &pastExpiry)
	if err := repo.Create(ctx, expired); err != nil {
		t.Fatalf("Create expired: %v", err)
	}

	// Create a non-expired note (no expiry).
	active := makeTestSharedNote(userID, true, nil)
	if err := repo.Create(ctx, active); err != nil {
		t.Fatalf("Create active: %v", err)
	}

	// Create another expired note.
	pastExpiry2 := time.Now().Add(-2 * time.Hour).UTC()
	expired2 := makeTestSharedNote(userID, false, &pastExpiry2)
	if err := repo.Create(ctx, expired2); err != nil {
		t.Fatalf("Create expired2: %v", err)
	}

	// Run cleanup.
	deleted, err := repo.DeleteExpired(ctx)
	if err != nil {
		t.Fatalf("DeleteExpired: %v", err)
	}
	if deleted != 2 {
		t.Errorf("DeleteExpired removed %d rows, want 2", deleted)
	}

	// The active note should still be present.
	_, err = repo.GetByID(ctx, active.ID)
	if err != nil {
		t.Fatalf("GetByID(active) after cleanup: %v", err)
	}

	// The expired notes should be gone.
	_, err = repo.GetByID(ctx, expired.ID)
	if err == nil {
		t.Error("expired note should have been deleted by DeleteExpired")
	}
}

// ---------------------------------------------------------------------------
// Tests: IncrementViewCount
// ---------------------------------------------------------------------------

func TestSharedNote_IncrementViewCount(t *testing.T) {
	repo := sharedNoteTestRepo(t)
	ctx := context.Background()
	userID := seedSharedNoteUser(t)

	note := makeTestSharedNote(userID, true, nil)
	if err := repo.Create(ctx, note); err != nil {
		t.Fatalf("Create: %v", err)
	}

	// Increment view count three times.
	for i := 0; i < 3; i++ {
		if err := repo.IncrementViewCount(ctx, note.ID); err != nil {
			t.Fatalf("IncrementViewCount[%d]: %v", i, err)
		}
	}

	// Verify count.
	got, err := repo.GetByID(ctx, note.ID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}
	if got.ViewCount != 3 {
		t.Errorf("ViewCount = %d, want 3", got.ViewCount)
	}
}

// ---------------------------------------------------------------------------
// Tests: ListPublic (Discover Feed)
// ---------------------------------------------------------------------------

func TestSharedNote_GetDiscoverFeed(t *testing.T) {
	repo := sharedNoteTestRepo(t)
	ctx := context.Background()
	userID := seedSharedNoteUser(t)

	// Create two public notes.
	public1 := makeTestSharedNote(userID, true, nil)
	if err := repo.Create(ctx, public1); err != nil {
		t.Fatalf("Create public1: %v", err)
	}

	public2 := makeTestSharedNote(userID, true, nil)
	if err := repo.Create(ctx, public2); err != nil {
		t.Fatalf("Create public2: %v", err)
	}

	// Create a private note (should not appear in feed).
	private := makeTestSharedNote(userID, false, nil)
	if err := repo.Create(ctx, private); err != nil {
		t.Fatalf("Create private: %v", err)
	}

	// Create a public note that has already expired (should not appear).
	pastExpiry := time.Now().Add(-1 * time.Hour).UTC()
	expiredPublic := makeTestSharedNote(userID, true, &pastExpiry)
	if err := repo.Create(ctx, expiredPublic); err != nil {
		t.Fatalf("Create expiredPublic: %v", err)
	}

	// Fetch the discover feed.
	items, err := repo.ListPublic(ctx, 10, 0)
	if err != nil {
		t.Fatalf("ListPublic: %v", err)
	}

	if len(items) != 2 {
		t.Fatalf("len(items) = %d, want 2 (only non-expired public notes)", len(items))
	}

	// Both items should be public notes (not private, not expired).
	foundIDs := map[string]bool{}
	for _, item := range items {
		foundIDs[item.ID] = true
		if item.ID == private.ID {
			t.Error("private note should not appear in discover feed")
		}
		if item.ID == expiredPublic.ID {
			t.Error("expired public note should not appear in discover feed")
		}
	}
	if !foundIDs[public1.ID] {
		t.Error("public1 should appear in discover feed")
	}
	if !foundIDs[public2.ID] {
		t.Error("public2 should appear in discover feed")
	}
}
