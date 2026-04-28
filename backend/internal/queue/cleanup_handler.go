package queue

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/hibiken/asynq"

	"github.com/anynote/backend/internal/repository"
)

// CleanupHandler processes periodic cleanup tasks (e.g., expired shared notes).
type CleanupHandler struct {
	sharedNoteRepo *repository.SharedNoteRepository
}

// NewCleanupHandler creates a new CleanupHandler.
func NewCleanupHandler(sharedNoteRepo *repository.SharedNoteRepository) *CleanupHandler {
	return &CleanupHandler{sharedNoteRepo: sharedNoteRepo}
}

// HandleCleanupExpiredShares deletes shared_notes rows where expires_at < NOW().
// Implements asynq.Handler for use with the task queue scheduler.
func (h *CleanupHandler) HandleCleanupExpiredShares(ctx context.Context, _ *asynq.Task) error {
	n, err := h.sharedNoteRepo.DeleteExpired(ctx)
	if err != nil {
		return fmt.Errorf("cleanup expired shares: %w", err)
	}
	if n > 0 {
		slog.Info("cleaned up expired shared notes", "deleted", n)
	}
	return nil
}
