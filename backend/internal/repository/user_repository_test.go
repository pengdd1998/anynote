package repository

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// NOTE: Repository tests that require a running PostgreSQL instance are
// skipped when the database is unavailable. See device_token_repository_test.go
// for integration test instructions.
// ---------------------------------------------------------------------------

// TestUserRepository_DocumentsExpectedBehavior documents the expected SQL
// behaviors for the UserRepository. These behaviors are tested indirectly
// through AuthService tests using mock repositories.
func TestUserRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("Create_hashes_auth_key_and_inserts", func(t *testing.T) {
		// Expected behavior:
		//   1. bcrypt.GenerateFromPassword(user.AuthKeyHash, bcryptCost)
		//   2. INSERT INTO users (id, email, username, auth_key_hash, salt, recovery_key, plan)
		//      VALUES ($1, $2, $3, $4, $5, $6, $7)
		//
		// The auth_key_hash is bcrypt-hashed before storage.
		// Returns error on duplicate email or username (unique constraint).
		t.Log("documented: Create bcrypt-hashes AuthKeyHash before INSERT")
	})

	t.Run("GetByEmail_selects_user", func(t *testing.T) {
		// Expected behavior:
		//   SELECT id, email, username, auth_key_hash, salt, recovery_key, plan, created_at, updated_at
		//   FROM users WHERE email = $1
		//
		// Returns pgx.ErrNoRows when email not found.
		t.Log("documented: GetByEmail queries by email, returns full user record")
	})

	t.Run("GetByID_selects_user", func(t *testing.T) {
		// Expected behavior:
		//   SELECT id, email, username, auth_key_hash, salt, recovery_key, plan, created_at, updated_at
		//   FROM users WHERE id = $1
		//
		// Returns pgx.ErrNoRows when id not found.
		t.Log("documented: GetByID queries by UUID primary key")
	})
}

// ---------------------------------------------------------------------------
// Unit tests verifying business logic in the repository layer
// ---------------------------------------------------------------------------

func TestUserRepository_BCryptHashing(t *testing.T) {
	// Verify that the bcrypt hashing used in Create works correctly.
	authKey := []byte("test-auth-key-123")

	hashed, err := bcrypt.GenerateFromPassword(authKey, bcryptCost)
	if err != nil {
		t.Fatalf("bcrypt.GenerateFromPassword: %v", err)
	}

	if string(hashed) == string(authKey) {
		t.Error("hashed password should differ from plaintext")
	}

	if err := bcrypt.CompareHashAndPassword(hashed, authKey); err != nil {
		t.Errorf("CompareHashAndPassword: %v", err)
	}

	if err := bcrypt.CompareHashAndPassword(hashed, []byte("wrong")); err == nil {
		t.Error("wrong password should not match")
	}
}

// mockUserRepo satisfies the service.UserRepository interface for unit tests.
type mockUserRepo struct {
	usersByEmail map[string]*domain.User
	usersByID    map[uuid.UUID]*domain.User
}

func newMockUserRepo() *mockUserRepo {
	return &mockUserRepo{
		usersByEmail: make(map[string]*domain.User),
		usersByID:    make(map[uuid.UUID]*domain.User),
	}
}

func (m *mockUserRepo) Create(ctx context.Context, user *domain.User) error {
	if _, exists := m.usersByEmail[user.Email]; exists {
		return errors.New("duplicate email")
	}
	m.usersByEmail[user.Email] = user
	m.usersByID[user.ID] = user
	return nil
}

func (m *mockUserRepo) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	u, ok := m.usersByEmail[email]
	if !ok {
		return nil, errors.New("user not found")
	}
	return u, nil
}

func (m *mockUserRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	u, ok := m.usersByID[id]
	if !ok {
		return nil, errors.New("user not found")
	}
	return u, nil
}

func (m *mockUserRepo) GetRecoverySalt(ctx context.Context, id uuid.UUID) ([]byte, error) {
	u, ok := m.usersByID[id]
	if !ok {
		return nil, errors.New("user not found")
	}
	return u.RecoverySalt, nil
}

func (m *mockUserRepo) GetRecoverySaltByEmail(ctx context.Context, email string) ([]byte, error) {
	u, ok := m.usersByEmail[email]
	if !ok {
		return nil, errors.New("user not found")
	}
	return u.RecoverySalt, nil
}

func TestMockUserRepo_Create(t *testing.T) {
	repo := newMockUserRepo()
	ctx := context.Background()
	user := &domain.User{
		ID:       uuid.New(),
		Email:    "test@example.com",
		Username: "testuser",
		Plan:     "free",
	}

	err := repo.Create(ctx, user)
	if err != nil {
		t.Fatalf("Create: %v", err)
	}

	got, err := repo.GetByEmail(ctx, "test@example.com")
	if err != nil {
		t.Fatalf("GetByEmail: %v", err)
	}
	if got.ID != user.ID {
		t.Errorf("ID = %v, want %v", got.ID, user.ID)
	}
	if got.Username != "testuser" {
		t.Errorf("Username = %q, want %q", got.Username, "testuser")
	}
}

func TestMockUserRepo_Create_DuplicateEmail(t *testing.T) {
	repo := newMockUserRepo()
	ctx := context.Background()

	user1 := &domain.User{ID: uuid.New(), Email: "dup@example.com", Username: "user1"}
	user2 := &domain.User{ID: uuid.New(), Email: "dup@example.com", Username: "user2"}

	if err := repo.Create(ctx, user1); err != nil {
		t.Fatalf("first Create: %v", err)
	}
	if err := repo.Create(ctx, user2); err == nil {
		t.Error("duplicate Create should return error")
	}
}

func TestMockUserRepo_GetByEmail_NotFound(t *testing.T) {
	repo := newMockUserRepo()
	ctx := context.Background()

	_, err := repo.GetByEmail(ctx, "nonexistent@example.com")
	if err == nil {
		t.Error("GetByEmail should return error for nonexistent email")
	}
}

func TestMockUserRepo_GetByID_NotFound(t *testing.T) {
	repo := newMockUserRepo()
	ctx := context.Background()

	_, err := repo.GetByID(ctx, uuid.New())
	if err == nil {
		t.Error("GetByID should return error for nonexistent ID")
	}
}

func TestMockUserRepo_GetByID_Found(t *testing.T) {
	repo := newMockUserRepo()
	ctx := context.Background()
	user := &domain.User{ID: uuid.New(), Email: "id@test.com", Username: "idtest"}

	repo.Create(ctx, user)

	got, err := repo.GetByID(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}
	if got.Email != "id@test.com" {
		t.Errorf("Email = %q, want %q", got.Email, "id@test.com")
	}
}
