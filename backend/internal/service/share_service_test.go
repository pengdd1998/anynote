package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock SharedNoteRepository
// ---------------------------------------------------------------------------

type mockSharedNoteRepo struct {
	createFn       func(ctx context.Context, note *domain.SharedNote) error
	getByIDFn      func(ctx context.Context, id string) (*domain.SharedNote, error)
	incrementViewFn func(ctx context.Context, id string) error
	deleteExpiredFn func(ctx context.Context) (int64, error)
	listByUserFn   func(ctx context.Context, userID uuid.UUID) ([]domain.SharedNote, error)
	listPublicFn   func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error)
	reactFn        func(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error)
	getUserReactFn func(ctx context.Context, sharedNoteID string, userID uuid.UUID) (map[string]bool, error)
}

func (m *mockSharedNoteRepo) Create(ctx context.Context, note *domain.SharedNote) error {
	if m.createFn != nil {
		return m.createFn(ctx, note)
	}
	return nil
}

func (m *mockSharedNoteRepo) GetByID(ctx context.Context, id string) (*domain.SharedNote, error) {
	if m.getByIDFn != nil {
		return m.getByIDFn(ctx, id)
	}
	return nil, errors.New("not found")
}

func (m *mockSharedNoteRepo) IncrementViewCount(ctx context.Context, id string) error {
	if m.incrementViewFn != nil {
		return m.incrementViewFn(ctx, id)
	}
	return nil
}

func (m *mockSharedNoteRepo) DeleteExpired(ctx context.Context) (int64, error) {
	if m.deleteExpiredFn != nil {
		return m.deleteExpiredFn(ctx)
	}
	return 0, nil
}

func (m *mockSharedNoteRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.SharedNote, error) {
	if m.listByUserFn != nil {
		return m.listByUserFn(ctx, userID)
	}
	return nil, nil
}

func (m *mockSharedNoteRepo) ListPublic(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
	if m.listPublicFn != nil {
		return m.listPublicFn(ctx, limit, offset)
	}
	return nil, nil
}

func (m *mockSharedNoteRepo) React(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error) {
	if m.reactFn != nil {
		return m.reactFn(ctx, sharedNoteID, userID, reactionType)
	}
	return nil, nil
}

func (m *mockSharedNoteRepo) GetUserReaction(ctx context.Context, sharedNoteID string, userID uuid.UUID) (map[string]bool, error) {
	if m.getUserReactFn != nil {
		return m.getUserReactFn(ctx, sharedNoteID, userID)
	}
	return map[string]bool{}, nil
}

// ---------------------------------------------------------------------------
// Tests: CreateShare
// ---------------------------------------------------------------------------

func TestShareService_CreateShare_Success(t *testing.T) {
	repo := &mockSharedNoteRepo{
		createFn: func(ctx context.Context, note *domain.SharedNote) error {
			if note.ID == "" {
				t.Error("share ID should not be empty")
			}
			if len(note.ID) != 32 {
				t.Errorf("share ID length = %d, want 32 hex chars", len(note.ID))
			}
			if note.EncryptedContent != "enc-content" {
				t.Errorf("EncryptedContent = %q, want %q", note.EncryptedContent, "enc-content")
			}
			if note.CreatedBy == uuid.Nil {
				t.Error("CreatedBy should not be nil UUID")
			}
			return nil
		},
	}

	svc := NewShareService(repo)
	userID := uuid.New()

	resp, err := svc.CreateShare(context.Background(), userID, domain.CreateShareRequest{
		EncryptedContent: "enc-content",
		EncryptedTitle:   "enc-title",
		ShareKeyHash:     "hash123",
	})
	if err != nil {
		t.Fatalf("CreateShare: %v", err)
	}
	if resp.ID == "" {
		t.Error("response ID should not be empty")
	}
	if resp.URL != "/share/"+resp.ID {
		t.Errorf("URL = %q, want /share/%s", resp.URL, resp.ID)
	}
}

func TestShareService_CreateShare_WithExpiry(t *testing.T) {
	var capturedNote *domain.SharedNote
	repo := &mockSharedNoteRepo{
		createFn: func(ctx context.Context, note *domain.SharedNote) error {
			capturedNote = note
			return nil
		},
	}

	svc := NewShareService(repo)
	hours := 24

	resp, err := svc.CreateShare(context.Background(), uuid.New(), domain.CreateShareRequest{
		EncryptedContent: "enc-content",
		EncryptedTitle:   "enc-title",
		ShareKeyHash:     "hash123",
		ExpiresHours:     &hours,
	})
	if err != nil {
		t.Fatalf("CreateShare: %v", err)
	}
	if resp == nil {
		t.Fatal("response should not be nil")
	}
	if capturedNote.ExpiresAt == nil {
		t.Fatal("ExpiresAt should be set when ExpiresHours is provided")
	}
	// The expiry should be roughly 24 hours from now.
	diff := time.Until(*capturedNote.ExpiresAt)
	if diff < 23*time.Hour || diff > 25*time.Hour {
		t.Errorf("ExpiresAt diff = %v, want ~24h", diff)
	}
}

