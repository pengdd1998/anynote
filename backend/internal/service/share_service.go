package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

var (
	ErrShareNotFound    = errors.New("share not found")
	ErrShareExpired     = errors.New("share has expired")
	ErrShareMaxViews    = errors.New("share has reached maximum views")
	ErrInvalidReaction  = errors.New("invalid reaction type")
)

// SharedNoteRepository defines the persistence operations for shared notes.
type SharedNoteRepository interface {
	Create(ctx context.Context, note *domain.SharedNote) error
	GetByID(ctx context.Context, id string) (*domain.SharedNote, error)
	IncrementViewCount(ctx context.Context, id string) error
	DeleteExpired(ctx context.Context) (int64, error)
	ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.SharedNote, error)
	ListPublic(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error)
	React(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error)
	GetUserReaction(ctx context.Context, sharedNoteID string, userID uuid.UUID) (map[string]bool, error)
}

// ShareService handles shared note operations.
type ShareService interface {
	CreateShare(ctx context.Context, userID uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error)
	GetShare(ctx context.Context, id string) (*domain.GetShareResponse, error)
	DiscoverFeed(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error)
	ToggleReaction(ctx context.Context, userID uuid.UUID, shareID string, reactionType string) (*domain.ReactResponse, error)
}

type shareService struct {
	shareRepo SharedNoteRepository
}

// NewShareService creates a new share service.
func NewShareService(shareRepo SharedNoteRepository) ShareService {
	return &shareService{shareRepo: shareRepo}
}

func (s *shareService) CreateShare(ctx context.Context, userID uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
	// Generate a random share ID (16 bytes = 32 hex chars).
	shareID, err := generateShareID()
	if err != nil {
		return nil, err
	}

	var expiresAt *time.Time
	if req.ExpiresHours != nil && *req.ExpiresHours > 0 {
		t := time.Now().UTC().Add(time.Duration(*req.ExpiresHours) * time.Hour)
		expiresAt = &t
	}

	isPublic := false
	if req.IsPublic != nil {
		isPublic = *req.IsPublic
	}

	note := &domain.SharedNote{
		ID:               shareID,
		EncryptedContent: req.EncryptedContent,
		EncryptedTitle:   req.EncryptedTitle,
		ShareKeyHash:     req.ShareKeyHash,
		HasPassword:      req.HasPassword,
		IsPublic:         isPublic,
		ExpiresAt:        expiresAt,
		MaxViews:         req.MaxViews,
		CreatedBy:        userID,
	}

	if err := s.shareRepo.Create(ctx, note); err != nil {
		return nil, err
	}

	return &domain.CreateShareResponse{
		ID:  shareID,
		URL: "/share/" + shareID,
	}, nil
}

func (s *shareService) GetShare(ctx context.Context, id string) (*domain.GetShareResponse, error) {
	note, err := s.shareRepo.GetByID(ctx, id)
	if err != nil {
		return nil, ErrShareNotFound
	}

	// Check if expired.
	if note.ExpiresAt != nil && note.ExpiresAt.Before(time.Now().UTC()) {
		return nil, ErrShareExpired
	}

	// Check max views.
	if note.MaxViews != nil && note.ViewCount >= *note.MaxViews {
		return nil, ErrShareMaxViews
	}

	// Increment view count (best effort, do not fail the request).
	_ = s.shareRepo.IncrementViewCount(ctx, id)

	return &domain.GetShareResponse{
		ID:               note.ID,
		EncryptedContent: note.EncryptedContent,
		EncryptedTitle:   note.EncryptedTitle,
		HasPassword:      note.HasPassword,
		ExpiresAt:        note.ExpiresAt,
		ViewCount:        note.ViewCount + 1,
		MaxViews:         note.MaxViews,
	}, nil
}

// DiscoverFeed returns public shared notes for the discovery feed.
func (s *shareService) DiscoverFeed(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	return s.shareRepo.ListPublic(ctx, limit, offset)
}

// ToggleReaction toggles a heart or bookmark reaction on a shared note.
func (s *shareService) ToggleReaction(ctx context.Context, userID uuid.UUID, shareID string, reactionType string) (*domain.ReactResponse, error) {
	if reactionType != "heart" && reactionType != "bookmark" {
		return nil, ErrInvalidReaction
	}

	// Verify the shared note exists.
	_, err := s.shareRepo.GetByID(ctx, shareID)
	if err != nil {
		return nil, ErrShareNotFound
	}

	return s.shareRepo.React(ctx, shareID, userID, reactionType)
}

// generateShareID creates a cryptographically random 32-character hex string.
func generateShareID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
