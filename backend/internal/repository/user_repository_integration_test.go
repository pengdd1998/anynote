//go:build integration

package repository

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/testutil"
)

// userTestRepo returns a fresh UserRepository backed by the shared integration
// test pool. It truncates the users table before returning so each test starts
// clean.
func userTestRepo(t *testing.T) *UserRepository {
	t.Helper()
	pool := ensurePool(t)
	testutil.CleanTable(t, pool, "users")
	return NewUserRepository(pool)
}

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

// newTestDomainUser creates a domain.User with unique email/username and
// plausible fake credentials. The caller may override fields after creation.
func newTestDomainUser() *domain.User {
	uid := uuid.New()
	suffix := uid.String()[:8]
	return &domain.User{
		ID:           uid,
		Email:        fmt.Sprintf("test-%s@example.com", suffix),
		Username:     fmt.Sprintf("user_%s", suffix),
		AuthKeyHash:  []byte("plaintext-auth-key-for-testing"),
		Salt:         []byte("0123456789abcdef0123456789abcdef"), // 32 bytes
		RecoveryKey:  []byte("recovery-key-32-bytes-padding!!!"), // 32 bytes
		RecoverySalt: []byte("recovery-salt-32-bytes-padding!!!"), // 32 bytes
		Plan:         "free",
	}
}

// ---------------------------------------------------------------------------
// Tests: Create
// ---------------------------------------------------------------------------

func TestUserRepository_Create_Success(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	user := newTestDomainUser()
	if err := repo.Create(ctx, user); err != nil {
		t.Fatalf("Create: %v", err)
	}
}

func TestUserRepository_Create_DuplicateEmail(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	user1 := newTestDomainUser()
	if err := repo.Create(ctx, user1); err != nil {
		t.Fatalf("Create first user: %v", err)
	}

	// Second user with same email but different ID and username.
	user2 := newTestDomainUser()
	user2.Email = user1.Email
	if err := repo.Create(ctx, user2); err == nil {
		t.Error("expected error when creating user with duplicate email")
	}
}

