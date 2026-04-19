package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

// CommentRepository interface defines persistence operations for note comments.
type CommentRepository interface {
	Create(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error)
	ListBySharedNote(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error)
	CountBySharedNote(ctx context.Context, sharedNoteID string) (int, error)
	Delete(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) (int64, error)
}

type commentRepository struct {
	pool *pgxpool.Pool
}

// NewCommentRepository creates a new comment repository backed by pgxpool.
func NewCommentRepository(pool *pgxpool.Pool) CommentRepository {
	return &commentRepository{pool: pool}
}

func (r *commentRepository) Create(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
	var parentID *uuid.UUID
	if req.ParentID != "" {
		pid, err := uuid.Parse(req.ParentID)
		if err != nil {
			return nil, fmt.Errorf("invalid parent_id: %w", err)
		}
		parentID = &pid
	}

	var c domain.Comment
	err := r.pool.QueryRow(ctx,
		`INSERT INTO note_comments (shared_note_id, user_id, encrypted_content, parent_id)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, shared_note_id, user_id, encrypted_content, parent_id, created_at, updated_at`,
		sharedNoteID, userID, req.EncryptedContent, parentID,
	).Scan(&c.ID, &c.SharedNoteID, &c.UserID, &c.EncryptedContent, &c.ParentID, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert comment: %w", err)
	}
	return &c, nil
}

func (r *commentRepository) ListBySharedNote(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, shared_note_id, user_id, encrypted_content, parent_id, created_at, updated_at
		 FROM note_comments
		 WHERE shared_note_id = $1 AND deleted_at IS NULL
		 ORDER BY created_at ASC
		 LIMIT $2 OFFSET $3`,
		sharedNoteID, limit, offset,
	)
	if err != nil {
		return nil, fmt.Errorf("list comments: %w", err)
	}
	defer rows.Close()

	var comments []domain.Comment
	for rows.Next() {
		var c domain.Comment
		if err := rows.Scan(&c.ID, &c.SharedNoteID, &c.UserID, &c.EncryptedContent, &c.ParentID, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan comment: %w", err)
		}
		comments = append(comments, c)
	}
	return comments, rows.Err()
}

func (r *commentRepository) CountBySharedNote(ctx context.Context, sharedNoteID string) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM note_comments WHERE shared_note_id = $1 AND deleted_at IS NULL`,
		sharedNoteID,
	).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count comments: %w", err)
	}
	return count, nil
}

func (r *commentRepository) Delete(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) (int64, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE note_comments SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
		commentID, userID,
	)
	if err != nil {
		return 0, fmt.Errorf("delete comment: %w", err)
	}
	return tag.RowsAffected(), nil
}
