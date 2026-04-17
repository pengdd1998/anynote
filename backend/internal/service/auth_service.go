package service

import (
	"context"
	"errors"
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
)

type AuthService interface {
	Register(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error)
	Login(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error)
	RefreshToken(ctx context.Context, refreshToken string) (*domain.AuthResponse, error)
	GetCurrentUser(ctx context.Context, userID uuid.UUID) (*domain.User, error)
}

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
}

type authService struct {
	userRepo   UserRepository
	jwtSecret  string
	tokenExpiry time.Duration
	refreshExpiry time.Duration
}

func NewAuthService(userRepo UserRepository, jwtSecret string, tokenExpiry, refreshExpiry time.Duration) AuthService {
	return &authService{
		userRepo:      userRepo,
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

func (s *authService) generateAuthResponse(user *domain.User) (*domain.AuthResponse, error) {
	now := time.Now()

	accessToken, err := s.generateToken(user, now, s.tokenExpiry)
	if err != nil {
		return nil, err
	}

	refreshToken, err := s.generateToken(user, now, s.refreshExpiry)
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

func (s *authService) generateToken(user *domain.User, now time.Time, expiry time.Duration) (string, error) {
	claims := jwt.MapClaims{
		"user_id": user.ID.String(),
		"email":   user.Email,
		"plan":    user.Plan,
		"iat":     now.Unix(),
		"exp":     now.Add(expiry).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}
