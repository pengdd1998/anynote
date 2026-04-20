package repository

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestSharedNoteRepository_DocumentsExpectedBehavior documents expected SQL behaviors.
func TestSharedNoteRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("Create_inserts_shared_note", func(t *testing.T) {
		// INSERT INTO shared_notes (id, encrypted_content, encrypted_title, share_key_hash,
		//   has_password, is_public, expires_at, max_views, created_by)
		//   VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		t.Log("documented: Create inserts a new shared note record")
	})

	t.Run("GetByID_selects_full_record", func(t *testing.T) {
		// SELECT id, encrypted_content, encrypted_title, share_key_hash,
		//   has_password, is_public, expires_at, view_count, max_views,
		//   reaction_heart, reaction_bookmark, created_by, created_at
		// FROM shared_notes WHERE id = $1
		t.Log("documented: GetByID returns full shared note including view_count and reactions")
	})

	t.Run("IncrementViewCount_increments", func(t *testing.T) {
		// UPDATE shared_notes SET view_count = view_count + 1 WHERE id = $1
		t.Log("documented: IncrementViewCount atomically increments view_count")
	})

	t.Run("DeleteExpired_removes_expired_notes", func(t *testing.T) {
		// DELETE FROM shared_notes WHERE expires_at IS NOT NULL AND expires_at < NOW()
		t.Log("documented: DeleteExpired removes notes past their expires_at timestamp")
	})

	t.Run("ListByUser_returns_user_notes", func(t *testing.T) {
		// SELECT ... FROM shared_notes WHERE created_by = $1 ORDER BY created_at DESC
		t.Log("documented: ListByUser returns notes created by user, newest first")
	})

	t.Run("ListPublic_returns_discovery_feed", func(t *testing.T) {
		// SELECT ... FROM shared_notes
		// WHERE is_public = TRUE AND (expires_at IS NULL OR expires_at > NOW())
		// ORDER BY created_at DESC LIMIT $1 OFFSET $2
		t.Log("documented: ListPublic returns non-expired public notes for discovery")
	})

	t.Run("React_toggles_reaction", func(t *testing.T) {
		// Complex toggle logic using note_reactions table + denormalized counters.
		// Returns ErrInvalidReaction for unknown reaction types.
		t.Log("documented: React toggles heart/bookmark reactions with denormalized counters")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

type mockSharedNoteRepo struct {
	notes     map[string]*domain.SharedNote
	reactions map[string]map[string]bool // key: noteID:userID → reaction types
}

func newMockSharedNoteRepo() *mockSharedNoteRepo {
	return &mockSharedNoteRepo{
		notes:     make(map[string]*domain.SharedNote),
		reactions: make(map[string]map[string]bool),
	}
}

func (m *mockSharedNoteRepo) Create(ctx context.Context, note *domain.SharedNote) error {
	m.notes[note.ID] = note
	return nil
}

func (m *mockSharedNoteRepo) GetByID(ctx context.Context, id string) (*domain.SharedNote, error) {
	n, ok := m.notes[id]
	if !ok {
		return nil, errors.New("shared note not found")
	}
	return n, nil
}

func (m *mockSharedNoteRepo) IncrementViewCount(ctx context.Context, id string) error {
	n, ok := m.notes[id]
	if !ok {
		return errors.New("shared note not found")
	}
	n.ViewCount++
	return nil
}

func (m *mockSharedNoteRepo) DeleteExpired(ctx context.Context) (int64, error) {
	var deleted int64
	now := time.Now()
	for id, n := range m.notes {
		if n.ExpiresAt != nil && n.ExpiresAt.Before(now) {
			delete(m.notes, id)
			deleted++
		}
	}
	return deleted, nil
}

func (m *mockSharedNoteRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.SharedNote, error) {
	var result []domain.SharedNote
	for _, n := range m.notes {
		if n.CreatedBy == userID {
			result = append(result, *n)
		}
	}
	return result, nil
}

func (m *mockSharedNoteRepo) ListPublic(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
	var items []domain.DiscoverFeedItem
	now := time.Now()
	for _, n := range m.notes {
		if n.IsPublic && (n.ExpiresAt == nil || n.ExpiresAt.After(now)) {
			items = append(items, domain.DiscoverFeedItem{
				ID:               n.ID,
				EncryptedTitle:   n.EncryptedTitle,
				HasPassword:      n.HasPassword,
				ViewCount:        n.ViewCount,
				ReactionHeart:    n.ReactionHeart,
				ReactionBookmark: n.ReactionBookmark,
				CreatedAt:        n.CreatedAt,
			})
		}
	}
	return items, nil
}

func (m *mockSharedNoteRepo) React(ctx context.Context, noteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error) {
	if reactionType != "heart" && reactionType != "bookmark" {
		return nil, domain.ErrInvalidReaction
	}

	key := noteID + ":" + userID.String()
	userReactions, exists := m.reactions[key]

	n, noteExists := m.notes[noteID]
	if !noteExists {
		return nil, errors.New("shared note not found")
	}

	if exists && userReactions[reactionType] {
		// Toggle off.
		delete(userReactions, reactionType)
		if reactionType == "heart" {
			n.ReactionHeart--
		} else {
			n.ReactionBookmark--
		}
		counter := n.ReactionHeart
		if reactionType == "bookmark" {
			counter = n.ReactionBookmark
		}
		return &domain.ReactResponse{ReactionType: reactionType, Active: false, Count: counter}, nil
	}

	// Toggle on.
	if !exists {
		m.reactions[key] = make(map[string]bool)
	}
	m.reactions[key][reactionType] = true
	if reactionType == "heart" {
		n.ReactionHeart++
	} else {
		n.ReactionBookmark++
	}
	counter := n.ReactionHeart
	if reactionType == "bookmark" {
		counter = n.ReactionBookmark
	}
	return &domain.ReactResponse{ReactionType: reactionType, Active: true, Count: counter}, nil
}

func TestMockSharedNoteRepo_CreateAndGet(t *testing.T) {
	repo := newMockSharedNoteRepo()
	ctx := context.Background()
	userID := uuid.New()

	note := &domain.SharedNote{
		ID:               "share-1",
		EncryptedContent: "encrypted",
		EncryptedTitle:   "title",
		IsPublic:         true,
		CreatedBy:        userID,
	}
	repo.Create(ctx, note)

	got, err := repo.GetByID(ctx, "share-1")
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}
	if !got.IsPublic {
		t.Error("IsPublic should be true")
	}
	if got.CreatedBy != userID {
		t.Error("CreatedBy mismatch")
	}
}

func TestMockSharedNoteRepo_GetByID_NotFound(t *testing.T) {
	repo := newMockSharedNoteRepo()
	ctx := context.Background()

	_, err := repo.GetByID(ctx, "nonexistent")
	if err == nil {
		t.Error("GetByID should return error for nonexistent note")
	}
}

func TestMockSharedNoteRepo_IncrementViewCount(t *testing.T) {
	repo := newMockSharedNoteRepo()
	ctx := context.Background()
	repo.Create(ctx, &domain.SharedNote{ID: "share-1"})

	repo.IncrementViewCount(ctx, "share-1")
	repo.IncrementViewCount(ctx, "share-1")

	n, _ := repo.GetByID(ctx, "share-1")
	if n.ViewCount != 2 {
		t.Errorf("ViewCount = %d, want 2", n.ViewCount)
	}
}

func TestMockSharedNoteRepo_DeleteExpired(t *testing.T) {
	repo := newMockSharedNoteRepo()
	ctx := context.Background()
	past := time.Now().Add(-1 * time.Hour)
	future := time.Now().Add(24 * time.Hour)

	repo.Create(ctx, &domain.SharedNote{ID: "expired", ExpiresAt: &past})
	repo.Create(ctx, &domain.SharedNote{ID: "valid", ExpiresAt: &future})
	repo.Create(ctx, &domain.SharedNote{ID: "no-expiry"})

	deleted, err := repo.DeleteExpired(ctx)
	if err != nil {
		t.Fatalf("DeleteExpired: %v", err)
	}
	if deleted != 1 {
		t.Errorf("deleted = %d, want 1", deleted)
	}

	if _, err := repo.GetByID(ctx, "expired"); err == nil {
		t.Error("expired note should be deleted")
	}
	if _, err := repo.GetByID(ctx, "valid"); err != nil {
		t.Error("valid note should still exist")
	}
}

func TestMockSharedNoteRepo_ListPublic(t *testing.T) {
	repo := newMockSharedNoteRepo()
	ctx := context.Background()

	repo.Create(ctx, &domain.SharedNote{ID: "pub-1", IsPublic: true, EncryptedTitle: "t1"})
	repo.Create(ctx, &domain.SharedNote{ID: "priv-1", IsPublic: false, EncryptedTitle: "t2"})
	repo.Create(ctx, &domain.SharedNote{ID: "pub-2", IsPublic: true, EncryptedTitle: "t3"})

	items, err := repo.ListPublic(ctx, 10, 0)
	if err != nil {
		t.Fatalf("ListPublic: %v", err)
	}
	if len(items) != 2 {
		t.Errorf("len(items) = %d, want 2 public notes", len(items))
	}
}

func TestMockSharedNoteRepo_React_Toggle(t *testing.T) {
	repo := newMockSharedNoteRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.Create(ctx, &domain.SharedNote{ID: "share-1"})

	// React (toggle on).
	resp, err := repo.React(ctx, "share-1", userID, "heart")
	if err != nil {
		t.Fatalf("React: %v", err)
	}
	if !resp.Active {
		t.Error("first reaction should be active")
	}
	if resp.Count != 1 {
		t.Errorf("Count = %d, want 1", resp.Count)
	}

	// React again (toggle off).
	resp, err = repo.React(ctx, "share-1", userID, "heart")
	if err != nil {
		t.Fatalf("React toggle off: %v", err)
	}
	if resp.Active {
		t.Error("second reaction should be inactive (toggled off)")
	}
	if resp.Count != 0 {
		t.Errorf("Count = %d, want 0", resp.Count)
	}
}

func TestMockSharedNoteRepo_React_InvalidType(t *testing.T) {
	repo := newMockSharedNoteRepo()
	ctx := context.Background()
	repo.Create(ctx, &domain.SharedNote{ID: "share-1"})

	_, err := repo.React(ctx, "share-1", uuid.New(), "invalid")
	if err != domain.ErrInvalidReaction {
		t.Errorf("error = %v, want ErrInvalidReaction", err)
	}
}

func TestMockSharedNoteRepo_ListByUser(t *testing.T) {
	repo := newMockSharedNoteRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()

	repo.Create(ctx, &domain.SharedNote{ID: "u1-1", CreatedBy: user1})
	repo.Create(ctx, &domain.SharedNote{ID: "u1-2", CreatedBy: user1})
	repo.Create(ctx, &domain.SharedNote{ID: "u2-1", CreatedBy: user2})

	notes, err := repo.ListByUser(ctx, user1)
	if err != nil {
		t.Fatalf("ListByUser: %v", err)
	}
	if len(notes) != 2 {
		t.Errorf("len(notes) = %d, want 2 for user1", len(notes))
	}
}
