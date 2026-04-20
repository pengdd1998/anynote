package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock UserRepository
// ---------------------------------------------------------------------------

type mockUserRepo struct {
	users       map[string]*domain.User // keyed by email
	usersByID   map[uuid.UUID]*domain.User
	createErr   error
}

func newMockUserRepo() *mockUserRepo {
	return &mockUserRepo{
		users:     make(map[string]*domain.User),
		usersByID: make(map[uuid.UUID]*domain.User),
	}
}

func (m *mockUserRepo) Create(ctx context.Context, user *domain.User) error {
	if m.createErr != nil {
		return m.createErr
	}
	m.users[user.Email] = user
	m.usersByID[user.ID] = user
	return nil
}

func (m *mockUserRepo) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	u, ok := m.users[email]
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

func (m *mockUserRepo) Delete(ctx context.Context, id uuid.UUID) error {
	u, ok := m.usersByID[id]
	if !ok {
		return errors.New("user not found")
	}
	delete(m.users, u.Email)
	delete(m.usersByID, id)
	return nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const testJWTSecret = "test-jwt-secret-key-for-unit-tests"

func newTestAuthService(repo UserRepository) AuthService {
	return NewAuthService(repo, testJWTSecret, 1*time.Hour, 7*24*time.Hour)
}

func mustHashAuthKey(plain string) []byte {
	// Simulate the client-side bcrypt hash that would be sent as AuthKeyHash.
	// The server compares this with bcrypt.CompareHashAndPassword, so we
	// generate a bcrypt hash here and use that as both the stored hash and
	// the login credential.
	hash, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	if err != nil {
		panic(err)
	}
	return hash
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestAuthService_Register_Success(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	hash := mustHashAuthKey("client-derived-key")
	salt := []byte("random-salt-16b")

	resp, err := svc.Register(context.Background(), domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice",
		AuthKeyHash: hash,
		Salt:        salt,
		RecoveryKey: []byte("recovery-key"),
	})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	if resp.AccessToken == "" {
		t.Error("AccessToken should not be empty")
	}
	if resp.RefreshToken == "" {
		t.Error("RefreshToken should not be empty")
	}
	if resp.User.Email != "alice@example.com" {
		t.Errorf("User.Email = %q, want %q", resp.User.Email, "alice@example.com")
	}
	if resp.User.Plan != "free" {
		t.Errorf("User.Plan = %q, want %q", resp.User.Plan, "free")
	}
	if resp.User.ID == uuid.Nil {
		t.Error("User.ID should not be nil UUID")
	}
	if resp.ExpiresAt.IsZero() {
		t.Error("ExpiresAt should be set")
	}
}

func TestAuthService_Register_DuplicateEmail(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	hash := mustHashAuthKey("key")
	req := domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice",
		AuthKeyHash: hash,
		Salt:        []byte("salt"),
		RecoveryKey: []byte("recovery"),
	}

	if _, err := svc.Register(context.Background(), req); err != nil {
		t.Fatalf("first Register: %v", err)
	}

	_, err := svc.Register(context.Background(), domain.RegisterRequest{
		Email:       "alice@example.com",
		Username:    "alice2",
		AuthKeyHash: hash,
		Salt:        []byte("salt2"),
		RecoveryKey: []byte("recovery2"),
	})
	if !errors.Is(err, ErrEmailExists) {
		t.Errorf("second Register error = %v, want ErrEmailExists", err)
	}
}

func TestAuthService_Register_RepoError(t *testing.T) {
	repo := newMockUserRepo()
	repo.createErr = errors.New("db connection lost")
	svc := newTestAuthService(repo)

	_, err := svc.Register(context.Background(), domain.RegisterRequest{
		Email:       "bob@example.com",
		Username:    "bob",
		AuthKeyHash: mustHashAuthKey("key"),
		Salt:        []byte("salt"),
		RecoveryKey: []byte("recovery"),
	})
	if err == nil {
		t.Error("expected error when repo.Create fails")
	}
}