func TestUserRepository_Create_DuplicateUsername(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	user1 := newTestDomainUser()
	if err := repo.Create(ctx, user1); err != nil {
		t.Fatalf("Create first user: %v", err)
	}

	// Second user with same username but different ID and email.
	user2 := newTestDomainUser()
	user2.Username = user1.Username
	if err := repo.Create(ctx, user2); err == nil {
		t.Error("expected error when creating user with duplicate username")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetByEmail
// ---------------------------------------------------------------------------

func TestUserRepository_GetByEmail(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	original := newTestDomainUser()
	if err := repo.Create(ctx, original); err != nil {
		t.Fatalf("Create: %v", err)
	}

	got, err := repo.GetByEmail(ctx, original.Email)
	if err != nil {
		t.Fatalf("GetByEmail: %v", err)
	}

	// Verify scalar fields.
	if got.ID != original.ID {
		t.Errorf("ID = %v, want %v", got.ID, original.ID)
	}
	if got.Email != original.Email {
		t.Errorf("Email = %q, want %q", got.Email, original.Email)
	}
	if got.Username != original.Username {
		t.Errorf("Username = %q, want %q", got.Username, original.Username)
	}
	if got.Plan != original.Plan {
		t.Errorf("Plan = %q, want %q", got.Plan, original.Plan)
	}

	// Verify non-hashed byte fields match exactly.
	if string(got.Salt) != string(original.Salt) {
		t.Errorf("Salt mismatch")
	}
	if string(got.RecoveryKey) != string(original.RecoveryKey) {
		t.Errorf("RecoveryKey mismatch")
	}
	if string(got.RecoverySalt) != string(original.RecoverySalt) {
		t.Errorf("RecoverySalt mismatch")
	}

	// AuthKeyHash is bcrypt-hashed by Create, so it must differ from the
	// plaintext value we passed in.
	if string(got.AuthKeyHash) == string(original.AuthKeyHash) {
		t.Error("AuthKeyHash should be bcrypt-hashed, but matched plaintext")
	}

	// Timestamps should be non-zero.
	if got.CreatedAt.IsZero() {
		t.Error("CreatedAt should not be zero")
	}
	if got.UpdatedAt.IsZero() {
		t.Error("UpdatedAt should not be zero")
	}
}

func TestUserRepository_GetByEmail_NotFound(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	_, err := repo.GetByEmail(ctx, "nonexistent@example.com")
	if err == nil {
		t.Error("expected error for non-existent email")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetByID
// ---------------------------------------------------------------------------

func TestUserRepository_GetByID(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	original := newTestDomainUser()
	if err := repo.Create(ctx, original); err != nil {
		t.Fatalf("Create: %v", err)
	}

	got, err := repo.GetByID(ctx, original.ID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}

	if got.ID != original.ID {
		t.Errorf("ID = %v, want %v", got.ID, original.ID)
	}
	if got.Email != original.Email {
		t.Errorf("Email = %q, want %q", got.Email, original.Email)
	}
	if got.Username != original.Username {
		t.Errorf("Username = %q, want %q", got.Username, original.Username)
	}
	if got.Plan != original.Plan {
		t.Errorf("Plan = %q, want %q", got.Plan, original.Plan)
	}
	if string(got.Salt) != string(original.Salt) {
		t.Errorf("Salt mismatch")
	}
	if string(got.RecoveryKey) != string(original.RecoveryKey) {
		t.Errorf("RecoveryKey mismatch")
	}
	if string(got.RecoverySalt) != string(original.RecoverySalt) {
		t.Errorf("RecoverySalt mismatch")
	}
	// AuthKeyHash is bcrypt-hashed; must differ from plaintext.
	if string(got.AuthKeyHash) == string(original.AuthKeyHash) {
		t.Error("AuthKeyHash should be bcrypt-hashed, but matched plaintext")
	}
}

func TestUserRepository_GetByID_NotFound(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	_, err := repo.GetByID(ctx, uuid.New())
	if err == nil {
		t.Error("expected error for non-existent ID")
	}
}

// ---------------------------------------------------------------------------
// Tests: Delete
// ---------------------------------------------------------------------------

func TestUserRepository_Delete(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	user := newTestDomainUser()
	if err := repo.Create(ctx, user); err != nil {
		t.Fatalf("Create: %v", err)
	}

	if err := repo.Delete(ctx, user.ID); err != nil {
		t.Fatalf("Delete: %v", err)
	}

	_, err := repo.GetByID(ctx, user.ID)
	if err == nil {
		t.Error("expected error after deleting user, but GetByID succeeded")
	}
}

// ---------------------------------------------------------------------------
// Tests: bcrypt hash verification (end-to-end through DB round-trip)
// ---------------------------------------------------------------------------

func TestUserRepository_BcryptHashVerification(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	// Use a known plaintext password as AuthKeyHash.
	plaintext := []byte("my-secret-auth-key-12345")
	user := newTestDomainUser()
	user.AuthKeyHash = plaintext

	if err := repo.Create(ctx, user); err != nil {
		t.Fatalf("Create: %v", err)
	}

	// Fetch the stored user. AuthKeyHash is now the bcrypt hash.
	stored, err := repo.GetByID(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}

	// The stored hash must verify against the original plaintext.
	if err := bcrypt.CompareHashAndPassword(stored.AuthKeyHash, plaintext); err != nil {
		t.Errorf("CompareHashAndPassword with correct key: %v", err)
	}

	// A wrong key must NOT verify.
	if err := bcrypt.CompareHashAndPassword(stored.AuthKeyHash, []byte("wrong-key")); err == nil {
		t.Error("CompareHashAndPassword with wrong key should fail, but succeeded")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetRecoverySalt
// ---------------------------------------------------------------------------

func TestUserRepository_GetRecoverySalt(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	user := newTestDomainUser()
	if err := repo.Create(ctx, user); err != nil {
		t.Fatalf("Create: %v", err)
	}

	salt, err := repo.GetRecoverySalt(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetRecoverySalt: %v", err)
	}
	if string(salt) != string(user.RecoverySalt) {
		t.Errorf("RecoverySalt = %x, want %x", salt, user.RecoverySalt)
	}
}

func TestUserRepository_GetRecoverySaltByEmail(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	user := newTestDomainUser()
	if err := repo.Create(ctx, user); err != nil {
		t.Fatalf("Create: %v", err)
	}

	salt, err := repo.GetRecoverySaltByEmail(ctx, user.Email)
	if err != nil {
		t.Fatalf("GetRecoverySaltByEmail: %v", err)
	}
	if string(salt) != string(user.RecoverySalt) {
		t.Errorf("RecoverySalt = %x, want %x", salt, user.RecoverySalt)
	}
}

func TestUserRepository_GetRecoverySalt_NilForLegacyUser(t *testing.T) {
	pool := ensurePool(t)
	testutil.CleanTable(t, pool, "users")
	repo := NewUserRepository(pool)
	ctx := context.Background()

	// Simulate a legacy user by inserting directly via the pool, setting
	// recovery_salt to NULL (as it would have been before migration 016).
	user := newTestDomainUser()
	// Use raw SQL to insert with NULL recovery_salt, bypassing the repository
	// Create method which would set it.
	_, err := pool.Exec(ctx,
		`INSERT INTO users (id, email, username, auth_key_hash, salt, recovery_key, recovery_salt, plan)
		 VALUES ($1, $2, $3, $4, $5, $6, NULL, $7)`,
		user.ID, user.Email, user.Username,
		[]byte("$2a$12$legacyplaceholderhash123456789012345678"),
		user.Salt, user.RecoveryKey, user.Plan,
	)
	if err != nil {
		t.Fatalf("insert legacy user: %v", err)
	}

	// GetRecoverySalt should return nil for a legacy user.
	salt, err := repo.GetRecoverySalt(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetRecoverySalt for legacy user: %v", err)
	}
	if salt != nil {
		t.Errorf("expected nil recovery_salt for legacy user, got %x", salt)
	}

	// Same via email lookup.
	saltByEmail, err := repo.GetRecoverySaltByEmail(ctx, user.Email)
	if err != nil {
		t.Fatalf("GetRecoverySaltByEmail for legacy user: %v", err)
	}
	if saltByEmail != nil {
		t.Errorf("expected nil recovery_salt by email for legacy user, got %x", saltByEmail)
	}
}

// ---------------------------------------------------------------------------
// Tests: full CRUD round-trip
// ---------------------------------------------------------------------------

func TestUserRepository_FullCRUDRoundTrip(t *testing.T) {
	repo := userTestRepo(t)
	ctx := context.Background()

	user := newTestDomainUser()

	// Step 1: Create.
	if err := repo.Create(ctx, user); err != nil {
		t.Fatalf("Create: %v", err)
	}

	// Step 2: Read by ID.
	byID, err := repo.GetByID(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}
	if byID.Email != user.Email {
		t.Errorf("GetByID: Email = %q, want %q", byID.Email, user.Email)
	}
	if byID.Username != user.Username {
		t.Errorf("GetByID: Username = %q, want %q", byID.Username, user.Username)
	}

	// Step 3: Read by email.
	byEmail, err := repo.GetByEmail(ctx, user.Email)
	if err != nil {
		t.Fatalf("GetByEmail: %v", err)
	}
	if byEmail.ID != user.ID {
		t.Errorf("GetByEmail: ID = %v, want %v", byEmail.ID, user.ID)
	}

	// Both lookups must return the same record.
	if byID.Email != byEmail.Email {
		t.Errorf("GetByID and GetByEmail returned different emails: %q vs %q",
			byID.Email, byEmail.Email)
	}

	// Step 4: Recovery salt lookups.
	saltByID, err := repo.GetRecoverySalt(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetRecoverySalt: %v", err)
	}
	saltByEmail, err := repo.GetRecoverySaltByEmail(ctx, user.Email)
	if err != nil {
		t.Fatalf("GetRecoverySaltByEmail: %v", err)
	}
	if string(saltByID) != string(saltByEmail) {
		t.Errorf("recovery salt mismatch: byID=%x, byEmail=%x", saltByID, saltByEmail)
	}

	// Step 5: Delete.
	if err := repo.Delete(ctx, user.ID); err != nil {
		t.Fatalf("Delete: %v", err)
	}

	// Step 6: Verify deletion.
	if _, err := repo.GetByID(ctx, user.ID); err == nil {
		t.Error("GetByID should fail after Delete")
	}
	if _, err := repo.GetByEmail(ctx, user.Email); err == nil {
		t.Error("GetByEmail should fail after Delete")
	}
}
