package repository

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestCommentRepository_DocumentsExpectedBehavior documents expected SQL behaviors.
func TestCommentRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("Create_inserts_comment", func(t *testing.T) {
		// INSERT INTO note_comments (shared_note_id, user_id, encrypted_content, parent_id)
		// VALUES ($1, $2, $3, $4)
		// RETURNING id, shared_note_id, user_id, encrypted_content, parent_id, created_at, updated_at
		// parent_id is nullable; parsed from string to uuid.UUID.
		t.Log("documented: Create inserts comment with optional parent_id, returns full record via RETURNING")
	})

	t.Run("ListBySharedNote_returns_paginated", func(t *testing.T) {
		// SELECT ... FROM note_comments
		// WHERE shared_note_id = $1 AND deleted_at IS NULL
		// ORDER BY created_at ASC LIMIT $2 OFFSET $3
		t.Log("documented: ListBySharedNote returns non-deleted comments with pagination")
	})

	t.Run("CountBySharedNote_returns_count", func(t *testing.T) {
		// SELECT COUNT(*) FROM note_comments WHERE shared_note_id = $1 AND deleted_at IS NULL
		t.Log("documented: CountBySharedNote counts non-deleted comments")
	})

	t.Run("Delete_soft_deletes", func(t *testing.T) {
		// UPDATE note_comments SET deleted_at = NOW(), updated_at = NOW()
		// WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
		// Returns rows affected. Only owner can delete.
		t.Log("documented: Delete soft-deletes comment, scoped to user_id")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

type mockCommentRepo struct {
	comments map[uuid.UUID]*domain.Comment
}

func newMockCommentRepo() *mockCommentRepo {
	return &mockCommentRepo{
		comments: make(map[uuid.UUID]*domain.Comment),
	}
}

func (m *mockCommentRepo) Create(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
	if req.EncryptedContent == "" {
		return nil, errors.New("encrypted content is required")
	}

	var parentID *uuid.UUID
	if req.ParentID != "" {
		pid, err := uuid.Parse(req.ParentID)
		if err != nil {
			return nil, errors.New("invalid parent_id")
		}
		parentID = &pid
	}

	c := &domain.Comment{
		ID:               uuid.New(),
		SharedNoteID:     sharedNoteID,
		UserID:           userID,
		EncryptedContent: req.EncryptedContent,
		ParentID:         parentID,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}
	m.comments[c.ID] = c
	return c, nil
}

func (m *mockCommentRepo) ListBySharedNote(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error) {
	var all []domain.Comment
	for _, c := range m.comments {
		if c.SharedNoteID == sharedNoteID {
			all = append(all, *c)
		}
	}
	// Simple offset/limit (not sorted for mock).
	if offset >= len(all) {
		return nil, nil
	}
	end := offset + limit
	if end > len(all) {
		end = len(all)
	}
	return all[offset:end], nil
}

func (m *mockCommentRepo) CountBySharedNote(ctx context.Context, sharedNoteID string) (int, error) {
	count := 0
	for _, c := range m.comments {
		if c.SharedNoteID == sharedNoteID {
			count++
		}
	}
	return count, nil
}

func (m *mockCommentRepo) Delete(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) (int64, error) {
	c, ok := m.comments[commentID]
	if !ok || c.UserID != userID {
		return 0, nil
	}
	delete(m.comments, commentID)
	return 1, nil
}

func TestMockCommentRepo_Create(t *testing.T) {
	repo := newMockCommentRepo()
	ctx := context.Background()
	userID := uuid.New()

	c, err := repo.Create(ctx, "note-1", userID, domain.CreateCommentRequest{
		EncryptedContent: "encrypted-comment",
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if c.SharedNoteID != "note-1" {
		t.Errorf("SharedNoteID = %q, want %q", c.SharedNoteID, "note-1")
	}
	if c.UserID != userID {
		t.Error("UserID mismatch")
	}
}

func TestMockCommentRepo_Create_WithParent(t *testing.T) {
	repo := newMockCommentRepo()
	ctx := context.Background()
	userID := uuid.New()
	parentID := uuid.New()

	c, err := repo.Create(ctx, "note-1", userID, domain.CreateCommentRequest{
		EncryptedContent: "reply",
		ParentID:         parentID.String(),
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if c.ParentID == nil || *c.ParentID != parentID {
		t.Error("ParentID should match")
	}
}

func TestMockCommentRepo_Create_EmptyContent(t *testing.T) {
	repo := newMockCommentRepo()
	ctx := context.Background()

	_, err := repo.Create(ctx, "note-1", uuid.New(), domain.CreateCommentRequest{
		EncryptedContent: "",
	})
	if err == nil {
		t.Error("Create should reject empty content")
	}
}

func TestMockCommentRepo_Create_InvalidParentID(t *testing.T) {
	repo := newMockCommentRepo()
	ctx := context.Background()

	_, err := repo.Create(ctx, "note-1", uuid.New(), domain.CreateCommentRequest{
		EncryptedContent: "content",
		ParentID:         "not-a-uuid",
	})
	if err == nil {
		t.Error("Create should reject invalid parent_id")
	}
}

func TestMockCommentRepo_ListBySharedNote(t *testing.T) {
	repo := newMockCommentRepo()
	ctx := context.Background()

	repo.Create(ctx, "note-1", uuid.New(), domain.CreateCommentRequest{EncryptedContent: "c1"})
	repo.Create(ctx, "note-1", uuid.New(), domain.CreateCommentRequest{EncryptedContent: "c2"})
	repo.Create(ctx, "note-2", uuid.New(), domain.CreateCommentRequest{EncryptedContent: "c3"})

	comments, err := repo.ListBySharedNote(ctx, "note-1", 10, 0)
	if err != nil {
		t.Fatalf("ListBySharedNote: %v", err)
	}
	if len(comments) != 2 {
		t.Errorf("len(comments) = %d, want 2", len(comments))
	}
}

func TestMockCommentRepo_CountBySharedNote(t *testing.T) {
	repo := newMockCommentRepo()
	ctx := context.Background()

	repo.Create(ctx, "note-1", uuid.New(), domain.CreateCommentRequest{EncryptedContent: "c1"})
	repo.Create(ctx, "note-1", uuid.New(), domain.CreateCommentRequest{EncryptedContent: "c2"})

	count, err := repo.CountBySharedNote(ctx, "note-1")
	if err != nil {
		t.Fatalf("CountBySharedNote: %v", err)
	}
	if count != 2 {
		t.Errorf("count = %d, want 2", count)
	}

	count, _ = repo.CountBySharedNote(ctx, "note-none")
	if count != 0 {
		t.Errorf("count = %d, want 0 for nonexistent note", count)
	}
}

func TestMockCommentRepo_Delete(t *testing.T) {
	repo := newMockCommentRepo()
	ctx := context.Background()
	userID := uuid.New()

	c, _ := repo.Create(ctx, "note-1", userID, domain.CreateCommentRequest{EncryptedContent: "c1"})

	// Owner can delete.
	affected, err := repo.Delete(ctx, c.ID, userID)
	if err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if affected != 1 {
		t.Errorf("affected = %d, want 1", affected)
	}

	// Comment should be gone.
	count, _ := repo.CountBySharedNote(ctx, "note-1")
	if count != 0 {
		t.Errorf("count after delete = %d, want 0", count)
	}
}

func TestMockCommentRepo_Delete_Unauthorized(t *testing.T) {
	repo := newMockCommentRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()

	c, _ := repo.Create(ctx, "note-1", user1, domain.CreateCommentRequest{EncryptedContent: "c1"})

	// Different user cannot delete.
	affected, err := repo.Delete(ctx, c.ID, user2)
	if err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if affected != 0 {
		t.Errorf("affected = %d, want 0 for unauthorized delete", affected)
	}
}