func TestAuthService_Login_Success(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	plainPassword := "my-client-derived-auth-key"
	hash := mustHashAuthKey(plainPassword)

	// Pre-seed the user in the repo.
	user := &domain.User{
		ID:          uuid.New(),
		Email:       "carol@example.com",
		Username:    "carol",
		AuthKeyHash: hash,
		Plan:        "free",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	repo.users[user.Email] = user
	repo.usersByID[user.ID] = user

	resp, err := svc.Login(context.Background(), domain.LoginRequest{
		Email:       "carol@example.com",
		AuthKeyHash: []byte(plainPassword),
	})
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	if resp.AccessToken == "" {
		t.Error("AccessToken should not be empty")
	}
	if resp.User.Email != "carol@example.com" {
		t.Errorf("User.Email = %q, want %q", resp.User.Email, "carol@example.com")
	}
}

func TestAuthService_Login_WrongPassword(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	hash := mustHashAuthKey("correct-password")
	user := &domain.User{
		ID:          uuid.New(),
		Email:       "dave@example.com",
		Username:    "dave",
		AuthKeyHash: hash,
		Plan:        "free",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	repo.users[user.Email] = user
	repo.usersByID[user.ID] = user

	_, err := svc.Login(context.Background(), domain.LoginRequest{
		Email:       "dave@example.com",
		AuthKeyHash: []byte("wrong-password"),
	})
	if !errors.Is(err, ErrInvalidCredentials) {
		t.Errorf("Login error = %v, want ErrInvalidCredentials", err)
	}
}

func TestAuthService_Login_UserNotFound(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	_, err := svc.Login(context.Background(), domain.LoginRequest{
		Email:       "nonexistent@example.com",
		AuthKeyHash: []byte("whatever"),
	})
	if !errors.Is(err, ErrInvalidCredentials) {
		t.Errorf("Login error = %v, want ErrInvalidCredentials", err)
	}
}

func TestAuthService_RefreshToken_Success(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	// Generate a valid refresh token via the service's Register path.
	resp, err := svc.Register(context.Background(), domain.RegisterRequest{
		Email:       "erin@example.com",
		Username:    "erin",
		AuthKeyHash: mustHashAuthKey("key"),
		Salt:        []byte("salt"),
		RecoveryKey: []byte("recovery"),
	})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}

	refreshed, err := svc.RefreshToken(context.Background(), resp.RefreshToken)
	if err != nil {
		t.Fatalf("RefreshToken: %v", err)
	}
	if refreshed.AccessToken == "" {
		t.Error("refreshed AccessToken should not be empty")
	}
	if refreshed.User.Email != "erin@example.com" {
		t.Errorf("User.Email = %q, want %q", refreshed.User.Email, "erin@example.com")
	}
}

func TestAuthService_RefreshToken_InvalidToken(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	_, err := svc.RefreshToken(context.Background(), "this-is-not-a-jwt")
	if !errors.Is(err, ErrInvalidCredentials) {
		t.Errorf("RefreshToken error = %v, want ErrInvalidCredentials", err)
	}
}

func TestAuthService_RefreshToken_ExpiredToken(t *testing.T) {
	repo := newMockUserRepo()
	// Use a very short expiry so the token is immediately expired.
	svc := NewAuthService(repo, testJWTSecret, 1*time.Nanosecond, 1*time.Nanosecond)

	resp, err := svc.Register(context.Background(), domain.RegisterRequest{
		Email:       "frank@example.com",
		Username:    "frank",
		AuthKeyHash: mustHashAuthKey("key"),
		Salt:        []byte("salt"),
		RecoveryKey: []byte("recovery"),
	})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}

	// Wait for the token to expire.
	time.Sleep(5 * time.Millisecond)

	_, err = svc.RefreshToken(context.Background(), resp.RefreshToken)
	if err == nil {
		t.Error("expected error for expired refresh token")
	}
}

