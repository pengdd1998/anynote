// Package service implements business logic for the AnyNote API.
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
	ErrInvalidToken       = errors.New("invalid token")
	ErrUserNotFound       = errors.New("user not found")
	ErrAccountDeletion    = errors.New("account deletion failed")
	ErrInvalidTokenType   = errors.New("invalid token type")
	ErrTokenRevoked       = errors.New("refresh token has been revoked")
	ErrInvalidRecoveryKey = errors.New("invalid recovery key")
)

type AuthService interface {
	Register(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error)
	Login(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error)
	RefreshToken(ctx context.Context, refreshToken string) (*domain.AuthResponse, error)
	GetCurrentUser(ctx context.Context, userID uuid.UUID) (*domain.User, error)
	DeleteAccount(ctx context.Context, userID uuid.UUID, authKeyHash []byte) error
	GetRecoverySalt(ctx context.Context, userID uuid.UUID) (*domain.RecoverySaltResponse, error)
	GetRecoverySaltByEmail(ctx context.Context, email string) (*domain.RecoverySaltResponse, error)
	RecoverAccount(ctx context.Context, req *domain.RecoverRequest) error
}

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
	Delete(ctx context.Context, id uuid.UUID) error
	GetRecoverySalt(ctx context.Context, id uuid.UUID) ([]byte, error)
	GetRecoverySaltByEmail(ctx context.Context, email string) ([]byte, error)
	UpdateAuthCredentials(ctx context.Context, userID uuid.UUID, hashedPassword, salt string) error
	GetRecoveryKeyByEmail(ctx context.Context, email string) ([]byte, error)
}

// deviceTokenDeleter removes device tokens for a user.
// Extracted as a minimal interface so the auth service does not depend on the
// full DeviceTokenRepository.
type deviceTokenDeleter interface {
	DeleteByUser(ctx context.Context, userID string) error
}

// RefreshTokenStore defines the operations needed for refresh token rotation.
// Implementations persist token records so that reuse can be detected and
// tokens can be revoked on logout or password change.
type RefreshTokenStore interface {
	// Store persists a new refresh token record.
	Store(ctx context.Context, userID uuid.UUID, tokenID string, expiresAt time.Time) error
	// Revoke marks a single refresh token as revoked. Returns whether the
	// token existed and was successfully revoked.
	Revoke(ctx context.Context, tokenID string) (bool, error)
	// IsRevoked reports whether a refresh token has been revoked.
	IsRevoked(ctx context.Context, tokenID string) (bool, error)
	// RevokeAllForUser revokes every active refresh token for a user.
	RevokeAllForUser(ctx context.Context, userID uuid.UUID) error
}

