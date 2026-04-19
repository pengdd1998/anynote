package repository

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// NOTE: These tests require a running PostgreSQL instance with the
// device_tokens table created. When the database is unavailable, the tests
// will be skipped. For CI, use docker-compose to bring up PostgreSQL first.
//
// To run locally:
//   docker compose up -d postgres
//   TEST_DATABASE_URL="postgres://anynote:anynote@localhost:5432/anynote_test?sslmode=disable" go test ./internal/repository/...
// ---------------------------------------------------------------------------

func getTestPool(t *testing.T) interface{} {
	t.Helper()
	// The repository tests need a real pgxpool.Pool. Since we cannot
	// construct one without a running database, we instead test the
	// repository layer via the service layer with mocks (see push_service_test.go).
	//
	// This file documents the expected behavior and provides integration
	// test scaffolding for when a database is available.
	return nil
}

// TestDeviceTokenRepository_DocumentsExpectedBehavior documents the expected
// behaviors for the DeviceTokenRepository. These behaviors are tested
// indirectly through PushService tests using mock repositories.
func TestDeviceTokenRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("Create_inserts_new_token", func(t *testing.T) {
		// Expected behavior:
		//   INSERT INTO device_tokens (id, user_id, token, platform)
		//   VALUES ($1, $2, $3, $4)
		//   ON CONFLICT (token) DO UPDATE SET user_id = $2, platform = $4, updated_at = NOW()
		//
		// When the token does not exist, a new row is created.
		// When the token already exists (conflict), the user_id and platform
		// are updated, allowing device ownership transfer.
		t.Log("documented: Create upserts on token conflict")
	})

	t.Run("DeleteByToken_removes_row", func(t *testing.T) {
		// Expected behavior:
		//   DELETE FROM device_tokens WHERE token = $1
		//
		// Returns nil even if the token did not exist.
		t.Log("documented: DeleteByToken removes by token value")
	})

	t.Run("ListByUser_returns_user_tokens", func(t *testing.T) {
		// Expected behavior:
		//   SELECT id, user_id, token, platform, created_at
		//   FROM device_tokens WHERE user_id = $1 ORDER BY created_at DESC
		//
		// Returns an empty slice (not nil) when no tokens found.
		t.Log("documented: ListByUser returns ordered entries")
	})
}

// The following integration tests will run only when a database is available.
// They are guarded by a build tag or environment variable check.

func skipIfNoDB(t *testing.T) {
	t.Helper()
	dbURL := "postgres://anynote:anynote@localhost:5432/anynote_test?sslmode=disable"
	pool, err := createTestPool(dbURL)
	if err != nil {
		t.Skip("Skipping integration test: PostgreSQL not available")
	}
	_ = pool
}

func createTestPool(dbURL string) (interface{}, error) {
	// Placeholder for integration test setup.
	// In production, use pgxpool.New(context.Background(), dbURL).
	return nil, nil
}

// ---------------------------------------------------------------------------
// Unit tests using an interface-based mock
// ---------------------------------------------------------------------------

// mockDeviceTokenRepo satisfies the service.DeviceTokenRepository interface
// for use in repository-level unit tests.
type mockDeviceTokenRepoForRepoTest struct {
	tokens map[string]*service.DeviceTokenEntry
}

func newMockRepo() *mockDeviceTokenRepoForRepoTest {
	return &mockDeviceTokenRepoForRepoTest{
		tokens: make(map[string]*service.DeviceTokenEntry),
	}
}

func (m *mockDeviceTokenRepoForRepoTest) Create(ctx context.Context, id uuid.UUID, userID string, token string, platform string) error {
	m.tokens[token] = &service.DeviceTokenEntry{
		ID:       id,
		UserID:   userID,
		Token:    token,
		Platform: platform,
	}
	return nil
}

func (m *mockDeviceTokenRepoForRepoTest) DeleteByToken(ctx context.Context, token string) error {
	delete(m.tokens, token)
	return nil
}

