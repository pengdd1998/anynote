package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/anynote/backend/internal/domain"
)

var (
	ErrEmailExists        = errors.New("email already exists")
	ErrUsernameExists     = errors.New("username already exists")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUserNotFound       = errors.New("user not found")
	ErrAccountDeletion    = errors.New("account deletion failed")
	ErrInvalidTokenType   = errors.New("invalid token type")
)

type AuthService interface {
	Register(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error)
	Login(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error)
	RefreshToken(ctx context.Context, refreshToken string) (*domain.AuthResponse, error)
	GetCurrentUser(ctx context.Context, userID uuid.UUID) (*domain.User, error)
	DeleteAccount(ctx context.Context, userID uuid.UUID, authKeyHash []byte) error
}

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
	Delete(ctx context.Context, id uuid.UUID) error
}

// deviceTokenDeleter removes device tokens for a user.
// Extracted as a minimal interface so the auth service does not depend on the
// full DeviceTokenRepository.
type deviceTokenDeleter interface {
	DeleteByUser(ctx context.Context, userID string) error
}

type authService struct {
	userRepo       UserRepository
	deviceTokens   deviceTokenDeleter
	jwtSecret      string
	tokenExpiry    time.Duration
	refreshExpiry  time.Duration
}

func NewAuthService(userRepo UserRepository, jwtSecret string, tokenExpiry, refreshExpiry time.Duration) AuthService {
	return &authService{
		userRepo:      userRepo,
		jwtSecret:     jwtSecret,
		tokenExpiry:   tokenExpiry,
		refreshExpiry: refreshExpiry,
	}
}

// NewAuthServiceWithDeviceTokens creates an AuthService that also cleans up
// device tokens on account deletion.
func NewAuthServiceWithDeviceTokens(userRepo UserRepository, dt deviceTokenDeleter, jwtSecret string, tokenExpiry, refreshExpiry time.Duration) AuthService {
	return &authService{
		userRepo:      userRepo,
		deviceTokens:  dt,
		jwtSecret:     jwtSecret,
		tokenExpiry:   tokenExpiry,
		refreshExpiry: refreshExpiry,
	}
}

func (s *authService) Register(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
	// Check email uniqueness
	if existing, _ := s.userRepo.GetByEmail(ctx, req.Email); existing != nil {
		return nil, ErrEmailExists
	}

	user := &domain.User{
		ID:          uuid.New(),
		Email:       req.Email,
		Username:    req.Username,
		AuthKeyHash: req.AuthKeyHash,
		Salt:        req.Salt,
		RecoveryKey: req.RecoveryKey,
		Plan:        "free",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, err
	}

	return s.generateAuthResponse(user)
}

func (s *authService) Login(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error) {
	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, ErrInvalidCredentials
	}

	// Compare auth key hash (client-derived)
	if err := bcrypt.CompareHashAndPassword(user.AuthKeyHash, req.AuthKeyHash); err != nil {
		return nil, ErrInvalidCredentials
	}

	return s.generateAuthResponse(user)
}

func (s *authService) RefreshToken(ctx context.Context, refreshToken string) (*domain.AuthResponse, error) {
	token, err := jwt.Parse(refreshToken, func(token *jwt.Token) (interface{}, error) {
		return []byte(s.jwtSecret), nil
	})
	if err != nil || !token.Valid {
		return nil, ErrInvalidCredentials
	}

	claims := token.Claims.(jwt.MapClaims)

	// Verify the token is a refresh token, not an access token.
	tokenType, _ := claims["token_type"].(string)
	if tokenType != "refresh" {
		return nil, ErrInvalidTokenType
	}

	userIDStr, ok := claims["user_id"].(string)
	if !ok {
		return nil, ErrInvalidCredentials
	}

	user, err := s.userRepo.GetByID(ctx, uuid.MustParse(userIDStr))
	if err != nil {
		return nil, ErrUserNotFound
	}

	return s.generateAuthResponse(user)
}

func (s *authService) GetCurrentUser(ctx context.Context, userID uuid.UUID) (*domain.User, error) {
	return s.userRepo.GetByID(ctx, userID)
}

// DeleteAccount verifies the provided auth key hash against the stored bcrypt
// hash and, on match, deletes the user and all associated data. Tables linked
// via ON DELETE CASCADE (sync_blobs, user_quotas, llm_configs, etc.) are
// automatically cleaned up by PostgreSQL. Device tokens require explicit
// deletion because the device_tokens table uses a TEXT user_id without FK.
func (s *authService) DeleteAccount(ctx context.Context, userID uuid.UUID, authKeyHash []byte) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return ErrUserNotFound
	}

	// Verify the caller knows the correct authentication key.
	if err := bcrypt.CompareHashAndPassword(user.AuthKeyHash, authKeyHash); err != nil {
		return ErrInvalidCredentials
	}

	// Clean up device tokens (no FK cascade for the device_tokens table).
	if s.deviceTokens != nil {
		if dtErr := s.deviceTokens.DeleteByUser(ctx, userID.String()); dtErr != nil {
			// Log but do not abort: the primary goal is deleting the user row,
			// which cascades to all FK-linked tables.
			slog.Warn("auth: failed to delete device tokens during account deletion",
				"user_id", userID.String(), "error", dtErr)
		}
	}

	if err := s.userRepo.Delete(ctx, userID); err != nil {
		return fmt.Errorf("delete user: %w", err)
	}

	return nil
}

func (s *authService) generateAuthResponse(user *domain.User) (*domain.AuthResponse, error) {
	now := time.Now()

	accessToken, err := s.generateToken(user, now, s.tokenExpiry, "access")
	if err != nil {
		return nil, err
	}

	refreshToken, err := s.generateToken(user, now, s.refreshExpiry, "refresh")
	if err != nil {
		return nil, err
	}

	return &domain.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresAt:    now.Add(s.tokenExpiry),
		User:         *user,
	}, nil
}

func (s *authService) generateToken(user *domain.User, now time.Time, expiry time.Duration, tokenType string) (string, error) {
	claims := jwt.MapClaims{
		"user_id":    user.ID.String(),
		"email":      user.Email,
		"plan":       user.Plan,
		"token_type": tokenType,
		"iat":        now.Unix(),
		"exp":        now.Add(expiry).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}
