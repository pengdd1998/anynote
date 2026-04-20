package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

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
	shareRepo   SharedNoteRepository // optional; nil means no owner lookups
	pushSvc     PushService          // optional; nil means no push notifications
}

// CommentServiceOption configures a commentService during construction.
type CommentServiceOption func(*commentService)

// WithCommentPushService sets the push notification service for comment events.
func WithCommentPushService(pushSvc PushService) CommentServiceOption {
	return func(s *commentService) { s.pushSvc = pushSvc }
}

// WithCommentShareRepo sets the shared note repository for owner lookups.
func WithCommentShareRepo(shareRepo SharedNoteRepository) CommentServiceOption {
	return func(s *commentService) { s.shareRepo = shareRepo }
}

// NewCommentService creates a new comment service.
func NewCommentService(commentRepo CommentRepository, opts ...CommentServiceOption) CommentService {
	svc := &commentService{commentRepo: commentRepo}
	for _, opt := range opts {
		opt(svc)
	}
	return svc
}

func (s *commentService) CreateComment(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
	comment, err := s.commentRepo.Create(ctx, sharedNoteID, userID, req)
	if err != nil {
		return nil, fmt.Errorf("create comment: %w", err)
	}

	// Notify the note owner about the new comment (async, best-effort).
	s.notifyNoteOwner(context.Background(), sharedNoteID, userID, comment.ID.String())

	return comment, nil
}

// notifyNoteOwner looks up the shared note owner and sends a push notification
// if the commenter is not the owner. Errors are logged but never propagated.
func (s *commentService) notifyNoteOwner(ctx context.Context, sharedNoteID string, commenterID uuid.UUID, commentID string) {
	if s.pushSvc == nil || s.shareRepo == nil {
		return
	}

	note, err := s.shareRepo.GetByID(ctx, sharedNoteID)
	if err != nil {
		slog.Error("comment push: failed to look up shared note owner",
			"shared_note_id", sharedNoteID,
			"error", err,
		)
		return
	}

	ownerID := note.CreatedBy

	// Do not self-notify: skip if the commenter is the note owner.
	if commenterID == ownerID {
		return
	}

	payload := PushPayload{
		Title:    "New Comment",
		Body:     "Someone commented on your shared note",
		Priority: "normal",
		Data: map[string]interface{}{
			"type":           "new_comment",
			"shared_note_id": sharedNoteID,
			"comment_id":     commentID,
		},
	}

	if err := s.pushSvc.SendPush(ctx, ownerID.String(), payload); err != nil {
		slog.Error("comment push: failed to send push notification",
			"owner_id", ownerID.String(),
			"shared_note_id", sharedNoteID,
			"error", err,
		)
	}
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
