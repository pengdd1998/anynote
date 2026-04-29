package service

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/platform"
)

// sessionMaxAge is the maximum lifetime of an in-memory auth session.
// Sessions older than this are cleaned up by the background goroutine.
const sessionMaxAge = 5 * time.Minute

const statusActive = "active"

type PlatformService interface {
	List(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error)
	Connect(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error)
	Disconnect(ctx context.Context, userID uuid.UUID, platformName string) error
	Verify(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error)

	// StartAuth initiates a platform authentication flow.
	// Returns the QR code as PNG bytes for the caller to send to the client.
	StartAuth(ctx context.Context, userID uuid.UUID, platformName string, masterKey []byte) (string, []byte, error)

	// PollAuth checks if the user completed authentication.
	// Returns the encrypted auth data on success, or nil while still pending.
	PollAuth(ctx context.Context, userID uuid.UUID, platformName string, authRef string, masterKey []byte) ([]byte, error)

	// CancelAuth removes an in-memory auth session when the client disconnects
	// before the authentication flow completes.
	CancelAuth(userID uuid.UUID, platformName string, authRef string)

	// Publish publishes content to a platform.
	Publish(ctx context.Context, userID uuid.UUID, platformName string, req PlatformPublishRequest, masterKey []byte) (*domain.PublishLog, error)

	// CheckStatus checks the live status of a published post.
	CheckStatus(ctx context.Context, userID uuid.UUID, platformName string, platformID string, masterKey []byte) (string, error)

	// Stop terminates the background session cleanup goroutine.
	Stop()
}

type PlatformConnectionRepository interface {
	ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error)
	GetByPlatform(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error)
	Create(ctx context.Context, conn *domain.PlatformConnection) error
	Delete(ctx context.Context, id uuid.UUID) error
	Update(ctx context.Context, conn *domain.PlatformConnection) error
}

type platformService struct {
	platformRepo PlatformConnectionRepository
	registry     *platform.Registry

	// authSessions stores in-progress auth sessions keyed by authRef.
	authSessions sync.Map

	// stopCh signals the background cleanup goroutine to stop.
	stopCh chan struct{}
}

func NewPlatformService(platformRepo PlatformConnectionRepository, registry *platform.Registry) PlatformService {
	svc := &platformService{
		platformRepo: platformRepo,
		registry:     registry,
		stopCh:       make(chan struct{}),
	}

	// Start background session cleanup.
	go svc.cleanupExpiredSessions()

	return svc
}

// cleanupExpiredSessions runs a background loop that removes auth sessions
// older than sessionMaxAge every minute.
func (s *platformService) cleanupExpiredSessions() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			now := time.Now()
			s.authSessions.Range(func(key, value interface{}) bool {
				session, ok := value.(*storedAuthSession)
				if !ok {
					s.authSessions.Delete(key)
					return true
				}
				if now.Sub(session.createdAt) > sessionMaxAge {
					s.authSessions.Delete(key)
					slog.Debug("cleaned up expired platform auth session",
						"auth_ref", session.authRef,
						"platform", session.platform,
					)
				}
				return true
			})
		case <-s.stopCh:
			slog.Info("platform auth session cleanup goroutine stopped")
			return
		}
	}
}

// Stop signals the background cleanup goroutine to terminate.
func (s *platformService) Stop() {
	close(s.stopCh)
}

// CancelAuth removes an in-memory auth session when the client disconnects
// before completing the authentication flow.
func (s *platformService) CancelAuth(userID uuid.UUID, platformName string, authRef string) {
	sessionKey := authSessionKey(userID, platformName, authRef)
	s.authSessions.Delete(sessionKey)
}

func (s *platformService) List(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error) {
	return s.platformRepo.ListByUser(ctx, userID)
}

func (s *platformService) Connect(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
	// Check if already connected.
	existing, _ := s.platformRepo.GetByPlatform(ctx, userID, platformName)
	if existing != nil {
		return nil, fmt.Errorf("platform already connected")
	}

	conn := &domain.PlatformConnection{
		ID:            uuid.New(),
		UserID:        userID,
		Platform:      platformName,
		EncryptedAuth: []byte{},
		Status:        "pending",
	}

	if err := s.platformRepo.Create(ctx, conn); err != nil {
		return nil, err
	}

	return conn, nil
}

func (s *platformService) Disconnect(ctx context.Context, userID uuid.UUID, platformName string) error {
	conn, err := s.platformRepo.GetByPlatform(ctx, userID, platformName)
	if err != nil {
		return fmt.Errorf("platform not connected")
	}

	// Attempt platform-specific revocation (best-effort).
	adapter, adapterErr := s.registry.Get(platformName)
	if adapterErr == nil && len(conn.EncryptedAuth) > 0 {
		// Revocation does not need the master key for all platforms;
		// pass nil and let the adapter handle it gracefully.
		if revokeErr := adapter.RevokeAuth(ctx, conn.EncryptedAuth, nil); revokeErr != nil {
			slog.Warn("platform: revoke auth failed (best-effort)", "platform", platformName, "error", revokeErr)
		}
	}

	return s.platformRepo.Delete(ctx, conn.ID)
}

func (s *platformService) Verify(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
	conn, err := s.platformRepo.GetByPlatform(ctx, userID, platformName)
	if err != nil {
		return nil, fmt.Errorf("platform not connected")
	}

	// Update the last_verified timestamp.
	conn.Status = statusActive
	if err := s.platformRepo.Update(ctx, conn); err != nil {
		return nil, fmt.Errorf("update verification: %w", err)
	}

	return conn, nil
}