func TestAuthService_GetCurrentUser_Success(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	user := &domain.User{
		ID:          uuid.New(),
		Email:       "grace@example.com",
		Username:    "grace",
		Plan:        "pro",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	repo.users[user.Email] = user
	repo.usersByID[user.ID] = user

	got, err := svc.GetCurrentUser(context.Background(), user.ID)
	if err != nil {
		t.Fatalf("GetCurrentUser: %v", err)
	}
	if got.Email != "grace@example.com" {
		t.Errorf("Email = %q, want %q", got.Email, "grace@example.com")
	}
}

func TestAuthService_GetCurrentUser_NotFound(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	_, err := svc.GetCurrentUser(context.Background(), uuid.New())
	if err == nil {
		t.Error("expected error for non-existent user")
	}
}

func TestAuthService_RefreshToken_RejectsAccessToken(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	// Register to get a token pair.
	resp, err := svc.Register(context.Background(), domain.RegisterRequest{
		Email:       "heidi@example.com",
		Username:    "heidi",
		AuthKeyHash: mustHashAuthKey("key"),
		Salt:        []byte("salt"),
		RecoveryKey: []byte("recovery"),
	})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}

	// Using the access token as a refresh token should fail.
	_, err = svc.RefreshToken(context.Background(), resp.AccessToken)
	if !errors.Is(err, ErrInvalidTokenType) {
		t.Errorf("RefreshToken with access token: error = %v, want ErrInvalidTokenType", err)
	}
}

func TestAuthService_GeneratedTokensContainType(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	resp, err := svc.Register(context.Background(), domain.RegisterRequest{
		Email:       "ivan@example.com",
		Username:    "ivan",
		AuthKeyHash: mustHashAuthKey("key"),
		Salt:        []byte("salt"),
		RecoveryKey: []byte("recovery"),
	})
	if err != nil {
		t.Fatalf("Register: %v", err)
	}

	// Parse access token and verify token_type claim.
	accessClaims := parseTokenClaims(t, resp.AccessToken, testJWTSecret)
	if tt, _ := accessClaims["token_type"].(string); tt != "access" {
		t.Errorf("access token token_type = %q, want %q", tt, "access")
	}

	// Parse refresh token and verify token_type claim.
	refreshClaims := parseTokenClaims(t, resp.RefreshToken, testJWTSecret)
	if tt, _ := refreshClaims["token_type"].(string); tt != "refresh" {
		t.Errorf("refresh token token_type = %q, want %q", tt, "refresh")
	}
}

// parseTokenClaims is a test helper that parses a JWT and returns its claims.
func parseTokenClaims(t *testing.T, tokenStr, secret string) jwt.MapClaims {
	t.Helper()
	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})
	if err != nil {
		t.Fatalf("parse token: %v", err)
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		t.Fatal("token claims are not MapClaims")
	}
	return claims
}

// ---------------------------------------------------------------------------
// Tests: DeleteAccount
// ---------------------------------------------------------------------------

func TestAuthService_DeleteAccount_Success(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	plainKey := "my-client-derived-auth-key"
	hash := mustHashAuthKey(plainKey)

	user := &domain.User{
		ID:          uuid.New(),
		Email:       "judy@example.com",
		Username:    "judy",
		AuthKeyHash: hash,
		Plan:        "free",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	repo.users[user.Email] = user
	repo.usersByID[user.ID] = user

	err := svc.DeleteAccount(context.Background(), user.ID, []byte(plainKey))
	if err != nil {
		t.Fatalf("DeleteAccount: %v", err)
	}

	// Verify user is gone from the repo.
	if _, ok := repo.usersByID[user.ID]; ok {
		t.Error("user should have been deleted from repo")
	}
}

func TestAuthService_DeleteAccount_WrongPassword(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	hash := mustHashAuthKey("correct-password")
	user := &domain.User{
		ID:          uuid.New(),
		Email:       "karl@example.com",
		Username:    "karl",
		AuthKeyHash: hash,
		Plan:        "free",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	repo.users[user.Email] = user
	repo.usersByID[user.ID] = user

	err := svc.DeleteAccount(context.Background(), user.ID, []byte("wrong-password"))
	if !errors.Is(err, ErrInvalidCredentials) {
		t.Errorf("DeleteAccount error = %v, want ErrInvalidCredentials", err)
	}

	// Verify user was NOT deleted.
	if _, ok := repo.usersByID[user.ID]; !ok {
		t.Error("user should still exist after wrong password")
	}
}

func TestAuthService_DeleteAccount_UserNotFound(t *testing.T) {
	repo := newMockUserRepo()
	svc := newTestAuthService(repo)

	err := svc.DeleteAccount(context.Background(), uuid.New(), []byte("some-key"))
	if !errors.Is(err, ErrUserNotFound) {
		t.Errorf("DeleteAccount error = %v, want ErrUserNotFound", err)
	}
}
