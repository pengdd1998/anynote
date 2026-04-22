//go:build integration

package repository

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/testutil"
)

// commentTestRepo returns a CommentRepository backed by the shared integration
// pool. It truncates dependent tables before each test.
func commentTestRepo(t *testing.T) CommentRepository {
	t.Helper()
	pool := ensurePool(t)
	testutil.CleanTable(t, pool,
		"note_comments",
		"note_reactions",
		"shared_notes",
		"users",
	)
	return NewCommentRepository(pool)
}

// seedCommentUser creates a test user and returns the UUID.
func seedCommentUser(t *testing.T) uuid.UUID {
	t.Helper()
	pool := ensurePool(t)
	id := uuid.New()
	email := fmt.Sprintf("cm-%s@example.com", id.String()[:8])
	username := fmt.Sprintf("cmuser_%s", id.String()[:8])
	testutil.SeedUser(t, pool, id.String(), email, username)
	return id
}

// seedSharedNote creates a shared note directly in the DB for comment tests.
// Returns the shared note ID (string).
func seedSharedNote(t *testing.T, userID uuid.UUID) string {
	t.Helper()
	pool := ensurePool(t)
	ctx := context.Background()
	id := "sn-" + uuid.New().String()[:16]
	_, err := pool.Exec(ctx,
		`INSERT INTO shared_notes (id, encrypted_content, encrypted_title, share_key_hash, has_password, is_public, created_by)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		id, "content-"+id, "title-"+id, "hash-"+id, false, true, userID,
	)
	if err != nil {
		t.Fatalf("seed shared note: %v", err)
	}
	return id
}

// ---------------------------------------------------------------------------
// Tests: Create + ListBySharedNote
// ---------------------------------------------------------------------------

func TestComment_CreateAndList(t *testing.T) {
	repo := commentTestRepo(t)
	ctx := context.Background()

	userID := seedCommentUser(t)
	noteID := seedSharedNote(t, userID)

	// Create 3 comments on the shared note.
	for i := 0; i < 3; i++ {
		req := domain.CreateCommentRequest{
			EncryptedContent: fmt.Sprintf("encrypted-comment-%d", i),
		}
		_, err := repo.Create(ctx, noteID, userID, req)
		if err != nil {
			t.Fatalf("Create[%d]: %v", i, err)
		}
	}

	// List comments.
	comments, err := repo.ListBySharedNote(ctx, noteID, 10, 0)
	if err != nil {
		t.Fatalf("ListBySharedNote: %v", err)
	}

	if len(comments) != 3 {
		t.Fatalf("len(comments) = %d, want 3", len(comments))
	}

	// Verify comments are ordered by created_at ASC.
	for i, c := range comments {
		if c.SharedNoteID != noteID {
			t.Errorf("comments[%d].SharedNoteID = %q, want %q", i, c.SharedNoteID, noteID)
		}
		if c.UserID != userID {
			t.Errorf("comments[%d].UserID mismatch", i)
		}
		if c.ParentID != nil {
			t.Errorf("comments[%d].ParentID should be nil for top-level comment", i)
		}
		if c.CreatedAt.IsZero() {
			t.Errorf("comments[%d].CreatedAt should not be zero", i)
		}
	}

	// Verify count.
	count, err := repo.CountBySharedNote(ctx, noteID)
	if err != nil {
		t.Fatalf("CountBySharedNote: %v", err)
	}
	if count != 3 {
		t.Errorf("CountBySharedNote = %d, want 3", count)
	}
}

// ---------------------------------------------------------------------------
// Tests: Reply thread (parent_id)
// ---------------------------------------------------------------------------

func TestComment_ReplyThread(t *testing.T) {
	repo := commentTestRepo(t)
	ctx := context.Background()

	userID := seedCommentUser(t)
	noteID := seedSharedNote(t, userID)

	// Create a parent comment.
	parentReq := domain.CreateCommentRequest{
		EncryptedContent: "parent-comment",
	}
	parent, err := repo.Create(ctx, noteID, userID, parentReq)
	if err != nil {
		t.Fatalf("Create parent: %v", err)
	}
	if parent.ParentID != nil {
		t.Fatal("parent comment should have nil ParentID")
	}

	// Create a reply referencing the parent.
	replyReq := domain.CreateCommentRequest{
		EncryptedContent: "reply-comment",
		ParentID:         parent.ID.String(),
	}
	reply, err := repo.Create(ctx, noteID, userID, replyReq)
	if err != nil {
		t.Fatalf("Create reply: %v", err)
	}

	// Verify reply has the correct parent_id.
	if reply.ParentID == nil {
		t.Fatal("reply should have non-nil ParentID")
	}
	if *reply.ParentID != parent.ID {
		t.Errorf("reply.ParentID = %v, want %v", *reply.ParentID, parent.ID)
	}

	// List all comments and verify both are present.
	comments, err := repo.ListBySharedNote(ctx, noteID, 10, 0)
	if err != nil {
		t.Fatalf("ListBySharedNote: %v", err)
	}
	if len(comments) != 2 {
		t.Fatalf("len(comments) = %d, want 2", len(comments))
	}

	// Verify count includes both parent and reply.
	count, err := repo.CountBySharedNote(ctx, noteID)
	if err != nil {
		t.Fatalf("CountBySharedNote: %v", err)
	}
	if count != 2 {
		t.Errorf("CountBySharedNote = %d, want 2", count)
	}
}

// ---------------------------------------------------------------------------
// Tests: Delete by user
// ---------------------------------------------------------------------------

func TestComment_DeleteByUserID(t *testing.T) {
	repo := commentTestRepo(t)
	ctx := context.Background()

	user1 := seedCommentUser(t)
	user2 := seedCommentUser(t)
	noteID := seedSharedNote(t, user1)

	// User1 creates a comment.
	c1Req := domain.CreateCommentRequest{
		EncryptedContent: "comment-by-user1",
	}
	c1, err := repo.Create(ctx, noteID, user1, c1Req)
	if err != nil {
		t.Fatalf("Create c1: %v", err)
	}

	// User2 creates a comment on the same note.
	c2Req := domain.CreateCommentRequest{
		EncryptedContent: "comment-by-user2",
	}
	c2, err := repo.Create(ctx, noteID, user2, c2Req)
	if err != nil {
		t.Fatalf("Create c2: %v", err)
	}

	// User1 deletes their own comment.
	affected, err := repo.Delete(ctx, c1.ID, user1)
	if err != nil {
		t.Fatalf("Delete c1: %v", err)
	}
	if affected != 1 {
		t.Errorf("affected = %d, want 1", affected)
	}

	// Verify user2's comment is still visible.
	comments, err := repo.ListBySharedNote(ctx, noteID, 10, 0)
	if err != nil {
		t.Fatalf("ListBySharedNote after delete: %v", err)
	}
	if len(comments) != 1 {
		t.Fatalf("len(comments) = %d, want 1 (user2's comment remains)", len(comments))
	}
	if comments[0].ID != c2.ID {
		t.Errorf("remaining comment ID = %v, want %v (user2's)", comments[0].ID, c2.ID)
	}

	// Verify count reflects only the non-deleted comment.
	count, err := repo.CountBySharedNote(ctx, noteID)
	if err != nil {
		t.Fatalf("CountBySharedNote: %v", err)
	}
	if count != 1 {
		t.Errorf("CountBySharedNote = %d, want 1", count)
	}

	// User1 cannot delete user2's comment (wrong owner).
	affected, err = repo.Delete(ctx, c2.ID, user1)
	if err != nil {
		t.Fatalf("Delete c2 by wrong user: %v", err)
	}
	if affected != 0 {
		t.Errorf("affected = %d, want 0 (user1 cannot delete user2's comment)", affected)
	}
}