type authService struct {
	userRepo         UserRepository
	deviceTokens     deviceTokenDeleter
	refreshTokenStore RefreshTokenStore
	jwtSecret        string
	tokenExpiry      time.Duration
	refreshExpiry    time.Duration
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
// device tokens on account deletion. The refreshTokenStore enables token
// rotation: when set, the service tracks issued refresh tokens and rejects
// reuse of previously-rotated tokens.
func NewAuthServiceWithDeviceTokens(userRepo UserRepository, dt deviceTokenDeleter, rts RefreshTokenStore, jwtSecret string, tokenExpiry, refreshExpiry time.Duration) AuthService {
	return &authService{
		userRepo:          userRepo,
		deviceTokens:      dt,
		refreshTokenStore: rts,
		jwtSecret:         jwtSecret,
		tokenExpiry:       tokenExpiry,
		refreshExpiry:     refreshExpiry,
	}
}

func (s *authService) Register(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
	// Check email uniqueness
	if existing, _ := s.userRepo.GetByEmail(ctx, req.Email); existing != nil {
		return nil, ErrEmailExists
	}

	user := &domain.User{
		ID:           uuid.New(),
		Email:        req.Email,
		Username:     req.Username,
		AuthKeyHash:  req.AuthKeyHash,
		Salt:         req.Salt,
		RecoveryKey:  req.RecoveryKey,
		RecoverySalt: req.RecoverySalt,
		Plan:         "free",
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, err
	}

	resp, err := s.generateAuthResponse(user)
	if err != nil {
		return nil, err
	}

	// Persist the refresh token when rotation tracking is enabled.
	if s.refreshTokenStore != nil {
		jti := s.extractJTI(resp.RefreshToken)
		if jti != "" {
			if storeErr := s.refreshTokenStore.Store(ctx, user.ID, jti, time.Now().Add(s.refreshExpiry)); storeErr != nil {
				slog.Warn("auth: failed to store refresh token on register", "user_id", user.ID.String(), "error", storeErr)
			}
		}
	}

	return resp, nil
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

	resp, err := s.generateAuthResponse(user)
	if err != nil {
		return nil, err
	}

	// Persist the refresh token when rotation tracking is enabled.
	if s.refreshTokenStore != nil {
		jti := s.extractJTI(resp.RefreshToken)
		if jti != "" {
			if storeErr := s.refreshTokenStore.Store(ctx, user.ID, jti, time.Now().Add(s.refreshExpiry)); storeErr != nil {
				slog.Warn("auth: failed to store refresh token on login", "user_id", user.ID.String(), "error", storeErr)
			}
		}
	}

	return resp, nil
}

func (s *authService) RefreshToken(ctx context.Context, refreshToken string) (*domain.AuthResponse, error) {
	token, err := jwt.Parse(refreshToken, func(token *jwt.Token) (interface{}, error) {
		return []byte(s.jwtSecret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !token.Valid {
		return nil, ErrInvalidCredentials
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, ErrInvalidToken
	}

	// Verify the token is a refresh token, not an access token.
	tokenType, _ := claims["token_type"].(string)
	if tokenType != "refresh" {
		return nil, ErrInvalidTokenType
	}

	// Check if the token has been revoked (when rotation tracking is enabled).
	oldJTI, _ := claims["jti"].(string)
	if s.refreshTokenStore != nil && oldJTI != "" {
		revoked, revErr := s.refreshTokenStore.IsRevoked(ctx, oldJTI)
		if revErr != nil {
			slog.Warn("auth: failed to check refresh token revocation", "error", revErr)
		}
		if revoked {
			return nil, ErrTokenRevoked
		}
	}

	userIDStr, ok := claims["user_id"].(string)
	if !ok {
		return nil, ErrInvalidCredentials
	}

	userID := uuid.MustParse(userIDStr)
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, ErrUserNotFound
	}

	resp, err := s.generateAuthResponse(user)
	if err != nil {
		return nil, err
	}

	// Rotate: revoke the old token and persist the new one.
	if s.refreshTokenStore != nil {
		// Revoke the old token.
		if oldJTI != "" {
			if _, revokeErr := s.refreshTokenStore.Revoke(ctx, oldJTI); revokeErr != nil {
				slog.Warn("auth: failed to revoke old refresh token during rotation",
					"user_id", userID.String(), "error", revokeErr)
			}
		}
		// Store the new token.
		newJTI := s.extractJTI(resp.RefreshToken)
		if newJTI != "" {
			if storeErr := s.refreshTokenStore.Store(ctx, userID, newJTI, time.Now().Add(s.refreshExpiry)); storeErr != nil {
				slog.Warn("auth: failed to store new refresh token during rotation",
					"user_id", userID.String(), "error", storeErr)
			}
		}
	}

	return resp, nil
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

	// Revoke all refresh tokens for this user (best-effort cleanup).
	if s.refreshTokenStore != nil {
		if rtErr := s.refreshTokenStore.RevokeAllForUser(ctx, userID); rtErr != nil {
			slog.Warn("auth: failed to revoke refresh tokens during account deletion",
				"user_id", userID.String(), "error", rtErr)
		}
	}

	if err := s.userRepo.Delete(ctx, userID); err != nil {
		return fmt.Errorf("delete user: %w", err)
	}

	return nil
}

// GetRecoverySalt returns the per-user random recovery salt.  Returns nil
// RecoverySalt for legacy accounts that were created before this field
// existed -- the client will fall back to deterministic derivation.
func (s *authService) GetRecoverySalt(ctx context.Context, userID uuid.UUID) (*domain.RecoverySaltResponse, error) {
	salt, err := s.userRepo.GetRecoverySalt(ctx, userID)
	if err != nil {
		return nil, ErrUserNotFound
	}
	return &domain.RecoverySaltResponse{RecoverySalt: salt}, nil
}

// GetRecoverySaltByEmail returns the per-user random recovery salt by email.
// This is used during account recovery when the user is not authenticated.
func (s *authService) GetRecoverySaltByEmail(ctx context.Context, email string) (*domain.RecoverySaltResponse, error) {
	salt, err := s.userRepo.GetRecoverySaltByEmail(ctx, email)
	if err != nil {
		return nil, ErrUserNotFound
	}
	return &domain.RecoverySaltResponse{RecoverySalt: salt}, nil
}

// RecoverAccount verifies the recovery key against the stored hash and updates
// the user's password credentials. The recovery key comparison uses
// bcrypt.CompareHashAndPassword because the stored recovery_key was hashed
// with bcrypt during registration.
func (s *authService) RecoverAccount(ctx context.Context, req *domain.RecoverRequest) error {
	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return ErrUserNotFound
	}

	// Verify the provided recovery key against the stored bcrypt hash.
	if err := bcrypt.CompareHashAndPassword(user.RecoveryKey, []byte(req.RecoveryKey)); err != nil {
		return ErrInvalidRecoveryKey
	}

	// Hash the new password and update credentials.
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
	if err != nil {
		return fmt.Errorf("hash new password: %w", err)
	}

	// The salt parameter is set to empty string because the client derives its
	// own salt during the recovery flow. The server only stores the hashed
	// auth key.
	if err := s.userRepo.UpdateAuthCredentials(ctx, user.ID, string(hashedPassword), ""); err != nil {
		return fmt.Errorf("update credentials: %w", err)
	}

	// Revoke all refresh tokens so other sessions are terminated.
	if s.refreshTokenStore != nil {
		if rtErr := s.refreshTokenStore.RevokeAllForUser(ctx, user.ID); rtErr != nil {
			slog.Warn("auth: failed to revoke refresh tokens during account recovery",
				"user_id", user.ID.String(), "error", rtErr)
		}
	}

	return nil
}

func (s *authService) generateAuthResponse(user *domain.User) (*domain.AuthResponse, error) {
	now := time.Now()

	accessToken, err := s.generateToken(user, now, s.tokenExpiry, "access", "")
	if err != nil {
		return nil, err
	}

	// Generate a unique ID for the refresh token so the store can track it.
	refreshTokenID := uuid.New().String()

	refreshToken, err := s.generateToken(user, now, s.refreshExpiry, "refresh", refreshTokenID)
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

func (s *authService) generateToken(user *domain.User, now time.Time, expiry time.Duration, tokenType string, jti string) (string, error) {
	claims := jwt.MapClaims{
		"user_id":    user.ID.String(),
		"email":      user.Email,
		"plan":       user.Plan,
		"token_type": tokenType,
		"iat":        now.Unix(),
		"exp":        now.Add(expiry).Unix(),
	}
	if jti != "" {
		claims["jti"] = jti
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}

// extractJTI parses a JWT token string and returns the "jti" claim, or an
// empty string if the claim is absent or the token cannot be parsed.
func (s *authService) extractJTI(tokenStr string) string {
	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		return []byte(s.jwtSecret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil {
		return ""
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return ""
	}
	jti, _ := claims["jti"].(string)
	return jti
}