func TestShareService_CreateShare_WithMaxViews(t *testing.T) {
	var capturedNote *domain.SharedNote
	repo := &mockSharedNoteRepo{
		createFn: func(ctx context.Context, note *domain.SharedNote) error {
			capturedNote = note
			return nil
		},
	}

	svc := NewShareService(repo)
	maxViews := 10

	_, err := svc.CreateShare(context.Background(), uuid.New(), domain.CreateShareRequest{
		EncryptedContent: "enc-content",
		EncryptedTitle:   "enc-title",
		ShareKeyHash:     "hash123",
		MaxViews:         &maxViews,
	})
	if err != nil {
		t.Fatalf("CreateShare: %v", err)
	}
	if capturedNote.MaxViews == nil {
		t.Fatal("MaxViews should be set")
	}
	if *capturedNote.MaxViews != 10 {
		t.Errorf("MaxViews = %d, want 10", *capturedNote.MaxViews)
	}
}

func TestShareService_CreateShare_WithIsPublic(t *testing.T) {
	var capturedNote *domain.SharedNote
	repo := &mockSharedNoteRepo{
		createFn: func(ctx context.Context, note *domain.SharedNote) error {
			capturedNote = note
			return nil
		},
	}

	svc := NewShareService(repo)
	isPublic := true

	_, err := svc.CreateShare(context.Background(), uuid.New(), domain.CreateShareRequest{
		EncryptedContent: "enc-content",
		EncryptedTitle:   "enc-title",
		ShareKeyHash:     "hash123",
		IsPublic:         &isPublic,
	})
	if err != nil {
		t.Fatalf("CreateShare: %v", err)
	}
	if !capturedNote.IsPublic {
		t.Error("IsPublic should be true")
	}
}

func TestShareService_CreateShare_DefaultIsNotPublic(t *testing.T) {
	var capturedNote *domain.SharedNote
	repo := &mockSharedNoteRepo{
		createFn: func(ctx context.Context, note *domain.SharedNote) error {
			capturedNote = note
			return nil
		},
	}

	svc := NewShareService(repo)

	_, err := svc.CreateShare(context.Background(), uuid.New(), domain.CreateShareRequest{
		EncryptedContent: "enc-content",
		EncryptedTitle:   "enc-title",
		ShareKeyHash:     "hash123",
	})
	if err != nil {
		t.Fatalf("CreateShare: %v", err)
	}
	if capturedNote.IsPublic {
		t.Error("IsPublic should default to false")
	}
}

func TestShareService_CreateShare_ZeroExpiresHours_NoExpiry(t *testing.T) {
	var capturedNote *domain.SharedNote
	repo := &mockSharedNoteRepo{
		createFn: func(ctx context.Context, note *domain.SharedNote) error {
			capturedNote = note
			return nil
		},
	}

	svc := NewShareService(repo)
	hours := 0

	_, err := svc.CreateShare(context.Background(), uuid.New(), domain.CreateShareRequest{
		EncryptedContent: "enc-content",
		EncryptedTitle:   "enc-title",
		ShareKeyHash:     "hash123",
		ExpiresHours:     &hours,
	})
	if err != nil {
		t.Fatalf("CreateShare: %v", err)
	}
	if capturedNote.ExpiresAt != nil {
		t.Error("ExpiresAt should be nil when ExpiresHours is 0")
	}
}

func TestShareService_CreateShare_RepoError(t *testing.T) {
	repo := &mockSharedNoteRepo{
		createFn: func(ctx context.Context, note *domain.SharedNote) error {
			return errors.New("db connection lost")
		},
	}

	svc := NewShareService(repo)

	_, err := svc.CreateShare(context.Background(), uuid.New(), domain.CreateShareRequest{
		EncryptedContent: "enc-content",
		EncryptedTitle:   "enc-title",
		ShareKeyHash:     "hash123",
	})
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetShare
// ---------------------------------------------------------------------------

func TestShareService_GetShare_Success(t *testing.T) {
	shareID := "abc123def456abc123def456abc123de"
	repo := &mockSharedNoteRepo{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return &domain.SharedNote{
				ID:               id,
				EncryptedContent: "enc-content",
				EncryptedTitle:   "enc-title",
				ViewCount:        5,
			}, nil
		},
	}

	svc := NewShareService(repo)

	resp, err := svc.GetShare(context.Background(), shareID)
	if err != nil {
		t.Fatalf("GetShare: %v", err)
	}
	if resp.ID != shareID {
		t.Errorf("ID = %q, want %q", resp.ID, shareID)
	}
	if resp.ViewCount != 6 {
		t.Errorf("ViewCount = %d, want 6 (original 5 + 1)", resp.ViewCount)
	}
	if resp.EncryptedContent != "enc-content" {
		t.Errorf("EncryptedContent = %q, want %q", resp.EncryptedContent, "enc-content")
	}
}