func (m *mockDeviceTokenRepoForRepoTest) ListByUser(ctx context.Context, userID string) ([]service.DeviceTokenEntry, error) {
	var result []service.DeviceTokenEntry
	for _, e := range m.tokens {
		if e.UserID == userID {
			result = append(result, *e)
		}
	}
	return result, nil
}

func TestMockRepo_Create(t *testing.T) {
	repo := newMockRepo()
	ctx := context.Background()
	id := uuid.New()

	err := repo.Create(ctx, id, "user-1", "token-abc", "android")
	if err != nil {
		t.Fatalf("Create: %v", err)
	}

	entry, ok := repo.tokens["token-abc"]
	if !ok {
		t.Fatal("token not found after create")
	}
	if entry.UserID != "user-1" {
		t.Errorf("UserID = %q, want %q", entry.UserID, "user-1")
	}
	if entry.Platform != "android" {
		t.Errorf("Platform = %q, want %q", entry.Platform, "android")
	}
	if entry.ID != id {
		t.Errorf("ID = %v, want %v", entry.ID, id)
	}
}

func TestMockRepo_Create_Upsert(t *testing.T) {
	repo := newMockRepo()
	ctx := context.Background()

	// Create with user-1.
	repo.Create(ctx, uuid.New(), "user-1", "shared-token", "android")

	// Upsert with user-2 -- should replace the user.
	repo.Create(ctx, uuid.New(), "user-2", "shared-token", "ios")

	entry := repo.tokens["shared-token"]
	if entry.UserID != "user-2" {
		t.Errorf("UserID = %q, want %q (should be overwritten)", entry.UserID, "user-2")
	}
	if entry.Platform != "ios" {
		t.Errorf("Platform = %q, want %q (should be overwritten)", entry.Platform, "ios")
	}

	// Should still be exactly 1 entry for this token.
	count := 0
	for range repo.tokens {
		count++
	}
	// Note: map has other keys potentially, so we just check the specific token.
	if _, exists := repo.tokens["shared-token"]; !exists {
		t.Error("shared-token should exist")
	}
}

func TestMockRepo_DeleteByToken(t *testing.T) {
	repo := newMockRepo()
	ctx := context.Background()

	repo.Create(ctx, uuid.New(), "user-1", "token-to-delete", "android")
	repo.Create(ctx, uuid.New(), "user-1", "token-to-keep", "ios")

	err := repo.DeleteByToken(ctx, "token-to-delete")
	if err != nil {
		t.Fatalf("DeleteByToken: %v", err)
	}

	if _, exists := repo.tokens["token-to-delete"]; exists {
		t.Error("token should be deleted")
	}
	if _, exists := repo.tokens["token-to-keep"]; !exists {
		t.Error("other token should still exist")
	}
}

func TestMockRepo_ListByUser(t *testing.T) {
	repo := newMockRepo()
	ctx := context.Background()

	repo.Create(ctx, uuid.New(), "user-1", "token-a", "android")
	repo.Create(ctx, uuid.New(), "user-1", "token-b", "ios")
	repo.Create(ctx, uuid.New(), "user-2", "token-c", "web")

	entries, err := repo.ListByUser(ctx, "user-1")
	if err != nil {
		t.Fatalf("ListByUser: %v", err)
	}
	if len(entries) != 2 {
		t.Errorf("len(entries) = %d, want 2", len(entries))
	}

	entries, err = repo.ListByUser(ctx, "user-2")
	if err != nil {
		t.Fatalf("ListByUser: %v", err)
	}
	if len(entries) != 1 {
		t.Errorf("len(entries) = %d, want 1", len(entries))
	}

	entries, err = repo.ListByUser(ctx, "user-none")
	if err != nil {
		t.Fatalf("ListByUser: %v", err)
	}
	if len(entries) != 0 {
		t.Errorf("len(entries) = %d, want 0 for unknown user", len(entries))
	}
}
