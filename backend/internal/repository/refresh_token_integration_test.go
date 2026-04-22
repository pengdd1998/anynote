//go:build integration

package repository

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/testutil"
)

// refreshTestRepo returns a RefreshTokenRepository backed by the shared
// integration pool. It truncates dependent tables before each test.
func refreshTestRepo(t *testing.T) *RefreshTokenRepository {
	t.Helper()
	pool := ensurePool(t)
	testutil.CleanTable(t, pool, "refresh_tokens", "users")
	return NewRefreshTokenRepository(pool)
}

// seedRefreshUser creates a test user and returns the UUID.
func seedRefreshUser(t *testing.T) uuid.UUID {
	t.Helper()
	pool := ensurePool(t)
	id := uuid.New()
	email := fmt.Sprintf("rt-%s@example.com", id.String()[:8])
	username := fmt.Sprintf("rtuser_%s", id.String()[:8])
	testutil.SeedUser(t, pool, id.String(), email, username)
	return id
}

// ---------------------------------------------------------------------------
// Tests: Store + IsRevoked
// ---------------------------------------------------------------------------

func TestRefreshToken_CreateAndGet(t *testing.T) {
	repo := refreshTestRepo(t)
	ctx := context.Background()
	userID := seedRefreshUser(t)

	tokenID := "jti-" + uuid.New().String()
	expiresAt := time.Now().Add(7 * 24 * time.Hour).UTC().Truncate(time.Millisecond)

	// Store the refresh token.
	if err := repo.Store(ctx, userID, tokenID, expiresAt); err != nil {
		t.Fatalf("Store: %v", err)
	}

	// Verify the token is not revoked immediately after creation.
	revoked, err := repo.IsRevoked(ctx, tokenID)
	if err != nil {
		t.Fatalf("IsRevoked: %v", err)
	}
	if revoked {
		t.Error("newly stored token should not be revoked")
	}
}

// ---------------------------------------------------------------------------
// Tests: Revoke
// ---------------------------------------------------------------------------

func TestRefreshToken_Revoke(t *testing.T) {
	repo := refreshTestRepo(t)
	ctx := context.Background()
	userID := seedRefreshUser(t)

	tokenID := "jti-" + uuid.New().String()
	expiresAt := time.Now().Add(7 * 24 * time.Hour).UTC()

	if err := repo.Store(ctx, userID, tokenID, expiresAt); err != nil {
		t.Fatalf("Store: %v", err)
	}

	// Revoke the token.
	ok, err := repo.Revoke(ctx, tokenID)
	if err != nil {
		t.Fatalf("Revoke: %v", err)
	}
	if !ok {
		t.Error("Revoke should return true for existing token")
	}

	// Verify it is now revoked.
	revoked, err := repo.IsRevoked(ctx, tokenID)
	if err != nil {
		t.Fatalf("IsRevoked: %v", err)
	}
	if !revoked {
		t.Error("token should be revoked after Revoke call")
	}

	// Revoke again should return false (already revoked).
	ok, err = repo.Revoke(ctx, tokenID)
	if err != nil {
		t.Fatalf("Revoke (second): %v", err)
	}
	if ok {
		t.Error("second Revoke should return false since token is already revoked")
	}
}

// ---------------------------------------------------------------------------
// Tests: RevokeAllForUser
// ---------------------------------------------------------------------------

func TestRefreshToken_RevokeByUserID(t *testing.T) {
	repo := refreshTestRepo(t)
	ctx := context.Background()
	userID := seedRefreshUser(t)

	// Create three tokens for the same user.
	var tokenIDs []string
	for i := 0; i < 3; i++ {
		tid := "jti-" + uuid.New().String()
		tokenIDs = append(tokenIDs, tid)
		expiresAt := time.Now().Add(7 * 24 * time.Hour).UTC()
		if err := repo.Store(ctx, userID, tid, expiresAt); err != nil {
			t.Fatalf("Store[%d]: %v", i, err)
		}
	}

	// Revoke all tokens for this user.
	if err := repo.RevokeAllForUser(ctx, userID); err != nil {
		t.Fatalf("RevokeAllForUser: %v", err)
	}

	// Verify all three are revoked.
	for i, tid := range tokenIDs {
		revoked, err := repo.IsRevoked(ctx, tid)
		if err != nil {
			t.Fatalf("IsRevoked[%d]: %v", i, err)
		}
		if !revoked {
			t.Errorf("token[%d] should be revoked after RevokeAllForUser", i)
		}
	}
}

// ---------------------------------------------------------------------------
// Tests: IsRevoked for non-existent token
// ---------------------------------------------------------------------------

func TestRefreshToken_IsRevoked(t *testing.T) {
	repo := refreshTestRepo(t)
	ctx := context.Background()

	// A token that was never stored should not be considered revoked.
	revoked, err := repo.IsRevoked(ctx, "nonexistent-jti")
	if err != nil {
		t.Fatalf("IsRevoked(nonexistent): %v", err)
	}
	if revoked {
		t.Error("non-existent token should not be reported as revoked")
	}
}

// ---------------------------------------------------------------------------
// Tests: PurgeExpired
// ---------------------------------------------------------------------------

func TestRefreshToken_CleanupExpired(t *testing.T) {
	repo := refreshTestRepo(t)
	ctx := context.Background()
	userID := seedRefreshUser(t)

	// Create an expired token (expires in the past).
	expiredID := "jti-expired-" + uuid.New().String()
	pastExpiry := time.Now().Add(-1 * time.Hour).UTC()
	if err := repo.Store(ctx, userID, expiredID, pastExpiry); err != nil {
		t.Fatalf("Store expired: %v", err)
	}

	// Create a valid token (expires in the future).
	validID := "jti-valid-" + uuid.New().String()
	futureExpiry := time.Now().Add(7 * 24 * time.Hour).UTC()
	if err := repo.Store(ctx, userID, validID, futureExpiry); err != nil {
		t.Fatalf("Store valid: %v", err)
	}

	// Create another expired token.
	expiredID2 := "jti-expired2-" + uuid.New().String()
	if err := repo.Store(ctx, userID, expiredID2, pastExpiry); err != nil {
		t.Fatalf("Store expired2: %v", err)
	}

	// Purge expired tokens.
	purged, err := repo.PurgeExpired(ctx)
	if err != nil {
		t.Fatalf("PurgeExpired: %v", err)
	}
	if purged != 2 {
		t.Errorf("PurgeExpired purged %d rows, want 2", purged)
	}

	// The valid token should still be present and not revoked.
	revoked, err := repo.IsRevoked(ctx, validID)
	if err != nil {
		t.Fatalf("IsRevoked(valid): %v", err)
	}
	if revoked {
		t.Error("valid token should not be revoked after purge")
	}

	// The expired tokens should no longer exist (deleted, not revoked).
	// IsRevoked returns false for non-existent tokens.
	revoked, err = repo.IsRevoked(ctx, expiredID)
	if err != nil {
		t.Fatalf("IsRevoked(expired after purge): %v", err)
	}
	if revoked {
		t.Error("expired token was purged, should not be reported as revoked")
	}
}