func TestShareService_GetShare_NotFound(t *testing.T) {
	repo := &mockSharedNoteRepo{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return nil, errors.New("not found")
		},
	}

	svc := NewShareService(repo)

	_, err := svc.GetShare(context.Background(), "nonexistent")
	if err != ErrShareNotFound {
		t.Errorf("error = %v, want ErrShareNotFound", err)
	}
}

func TestShareService_GetShare_Expired(t *testing.T) {
	pastTime := time.Now().UTC().Add(-24 * time.Hour)
	repo := &mockSharedNoteRepo{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return &domain.SharedNote{
				ID:        id,
				ExpiresAt: &pastTime,
				ViewCount: 3,
			}, nil
		},
	}

	svc := NewShareService(repo)

	_, err := svc.GetShare(context.Background(), "expired-share")
	if err != ErrShareExpired {
		t.Errorf("error = %v, want ErrShareExpired", err)
	}
}

func TestShareService_GetShare_MaxViewsReached(t *testing.T) {
	maxViews := 5
	repo := &mockSharedNoteRepo{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return &domain.SharedNote{
				ID:        id,
				ViewCount: 5,
				MaxViews:  &maxViews,
			}, nil
		},
	}

	svc := NewShareService(repo)

	_, err := svc.GetShare(context.Background(), "max-views-share")
	if err != ErrShareMaxViews {
		t.Errorf("error = %v, want ErrShareMaxViews", err)
	}
}

func TestShareService_GetShare_MaxViewsNotYetReached(t *testing.T) {
	maxViews := 10
	repo := &mockSharedNoteRepo{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return &domain.SharedNote{
				ID:        id,
				ViewCount: 9,
				MaxViews:  &maxViews,
			}, nil
		},
	}

	svc := NewShareService(repo)

	resp, err := svc.GetShare(context.Background(), "valid-share")
	if err != nil {
		t.Fatalf("GetShare: %v", err)
	}
	if resp.ViewCount != 10 {
		t.Errorf("ViewCount = %d, want 10", resp.ViewCount)
	}
}

func TestShareService_GetShare_NoExpiryNoMaxViews(t *testing.T) {
	repo := &mockSharedNoteRepo{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return &domain.SharedNote{
				ID:               id,
				EncryptedContent: "content",
				EncryptedTitle:   "title",
				ViewCount:        0,
			}, nil
		},
	}

	svc := NewShareService(repo)

	resp, err := svc.GetShare(context.Background(), "permanent-share")
	if err != nil {
		t.Fatalf("GetShare: %v", err)
	}
	if resp.ViewCount != 1 {
		t.Errorf("ViewCount = %d, want 1", resp.ViewCount)
	}
}

// ---------------------------------------------------------------------------
// Tests: DiscoverFeed
// ---------------------------------------------------------------------------

func TestShareService_DiscoverFeed_Success(t *testing.T) {
	repo := &mockSharedNoteRepo{
		listPublicFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			return []domain.DiscoverFeedItem{
				{ID: "share1", EncryptedTitle: "title1", ViewCount: 10},
				{ID: "share2", EncryptedTitle: "title2", ViewCount: 5},
			}, nil
		},
	}

	svc := NewShareService(repo)

	items, err := svc.DiscoverFeed(context.Background(), 20, 0)
	if err != nil {
		t.Fatalf("DiscoverFeed: %v", err)
	}
	if len(items) != 2 {
		t.Errorf("items count = %d, want 2", len(items))
	}
}

func TestShareService_DiscoverFeed_DefaultLimit(t *testing.T) {
	var capturedLimit int
	repo := &mockSharedNoteRepo{
		listPublicFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			capturedLimit = limit
			return nil, nil
		},
	}

	svc := NewShareService(repo)

	// limit = 0 should be normalized to 20
	_, err := svc.DiscoverFeed(context.Background(), 0, 0)
	if err != nil {
		t.Fatalf("DiscoverFeed: %v", err)
	}
	if capturedLimit != 20 {
		t.Errorf("limit = %d, want 20 (default)", capturedLimit)
	}
}

func TestShareService_DiscoverFeed_ExceedsMaxLimit(t *testing.T) {
	var capturedLimit int
	repo := &mockSharedNoteRepo{
		listPublicFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			capturedLimit = limit
			return nil, nil
		},
	}

	svc := NewShareService(repo)

	// limit > 100 should be normalized to 20
	_, err := svc.DiscoverFeed(context.Background(), 200, 0)
	if err != nil {
		t.Fatalf("DiscoverFeed: %v", err)
	}
	if capturedLimit != 20 {
		t.Errorf("limit = %d, want 20 (clamped default)", capturedLimit)
	}
}

