package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

var (
	ErrCommentNotFound  = errors.New("comment not found")
	ErrNotCommentAuthor = errors.New("not the comment author")
)

// CommentRepository defines the persistence operations for comments.
type CommentRepository interface {
	Create(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error)
	ListBySharedNote(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error)
	CountBySharedNote(ctx context.Context, sharedNoteID string) (int, error)
	Delete(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) (int64, error)
}

// CommentService handles comment operations on shared notes.
type CommentService interface {
	CreateComment(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error)
	ListComments(ctx context.Context, sharedNoteID string, limit, offset int) (*domain.ListCommentsResponse, error)
	DeleteComment(ctx context.Context, commentID, userID uuid.UUID) error
}

type commentService struct {
	commentRepo CommentRepository
}

// NewCommentService creates a new comment service.
func NewCommentService(commentRepo CommentRepository) CommentService {
	return &commentService{commentRepo: commentRepo}
}

func (s *commentService) CreateComment(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
	comment, err := s.commentRepo.Create(ctx, sharedNoteID, userID, req)
	if err != nil {
		return nil, fmt.Errorf("create comment: %w", err)
	}
	return comment, nil
}

func (s *commentService) ListComments(ctx context.Context, sharedNoteID string, limit, offset int) (*domain.ListCommentsResponse, error) {
	comments, err := s.commentRepo.ListBySharedNote(ctx, sharedNoteID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list comments: %w", err)
	}

	total, err := s.commentRepo.CountBySharedNote(ctx, sharedNoteID)
	if err != nil {
		return nil, fmt.Errorf("count comments: %w", err)
	}

	if comments == nil {
		comments = []domain.Comment{}
	}

	return &domain.ListCommentsResponse{
		Comments: comments,
		Total:    total,
	}, nil
}

func (s *commentService) DeleteComment(ctx context.Context, commentID, userID uuid.UUID) error {
	rowsAffected, err := s.commentRepo.Delete(ctx, commentID, userID)
	if err != nil {
		return fmt.Errorf("delete comment: %w", err)
	}

	if rowsAffected == 0 {
		return ErrNotCommentAuthor
	}

	return nil
}
