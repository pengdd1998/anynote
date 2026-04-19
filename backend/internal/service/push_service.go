package service

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
)

// PushPayload represents the content of a push notification.
type PushPayload struct {
	Title    string                 `json:"title"`
	Body     string                 `json:"body"`
	Data     map[string]interface{} `json:"data,omitempty"`
	Priority string                 `json:"priority,omitempty"` // "high" or "normal"
}

// PushService handles sending push notifications.
// In production, this would integrate with FCM (Android) and APNs (iOS).
// For now, implements the interface with logging.
type PushService interface {
	// SendPush sends a notification to a specific user's devices.
	SendPush(ctx context.Context, userID string, payload PushPayload) error
	// RegisterDevice registers a device token for push notifications.
	RegisterDevice(ctx context.Context, userID string, token string, platform string) error
	// UnregisterDevice removes a device token.
	UnregisterDevice(ctx context.Context, token string) error
}

// DeviceTokenRepository defines persistence operations for device tokens.
type DeviceTokenRepository interface {
	Create(ctx context.Context, id uuid.UUID, userID string, token string, platform string) error
	DeleteByToken(ctx context.Context, token string) error
	ListByUser(ctx context.Context, userID string) ([]DeviceTokenEntry, error)
}

// DeviceTokenEntry represents a registered device token.
type DeviceTokenEntry struct {
	ID        uuid.UUID `json:"id"`
	UserID    string    `json:"user_id"`
	Token     string    `json:"token"`
	Platform  string    `json:"platform"`
	CreatedAt string    `json:"created_at"`
}

type pushService struct {
	repo DeviceTokenRepository
}

// NewPushService creates a new push notification service.
// In production, FCM/APNs clients would be injected here.
func NewPushService(repo DeviceTokenRepository) PushService {
	return &pushService{repo: repo}
}

func (s *pushService) SendPush(ctx context.Context, userID string, payload PushPayload) error {
	// Look up all device tokens for this user.
	devices, err := s.repo.ListByUser(ctx, userID)
	if err != nil {
		return fmt.Errorf("list device tokens: %w", err)
	}

	if len(devices) == 0 {
		slog.Debug("no registered devices for user, skipping push", "user_id", userID)
		return nil
	}

	// In production, this would dispatch to FCM/APNs clients.
	// For now, log the notification for each device.
	for _, device := range devices {
		slog.Info("push notification",
			"user_id", userID,
			"device_id", device.ID.String(),
			"platform", device.Platform,
			"title", payload.Title,
			"body", payload.Body,
			"priority", payload.Priority,
		)
	}

	return nil
}

func (s *pushService) RegisterDevice(ctx context.Context, userID string, token string, platform string) error {
	id := uuid.New()
	if err := s.repo.Create(ctx, id, userID, token, platform); err != nil {
		return fmt.Errorf("register device token: %w", err)
	}

	slog.Info("device registered for push",
		"user_id", userID,
		"device_id", id.String(),
		"platform", platform,
	)
	return nil
}

func (s *pushService) UnregisterDevice(ctx context.Context, token string) error {
	if err := s.repo.DeleteByToken(ctx, token); err != nil {
		return fmt.Errorf("unregister device token: %w", err)
	}

	slog.Info("device unregistered from push", "token_prefix", tokenPrefix(token))
	return nil
}

// tokenPrefix returns the first 8 characters of a device token for logging.
// This avoids logging the full token which could be a security concern.
func tokenPrefix(token string) string {
	if len(token) > 8 {
		return token[:8] + "..."
	}
	return token
}
