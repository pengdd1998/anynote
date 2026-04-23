package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// NoteLinkService manages note link operations.
type NoteLinkService interface {
	CreateLinks(ctx context.Context, userID uuid.UUID, links []domain.NoteLinkItem) ([]domain.NoteLink, error)
	GetBacklinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error)
	GetOutboundLinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error)
	GetGraph(ctx context.Context, userID uuid.UUID) (*domain.NoteGraphResponse, error)
	DeleteLink(ctx context.Context, userID uuid.UUID, sourceID uuid.UUID, targetID uuid.UUID) error
}

// NoteLinkRepository defines the data access interface for note links.
type NoteLinkRepository interface {
	CreateLinks(ctx context.Context, userID uuid.UUID, links []domain.NoteLinkItem) ([]domain.NoteLink, error)
	GetBacklinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error)
	GetOutboundLinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error)
	GetGraph(ctx context.Context, userID uuid.UUID) (*domain.NoteGraphResponse, error)
	DeleteLink(ctx context.Context, userID uuid.UUID, sourceID uuid.UUID, targetID uuid.UUID) error
}

type noteLinkService struct {
	repo NoteLinkRepository
}

// NewNoteLinkService creates a new NoteLinkService.
func NewNoteLinkService(repo NoteLinkRepository) NoteLinkService {
	return &noteLinkService{repo: repo}
}

func (s *noteLinkService) CreateLinks(ctx context.Context, userID uuid.UUID, links []domain.NoteLinkItem) ([]domain.NoteLink, error) {
	return s.repo.CreateLinks(ctx, userID, links)
}

func (s *noteLinkService) GetBacklinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error) {
	return s.repo.GetBacklinks(ctx, userID, noteID)
}

func (s *noteLinkService) GetOutboundLinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error) {
	return s.repo.GetOutboundLinks(ctx, userID, noteID)
}

func (s *noteLinkService) GetGraph(ctx context.Context, userID uuid.UUID) (*domain.NoteGraphResponse, error) {
	return s.repo.GetGraph(ctx, userID)
}

func (s *noteLinkService) DeleteLink(ctx context.Context, userID uuid.UUID, sourceID uuid.UUID, targetID uuid.UUID) error {
	return s.repo.DeleteLink(ctx, userID, sourceID, targetID)
}
