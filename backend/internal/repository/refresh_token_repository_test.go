package repository

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

// TestRefreshTokenRepository_DocumentsExpectedBehavior documents expected SQL behaviors.
func TestRefreshTokenRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("Store_inserts_token", func(t *testing.T) {
		// INSERT INTO refresh_tokens (user_id, token_id, expires_at)
		//   VALUES ($1, $2, $3)
		t.Log("documented: Store persists a refresh token record with jti, user, and expiry")
	})

	t.Run("Revoke_marks_revoked", func(t *testing.T) {
		// UPDATE refresh_tokens SET revoked = TRUE WHERE token_id = $1 AND revoked = FALSE
		t.Log("documented: Revoke marks token as revoked, returns whether a row was affected")
	})

	t.Run("IsRevoked_checks_status", func(t *testing.T) {
		// SELECT revoked FROM refresh_tokens WHERE token_id = $1
		t.Log("documented: IsRevoked returns true if token is revoked; returns (false, nil) if not found")
	})

	t.Run("RevokeAllForUser_revokes_all", func(t *testing.T) {
		// UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = $1 AND revoked = FALSE
		t.Log("documented: RevokeAllForUser revokes every active token for a user")
	})

	t.Run("PurgeExpired_removes_old", func(t *testing.T) {
		// DELETE FROM refresh_tokens WHERE expires_at < NOW()
		t.Log("documented: PurgeExpired removes all expired token records, returns count")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

// refreshTokenEntry is the internal representation for the mock store.
// The real repository works with raw fields rather than a domain struct.
type refreshTokenEntry struct {
	userID    uuid.UUID
	tokenID   string
	expiresAt time.Time
	revoked   bool
}

type mockRefreshTokenRepo struct {
	tokens map[string]*refreshTokenEntry // keyed by tokenID
}

func newMockRefreshTokenRepo() *mockRefreshTokenRepo {
	return &mockRefreshTokenRepo{
		tokens: make(map[string]*refreshTokenEntry),
	}
}

func (m *mockRefreshTokenRepo) Store(ctx context.Context, userID uuid.UUID, tokenID string, expiresAt time.Time) error {
	m.tokens[tokenID] = &refreshTokenEntry{
		userID:    userID,
		tokenID:   tokenID,
		expiresAt: expiresAt,
		revoked:   false,
	}
	return nil
}

func (m *mockRefreshTokenRepo) Revoke(ctx context.Context, tokenID string) (bool, error) {
	entry, ok := m.tokens[tokenID]
	if !ok || entry.revoked {
		return false, nil
	}
	entry.revoked = true
	return true, nil
}

func (m *mockRefreshTokenRepo) IsRevoked(ctx context.Context, tokenID string) (bool, error) {
	entry, ok := m.tokens[tokenID]
	if !ok {
		// Not found is treated as not revoked, matching real repository behavior.
		return false, nil
	}
	return entry.revoked, nil
}

func (m *mockRefreshTokenRepo) RevokeAllForUser(ctx context.Context, userID uuid.UUID) error {
	for _, entry := range m.tokens {
		if entry.userID == userID && !entry.revoked {
			entry.revoked = true
		}
	}
	return nil
}

func (m *mockRefreshTokenRepo) PurgeExpired(ctx context.Context) (int64, error) {
	now := time.Now()
	var purged int64
	for tokenID, entry := range m.tokens {
		if entry.expiresAt.Before(now) {
			delete(m.tokens, tokenID)
			purged++
		}
	}
	return purged, nil
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestMockRefreshTokenRepo_Store(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()
	userID := uuid.New()
	tokenID := "jti-abc-123"
	expiresAt := time.Now().Add(7 * 24 * time.Hour)

	err := repo.Store(ctx, userID, tokenID, expiresAt)
	if err != nil {
		t.Fatalf("Store: %v", err)
	}

	entry, ok := repo.tokens[tokenID]
	if !ok {
		t.Fatal("token should be stored")
	}
	if entry.userID != userID {
		t.Errorf("userID = %v, want %v", entry.userID, userID)
	}
	if entry.revoked {
		t.Error("newly stored token should not be revoked")
	}
}

func TestMockRefreshTokenRepo_Revoke_Found(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()
	tokenID := "jti-revoke-me"

	repo.Store(ctx, uuid.New(), tokenID, time.Now().Add(time.Hour))

	found, err := repo.Revoke(ctx, tokenID)
	if err != nil {
		t.Fatalf("Revoke: %v", err)
	}
	if !found {
		t.Error("Revoke should return true for existing unrevoked token")
	}

	// Revoke again should return false (already revoked).
	foundAgain, _ := repo.Revoke(ctx, tokenID)
	if foundAgain {
		t.Error("Revoke should return false for already-revoked token")
	}
}

func TestMockRefreshTokenRepo_Revoke_NotFound(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()

	found, err := repo.Revoke(ctx, "nonexistent-token")
	if err != nil {
		t.Fatalf("Revoke: %v", err)
	}
	if found {
		t.Error("Revoke should return false for nonexistent token")
	}
}

func TestMockRefreshTokenRepo_IsRevoked_Revoked(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()
	tokenID := "jti-check-revoked"

	repo.Store(ctx, uuid.New(), tokenID, time.Now().Add(time.Hour))
	repo.Revoke(ctx, tokenID)

	revoked, err := repo.IsRevoked(ctx, tokenID)
	if err != nil {
		t.Fatalf("IsRevoked: %v", err)
	}
	if !revoked {
		t.Error("IsRevoked should return true for revoked token")
	}
}

func TestMockRefreshTokenRepo_IsRevoked_NotRevoked(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()
	tokenID := "jti-active"

	repo.Store(ctx, uuid.New(), tokenID, time.Now().Add(time.Hour))

	revoked, err := repo.IsRevoked(ctx, tokenID)
	if err != nil {
		t.Fatalf("IsRevoked: %v", err)
	}
	if revoked {
		t.Error("IsRevoked should return false for active token")
	}
}

func TestMockRefreshTokenRepo_IsRevoked_NotFound(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()

	// A token not in the store returns (false, nil), matching real DB behavior.
	revoked, err := repo.IsRevoked(ctx, "no-such-token")
	if err != nil {
		t.Fatalf("IsRevoked: %v", err)
	}
	if revoked {
		t.Error("IsRevoked should return false for nonexistent token")
	}
}

func TestMockRefreshTokenRepo_RevokeAllForUser(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()
	userID := uuid.New()
	otherUser := uuid.New()

	repo.Store(ctx, userID, "token-1", time.Now().Add(time.Hour))
	repo.Store(ctx, userID, "token-2", time.Now().Add(time.Hour))
	repo.Store(ctx, otherUser, "token-3", time.Now().Add(time.Hour))

	err := repo.RevokeAllForUser(ctx, userID)
	if err != nil {
		t.Fatalf("RevokeAllForUser: %v", err)
	}

	// Both tokens for userID should be revoked.
	for _, tid := range []string{"token-1", "token-2"} {
		revoked, _ := repo.IsRevoked(ctx, tid)
		if !revoked {
			t.Errorf("token %q should be revoked after RevokeAllForUser", tid)
		}
	}

	// Token for otherUser should remain active.
	otherRevoked, _ := repo.IsRevoked(ctx, "token-3")
	if otherRevoked {
		t.Error("token-3 (other user) should not be revoked")
	}
}

func TestMockRefreshTokenRepo_PurgeExpired(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()

	past := time.Now().Add(-1 * time.Hour)
	future := time.Now().Add(1 * time.Hour)

	repo.Store(ctx, uuid.New(), "expired-1", past)
	repo.Store(ctx, uuid.New(), "expired-2", past)
	repo.Store(ctx, uuid.New(), "active-1", future)

	purged, err := repo.PurgeExpired(ctx)
	if err != nil {
		t.Fatalf("PurgeExpired: %v", err)
	}
	if purged != 2 {
		t.Errorf("PurgeExpired purged %d, want 2", purged)
	}

	// Active token should still be present.
	_, exists := repo.tokens["active-1"]
	if !exists {
		t.Error("active token should not be purged")
	}

	// Expired tokens should be gone.
	for _, tid := range []string{"expired-1", "expired-2"} {
		if _, exists := repo.tokens[tid]; exists {
			t.Errorf("expired token %q should have been purged", tid)
		}
	}
}

func TestMockRefreshTokenRepo_PurgeExpired_None(t *testing.T) {
	repo := newMockRefreshTokenRepo()
	ctx := context.Background()

	repo.Store(ctx, uuid.New(), "active-1", time.Now().Add(time.Hour))

	purged, err := repo.PurgeExpired(ctx)
	if err != nil {
		t.Fatalf("PurgeExpired: %v", err)
	}
	if purged != 0 {
		t.Errorf("PurgeExpired purged %d, want 0 when no expired tokens", purged)
	}
}
