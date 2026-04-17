package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

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
}

func NewPublishService(logRepo PublishLogRepository) PublishService {
	return &publishService{logRepo: logRepo}
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

	// In production, enqueue via asynq for async processing
	// For now, return the log entry (actual publishing happens in worker)

	return log, nil
}

func (s *publishService) GetHistory(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	return s.logRepo.ListByUser(ctx, userID)
}

func (s *publishService) GetByID(ctx context.Context, userID uuid.UUID, id uuid.UUID) (*domain.PublishLog, error) {
	log, err := s.logRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if log.UserID != userID {
		return nil, ErrUserNotFound
	}
	return log, nil
}
