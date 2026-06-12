// Package service implements business logic for the AnyNote API.
package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
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
)

type AuthService interface {
	Register(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error)
	Login(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error)
	RefreshToken(ctx context.Context, refreshToken string) (*domain.AuthResponse, error)
	GetCurrentUser(ctx context.Context, userID uuid.UUID) (*domain.User, error)
	DeleteAccount(ctx context.Context, userID uuid.UUID, authKeyHash []byte) error
	GetRecoverySalt(ctx context.Context, userID uuid.UUID) (*domain.RecoverySaltResponse, error)
	GetRecoverySaltByEmail(ctx context.Context, email string) (*domain.RecoverySaltResponse, error)
	GetSaltByEmail(ctx context.Context, email string) (*domain.SaltResponse, error)
	FakeSalt(email string) []byte
	FakeRecoverySalt(email string) []byte
	FakeEncryptedMasterKey(email string) []byte
}

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	GetByUsername(ctx context.Context, username string) (*domain.User, error)
	GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
	Delete(ctx context.Context, id uuid.UUID) error
	GetRecoverySalt(ctx context.Context, id uuid.UUID) ([]byte, error)
	GetRecoveryDataByEmail(ctx context.Context, email string) ([]byte, []byte, error)
	GetSaltByEmail(ctx context.Context, email string) ([]byte, error)
}

// deviceTokenDeleter removes device tokens for a user.
type deviceTokenDeleter interface {
	DeleteByUser(ctx context.Context, userID string) error
}

// RefreshTokenStore defines the operations needed for refresh token rotation.
type RefreshTokenStore interface {
	Store(ctx context.Context, userID uuid.UUID, tokenID string, expiresAt time.Time) error
	Revoke(ctx context.Context, tokenID string) (bool, error)
	IsRevoked(ctx context.Context, tokenID string) (bool, error)
	RevokeAllForUser(ctx context.Context, userID uuid.UUID) error
}

type authService struct {
	userRepo          UserRepository
	deviceTokens      deviceTokenDeleter
	refreshTokenStore RefreshTokenStore
	jwtSecret         string
	tokenExpiry       time.Duration
	refreshExpiry     time.Duration
}

func NewAuthService(userRepo UserRepository, jwtSecret string, tokenExpiry, refreshExpiry time.Duration) AuthService {
	return &authService{
		userRepo:      userRepo,
		jwtSecret:     jwtSecret,
		tokenExpiry:   tokenExpiry,
		refreshExpiry: refreshExpiry,
	}
}

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
	existing, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err == nil && existing != nil {
		return nil, ErrEmailExists
	}

	existing, err = s.userRepo.GetByUsername(ctx, req.Username)
	if err == nil && existing != nil {
		return nil, ErrUsernameExists
	}

	user := &domain.User{
		ID:                 uuid.New(),
		Email:              req.Email,
		Username:           req.Username,
		AuthKeyHash:        req.AuthKeyHash,
		Salt:               req.Salt,
		RecoveryKey:        []byte(req.RecoveryKey),
		RecoverySalt:       req.RecoverySalt,
		EncryptedMasterKey: req.EncryptedMasterKey,
		Plan:               "free",
		CreatedAt:          time.Now(),
		UpdatedAt:          time.Now(),
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		slog.Error("auth: failed to create user", "email", req.Email, "error", err)
		return nil, err
	}

	resp, err := s.generateAuthResponse(user)
	if err != nil {
		return nil, err
	}

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

	if err := bcrypt.CompareHashAndPassword(user.AuthKeyHash, req.AuthKeyHash); err != nil {
		return nil, ErrInvalidCredentials
	}

	resp, err := s.generateAuthResponse(user)
	if err != nil {
		return nil, err
	}

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

	tokenType, _ := claims["token_type"].(string)
	if tokenType != "refresh" {
		return nil, ErrInvalidTokenType
	}

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

	if s.refreshTokenStore != nil {
		if oldJTI != "" {
			if _, revokeErr := s.refreshTokenStore.Revoke(ctx, oldJTI); revokeErr != nil {
				slog.Warn("auth: failed to revoke old refresh token during rotation",
					"user_id", userID.String(), "error", revokeErr)
			}
		}
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

func (s *authService) DeleteAccount(ctx context.Context, userID uuid.UUID, authKeyHash []byte) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return ErrUserNotFound
	}

	if err := bcrypt.CompareHashAndPassword(user.AuthKeyHash, authKeyHash); err != nil {
		return ErrInvalidCredentials
	}

	if s.deviceTokens != nil {
		if dtErr := s.deviceTokens.DeleteByUser(ctx, userID.String()); dtErr != nil {
			slog.Warn("auth: failed to delete device tokens during account deletion",
				"user_id", userID.String(), "error", dtErr)
		}
	}

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

func (s *authService) GetRecoverySalt(ctx context.Context, userID uuid.UUID) (*domain.RecoverySaltResponse, error) {
	salt, err := s.userRepo.GetRecoverySalt(ctx, userID)
	if err != nil {
		return nil, ErrUserNotFound
	}
	return &domain.RecoverySaltResponse{RecoverySalt: salt}, nil
}

// GetRecoverySaltByEmail returns the per-user random recovery salt and
// encrypted master key by email. Used during account recovery when the
// user is not authenticated.
func (s *authService) GetRecoverySaltByEmail(ctx context.Context, email string) (*domain.RecoverySaltResponse, error) {
	salt, encMasterKey, err := s.userRepo.GetRecoveryDataByEmail(ctx, email)
	if err != nil {
		return nil, ErrUserNotFound
	}
	return &domain.RecoverySaltResponse{RecoverySalt: salt, EncryptedMasterKey: encMasterKey}, nil
}

func (s *authService) GetSaltByEmail(ctx context.Context, email string) (*domain.SaltResponse, error) {
	salt, err := s.userRepo.GetSaltByEmail(ctx, email)
	if err != nil {
		return nil, ErrUserNotFound
	}
	return &domain.SaltResponse{Salt: salt}, nil
}

func (s *authService) generateAuthResponse(user *domain.User) (*domain.AuthResponse, error) {
	now := time.Now()

	accessToken, err := s.generateToken(user, now, s.tokenExpiry, "access", "")
	if err != nil {
		return nil, err
	}

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

func (s *authService) FakeRecoverySalt(email string) []byte {
	mac := hmac.New(sha256.New, []byte(s.jwtSecret))
	mac.Write([]byte(email))
	return mac.Sum(nil)
}

// FakeEncryptedMasterKey returns a deterministic 72-byte fake blob for
// non-existing emails so that the response shape is indistinguishable from
// a real user's response.
func (s *authService) FakeEncryptedMasterKey(email string) []byte {
	// 72 bytes: 24 (nonce) + 32 (ciphertext) + 16 (tag)
	result := make([]byte, 0, 72)
	for i := 0; i < 3; i++ {
		mac := hmac.New(sha256.New, []byte(s.jwtSecret))
		mac.Write([]byte(fmt.Sprintf("enc-master-key:%d:%s", i, email)))
		result = append(result, mac.Sum(nil)...)
	}
	return result[:72]
}

func (s *authService) FakeSalt(email string) []byte {
	mac := hmac.New(sha256.New, []byte(s.jwtSecret))
	mac.Write([]byte("login-salt:" + email))
	return mac.Sum(nil)
}
