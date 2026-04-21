package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ErrNotOwner is returned when a user attempts to access a resource
// that belongs to a different user.
var ErrNotOwner = errors.New("resource not owned by requesting user")

// QueueEnqueuer abstracts the queue enqueue operation so publish_service
// does not depend directly on the queue package.
type QueueEnqueuer interface {
	EnqueuePublishJob(ctx context.Context, userID string, platform string, payload interface{}) (string, error)
}

type PublishService interface {
	Publish(ctx context.Context, userID uuid.UUID, req PublishRequest) (*domain.PublishLog, error)
	GetHistory(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error)
	GetByID(ctx context.Context, userID uuid.UUID, id uuid.UUID) (*domain.PublishLog, error)
}

type PublishRequest struct {
	Platform      string   `json:"platform"`
	ContentItemID string   `json:"content_item_id"`
	Title         string   `json:"title"`
	Content       string   `json:"content"`
	Tags          []string `json:"tags"`
}

type PublishLogRepository interface {
	Create(ctx context.Context, log *domain.PublishLog) error
	GetByID(ctx context.Context, id uuid.UUID) (*domain.PublishLog, error)
	ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error)
	UpdateStatus(ctx context.Context, id uuid.UUID, status string, errMsg string, platformURL string) error
}

type publishService struct {
	logRepo PublishLogRepository
	queue   QueueEnqueuer
	pushSvc PushService // optional; nil means no push notifications
}

// NewPublishService creates a publish service with the given log repository.
// The queue parameter is optional; if nil, jobs are not enqueued (useful for
// tests or server-mode where only the worker handles publishing).
func NewPublishService(logRepo PublishLogRepository, queue QueueEnqueuer, opts ...PublishServiceOption) PublishService {
	svc := &publishService{
		logRepo: logRepo,
		queue:   queue,
	}
	for _, opt := range opts {
		opt(svc)
	}
	return svc
}

// PublishServiceOption configures a publishService during construction.
type PublishServiceOption func(*publishService)

// WithPublishPushService sets the push notification service for publish events.
func WithPublishPushService(pushSvc PushService) PublishServiceOption {
	return func(s *publishService) { s.pushSvc = pushSvc }
}

func (s *publishService) Publish(ctx context.Context, userID uuid.UUID, req PublishRequest) (*domain.PublishLog, error) {
	log := &domain.PublishLog{
		ID:      uuid.New(),
		UserID:  userID,
		Platform: req.Platform,
		Title:   req.Title,
		Content: req.Content,
		Status:  "pending",
	}

	if err := s.logRepo.Create(ctx, log); err != nil {
		return nil, err
	}

	// Enqueue the publish job for async processing by the worker.
	if s.queue != nil {
		payload := map[string]interface{}{
			"user_id":        userID.String(),
			"platform":       req.Platform,
			"publish_log_id": log.ID.String(),
			"title":          req.Title,
			"content":        req.Content,
			"tags":           req.Tags,
		}

		jobID, err := s.queue.EnqueuePublishJob(ctx, userID.String(), req.Platform, payload)
		if err != nil {
			// Update status to failed if enqueue fails.
			if updateErr := s.logRepo.UpdateStatus(ctx, log.ID, "failed", fmt.Sprintf("failed to enqueue: %v", err), ""); updateErr != nil {
				slog.Error("publish: failed to update status after enqueue failure", "publish_log_id", log.ID.String(), "error", updateErr)
			}
			return nil, fmt.Errorf("enqueue publish job: %w", err)
		}

		slog.Info("publish job enqueued", "publish_log_id", log.ID.String(), "job_id", jobID)
	}

	// Trigger push notification for publish start.
	// In production, a second push would fire when the worker completes.
	if s.pushSvc != nil {
		go func() {
			payload := PushPayload{
				Title:    "Publishing Started",
				Body:     fmt.Sprintf("Publishing to %s: %s", req.Platform, req.Title),
				Priority: "normal",
				Data: map[string]interface{}{
					"type":           "publish_started",
					"platform":       req.Platform,
					"publish_log_id": log.ID.String(),
				},
			}
			if err := s.pushSvc.SendPush(context.Background(), userID.String(), payload); err != nil {
				slog.Error("failed to send publish push", "user_id", userID.String(), "error", err)
			}
		}()
	}

	return log, nil
}

func (s *publishService) GetHistory(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	return s.logRepo.ListByUser(ctx, userID)
}

func (s *publishService) GetByID(ctx context.Context, userID uuid.UUID, id uuid.UUID) (*domain.PublishLog, error) {
	publishLog, err := s.logRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if publishLog.UserID != userID {
		return nil, ErrNotOwner
	}
	return publishLog, nil
}