func TestShareService_DiscoverFeed_NegativeOffset(t *testing.T) {
	var capturedOffset int
	repo := &mockSharedNoteRepo{
		listPublicFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			capturedOffset = offset
			return nil, nil
		},
	}

	svc := NewShareService(repo)

	_, err := svc.DiscoverFeed(context.Background(), 10, -5)
	if err != nil {
		t.Fatalf("DiscoverFeed: %v", err)
	}
	if capturedOffset != 0 {
		t.Errorf("offset = %d, want 0 (clamped)", capturedOffset)
	}
}

func TestShareService_DiscoverFeed_RepoError(t *testing.T) {
	repo := &mockSharedNoteRepo{
		listPublicFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			return nil, errors.New("db error")
		},
	}

	svc := NewShareService(repo)

	_, err := svc.DiscoverFeed(context.Background(), 20, 0)
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: ToggleReaction
// ---------------------------------------------------------------------------

func TestShareService_ToggleReaction_Heart(t *testing.T) {
	repo := &mockSharedNoteRepo{
		reactFn: func(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error) {
			return &domain.ReactResponse{ReactionType: "heart", Active: true, Count: 1}, nil
		},
	}

	svc := NewShareService(repo)
	userID := uuid.New()

	resp, err := svc.ToggleReaction(context.Background(), userID, "share123", "heart")
	if err != nil {
		t.Fatalf("ToggleReaction: %v", err)
	}
	if !resp.Active {
		t.Error("Active should be true")
	}
	if resp.Count != 1 {
		t.Errorf("Count = %d, want 1", resp.Count)
	}
}

func TestShareService_ToggleReaction_Bookmark(t *testing.T) {
	repo := &mockSharedNoteRepo{
		reactFn: func(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error) {
			return &domain.ReactResponse{ReactionType: "bookmark", Active: true, Count: 3}, nil
		},
	}

	svc := NewShareService(repo)

	resp, err := svc.ToggleReaction(context.Background(), uuid.New(), "share123", "bookmark")
	if err != nil {
		t.Fatalf("ToggleReaction: %v", err)
	}
	if resp.ReactionType != "bookmark" {
		t.Errorf("ReactionType = %q, want %q", resp.ReactionType, "bookmark")
	}
}

func TestShareService_ToggleReaction_InvalidReactionType(t *testing.T) {
	repo := &mockSharedNoteRepo{}
	svc := NewShareService(repo)

	_, err := svc.ToggleReaction(context.Background(), uuid.New(), "share123", "invalid")
	if err != ErrInvalidReaction {
		t.Errorf("error = %v, want ErrInvalidReaction", err)
	}
}

func TestShareService_ToggleReaction_RepoErrorNotFK(t *testing.T) {
	repo := &mockSharedNoteRepo{
		reactFn: func(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error) {
			return nil, errors.New("some other db error")
		},
	}

	svc := NewShareService(repo)

	_, err := svc.ToggleReaction(context.Background(), uuid.New(), "share123", "heart")
	if err == nil {
		t.Error("expected error from React")
	}
	if errors.Is(err, ErrShareNotFound) {
		t.Errorf("non-FK error should not be mapped to ErrShareNotFound, got: %v", err)
	}
}

func TestShareService_ToggleReaction_ShareNotFound(t *testing.T) {
	repo := &mockSharedNoteRepo{
		reactFn: func(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error) {
			return nil, errors.New("foreign key violation: 23503")
		},
	}

	svc := NewShareService(repo)

	_, err := svc.ToggleReaction(context.Background(), uuid.New(), "nonexistent", "heart")
	if err != ErrShareNotFound {
		t.Errorf("error = %v, want ErrShareNotFound", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: generateShareID
// ---------------------------------------------------------------------------

func TestGenerateShareID(t *testing.T) {
	id, err := generateShareID()
	if err != nil {
		t.Fatalf("generateShareID: %v", err)
	}
	if len(id) != 32 {
		t.Errorf("ID length = %d, want 32", len(id))
	}
	// Verify it is valid hex.
	for _, c := range id {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			t.Errorf("ID contains non-hex character: %c", c)
			break
		}
	}
}

func TestGenerateShareID_Uniqueness(t *testing.T) {
	ids := make(map[string]bool)
	for i := 0; i < 100; i++ {
		id, err := generateShareID()
		if err != nil {
			t.Fatalf("generateShareID: %v", err)
		}
		if ids[id] {
			t.Errorf("duplicate ID generated: %s", id)
		}
		ids[id] = true
	}
}