// StartAuth initiates the QR code authentication flow for a platform.
// Returns (authRef, qrCodePNG, error).
func (s *platformService) StartAuth(ctx context.Context, userID uuid.UUID, platformName string, masterKey []byte) (string, []byte, error) {
	adapter, err := s.registry.Get(platformName)
	if err != nil {
		return "", nil, err
	}

	session, qrPNG, err := adapter.StartAuth(ctx, masterKey)
	if err != nil {
		return "", nil, fmt.Errorf("start auth: %w", err)
	}

	// Store the session so PollAuth can retrieve it later.
	sessionKey := authSessionKey(userID, platformName, session.AuthRef)
	s.authSessions.Store(sessionKey, &storedAuthSession{
		userID:    userID,
		platform:  platformName,
		authRef:   session.AuthRef,
		cdpHandle: session,
		createdAt: time.Now(),
	})

	return session.AuthRef, qrPNG, nil
}

// PollAuth checks if the user has completed the platform authentication.
// Returns encrypted auth bytes on success, nil while still pending.
func (s *platformService) PollAuth(ctx context.Context, userID uuid.UUID, platformName string, authRef string, masterKey []byte) ([]byte, error) {
	sessionKey := authSessionKey(userID, platformName, authRef)
	val, ok := s.authSessions.Load(sessionKey)
	if !ok {
		return nil, fmt.Errorf("auth session not found or expired")
	}
	stored, ok := val.(*storedAuthSession)
		if !ok {
			return nil, fmt.Errorf("invalid auth session type")
		}

	adapter, err := s.registry.Get(platformName)
	if err != nil {
		return nil, err
	}

	encryptedAuth, err := adapter.PollAuth(ctx, stored.cdpHandle, masterKey)
	if err != nil {
		return nil, fmt.Errorf("poll auth: %w", err)
	}

	if encryptedAuth == nil {
		// Still pending.
		return nil, nil
	}

	// Auth succeeded.  Persist the encrypted auth data.
	conn, connErr := s.platformRepo.GetByPlatform(ctx, userID, platformName)
	if connErr != nil {
		// Create a new connection if one does not exist yet.
		conn = &domain.PlatformConnection{
			ID:       uuid.New(),
			UserID:   userID,
			Platform: platformName,
			Status:   statusActive,
		}
		conn.EncryptedAuth = encryptedAuth
		if createErr := s.platformRepo.Create(ctx, conn); createErr != nil {
			return nil, fmt.Errorf("create connection: %w", createErr)
		}
	} else {
		conn.EncryptedAuth = encryptedAuth
		conn.Status = statusActive
		if updateErr := s.platformRepo.Update(ctx, conn); updateErr != nil {
			return nil, fmt.Errorf("update connection: %w", updateErr)
		}
	}

	// Clean up the in-memory session.
	s.authSessions.Delete(sessionKey)

	return encryptedAuth, nil
}

// Publish publishes content to the specified platform.
func (s *platformService) Publish(ctx context.Context, userID uuid.UUID, platformName string, req PlatformPublishRequest, masterKey []byte) (*domain.PublishLog, error) {
	adapter, err := s.registry.Get(platformName)
	if err != nil {
		return nil, err
	}

	conn, err := s.platformRepo.GetByPlatform(ctx, userID, platformName)
	if err != nil {
		return nil, fmt.Errorf("platform not connected: %w", err)
	}

	if len(conn.EncryptedAuth) == 0 {
		return nil, fmt.Errorf("platform authentication expired, please reconnect")
	}

	images := make([]platform.ImageRef, 0, len(req.Images))
	for _, img := range req.Images {
		images = append(images, platform.ImageRef{
			URL:      img.URL,
			FilePath: img.FilePath,
		})
	}

	result, err := adapter.Publish(ctx, conn.EncryptedAuth, masterKey, platform.PublishParams{
		Title:   req.Title,
		Content: req.Content,
		Tags:    req.Tags,
		Images:  images,
	})
	if err != nil {
		return nil, fmt.Errorf("publish to %s: %w", platformName, err)
	}

	return &domain.PublishLog{
		ID:          uuid.New(),
		UserID:      userID,
		Platform:    platformName,
		Title:       req.Title,
		Content:     req.Content,
		Status:      "published",
		PlatformURL: result.PlatformURL,
	}, nil
}

// CheckStatus checks if a published post is still live.
func (s *platformService) CheckStatus(ctx context.Context, userID uuid.UUID, platformName string, platformID string, masterKey []byte) (string, error) {
	adapter, err := s.registry.Get(platformName)
	if err != nil {
		return "unknown", err
	}

	conn, err := s.platformRepo.GetByPlatform(ctx, userID, platformName)
	if err != nil {
		return "unknown", fmt.Errorf("platform not connected: %w", err)
	}

	return adapter.CheckStatus(ctx, conn.EncryptedAuth, masterKey, platformID)
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// storedAuthSession holds the in-memory state for an in-progress auth flow.
type storedAuthSession struct {
	userID    uuid.UUID
	platform  string
	authRef   string
	cdpHandle *platform.AuthSession
	createdAt time.Time
}

func authSessionKey(userID uuid.UUID, platformName, authRef string) string {
	return fmt.Sprintf("%s:%s:%s", userID.String(), platformName, authRef)
}

// PlatformPublishRequest is the request for publishing content to a platform.
type PlatformPublishRequest struct {
	Platform      string                  `json:"platform"`
	ContentItemID string                  `json:"content_item_id"`
	Title         string                  `json:"title"`
	Content       string                  `json:"content"`
	Tags          []string                `json:"tags"`
	Images        []PlatformPublishImage  `json:"images"`
}

// PlatformPublishImage references an image to include in a platform publish request.
type PlatformPublishImage struct {
	URL      string `json:"url"`
	FilePath string `json:"file_path"`
}
