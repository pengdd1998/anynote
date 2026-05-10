package service

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/llm"
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
	IsValidPlatform(name string) bool
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
	logRepo        PublishLogRepository
	queue          QueueEnqueuer
	pushSvc        PushService // optional; nil means no push notifications
	masterKey      []byte      // server master key for encrypting publish content at rest
	validPlatforms map[string]struct{} // set of registered platform names
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

// WithPublishMasterKey sets the server master key for encrypting publish
// content at rest.
func WithPublishMasterKey(key []byte) PublishServiceOption {
	return func(s *publishService) { s.masterKey = key }
}

// WithValidPlatforms sets the set of allowed platform names for publish
// requests. Names are normalized to lowercase.
func WithValidPlatforms(names []string) PublishServiceOption {
	m := make(map[string]struct{}, len(names))
	for _, n := range names {
		m[n] = struct{}{}
	}
	return func(s *publishService) { s.validPlatforms = m }
}

// encryptField encrypts a string with AES-256-GCM and returns base64.
// Returns the plaintext unchanged if masterKey is nil or input is empty.
func (s *publishService) encryptField(plaintext string) (string, error) {
	if plaintext == "" || len(s.masterKey) == 0 {
		return plaintext, nil
	}
	ciphertext, err := llm.EncryptAPIKey(plaintext, s.masterKey)
	if err != nil {
		return "", fmt.Errorf("encrypt publish field: %w", err)
	}
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// decryptField decrypts a base64-encoded AES-256-GCM ciphertext.
// Returns the input unchanged if masterKey is nil, or if the input is not
// valid base64 (legacy plaintext data from before encryption was added).
func (s *publishService) decryptField(encoded string) (string, error) {
	if encoded == "" || len(s.masterKey) == 0 {
		return encoded, nil
	}
	ciphertext, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		// Not base64 -- assume legacy plaintext data.
		return encoded, nil
	}
	plaintext, err := llm.DecryptAPIKey(ciphertext, s.masterKey)
	if err != nil {
		return "", fmt.Errorf("decrypt publish field: %w", err)
	}
	return plaintext, nil
}

func (s *publishService) Publish(ctx context.Context, userID uuid.UUID, req PublishRequest) (*domain.PublishLog, error) {
	encTitle, err := s.encryptField(req.Title)
	if err != nil {
		return nil, err
	}
	encContent, err := s.encryptField(req.Content)
	if err != nil {
		return nil, err
	}

	log := &domain.PublishLog{
		ID:       uuid.New(),
		UserID:   userID,
		Platform: req.Platform,
		Title:    encTitle,
		Content:  encContent,
		Status:   "pending",
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
			"title":          encTitle,
			"content":        encContent,
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
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			payload := PushPayload{
				Title:    "Publishing Started",
				Body:     fmt.Sprintf("Publishing to %s", req.Platform),
				Priority: "normal",
				Data: map[string]interface{}{
					"type":           "publish_started",
					"platform":       req.Platform,
					"publish_log_id": log.ID.String(),
				},
			}
			if err := s.pushSvc.SendPush(ctx, userID.String(), payload); err != nil {
				slog.Error("failed to send publish push", "user_id", userID.String(), "error", err)
			}
		}()
	}

	return log, nil
}

func (s *publishService) GetHistory(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	logs, err := s.logRepo.ListByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	for i := range logs {
		logs[i].Title, err = s.decryptField(logs[i].Title)
		if err != nil {
			return nil, err
		}
		logs[i].Content, err = s.decryptField(logs[i].Content)
		if err != nil {
			return nil, err
		}
	}
	return logs, nil
}

func (s *publishService) GetByID(ctx context.Context, userID uuid.UUID, id uuid.UUID) (*domain.PublishLog, error) {
	publishLog, err := s.logRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if publishLog.UserID != userID {
		return nil, ErrNotOwner
	}
	// Decrypt content for the caller.
	publishLog.Title, err = s.decryptField(publishLog.Title)
	if err != nil {
		return nil, err
	}
	publishLog.Content, err = s.decryptField(publishLog.Content)
	if err != nil {
		return nil, err
	}
	return publishLog, nil
}

// IsValidPlatform returns true if the given platform name is in the registered
// set. When no valid platforms are configured (validPlatforms is nil), all
// non-empty names are accepted for backward compatibility.
func (s *publishService) IsValidPlatform(name string) bool {
	if name == "" {
		return false
	}
	if len(s.validPlatforms) == 0 {
		return true
	}
	_, ok := s.validPlatforms[name]
	return ok
}
