package service

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

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
// When an FCMClient is provided, notifications are delivered via Firebase Cloud Messaging.
// When FCMClient is nil, the service operates in log-only mode.
type PushService interface {
	// SendPush sends a notification to a specific user's devices.
	SendPush(ctx context.Context, userID string, payload PushPayload) error
	// RegisterDevice registers a device token for push notifications.
	RegisterDevice(ctx context.Context, userID string, token string, platform string) error
	// UnregisterDevice removes a device token.
	UnregisterDevice(ctx context.Context, token string) error
}

// FCMClient abstracts Firebase Cloud Messaging for testability.
// Implementations wrap the firebase.google.com/go/v4/messaging.Client.
type FCMClient interface {
	// Send delivers a message to FCM and returns the message ID on success.
	Send(ctx context.Context, message *FCMMessage) (string, error)
}

// FCMMessage represents a push notification message sent to a single device token.
// This is a clean domain type that avoids importing the Firebase SDK in the service layer.
type FCMMessage struct {
	Token     string                 // Device registration token
	Title     string                 // Notification title
	Body      string                 // Notification body
	Data      map[string]string      // Arbitrary key-value data payload
	Priority  string                 // "high" or "normal"
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
	fcm  FCMClient // nil means log-only mode
}

// NewPushService creates a new push notification service.
// Pass a nil FCMClient to operate in log-only mode (no actual push delivery).
func NewPushService(repo DeviceTokenRepository, fcm FCMClient) PushService {
	return &pushService{repo: repo, fcm: fcm}
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

	// When no FCM client is configured, fall back to log-only mode.
	if s.fcm == nil {
		for _, device := range devices {
			slog.Info("push notification (log-only)",
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

	// Deliver via FCM for each registered device.
	for _, device := range devices {
		data := convertDataToStringMap(payload.Data)
		msg := &FCMMessage{
			Token:    device.Token,
			Title:    payload.Title,
			Body:     payload.Body,
			Data:     data,
			Priority: payload.Priority,
		}

		_, err := s.fcm.Send(ctx, msg)
		if err != nil {
			if isUnregisteredError(err) {
				// Stale token: remove from database and continue.
				slog.Warn("removing stale device token",
					"token_prefix", tokenPrefix(device.Token),
					"user_id", userID,
					"error", err,
				)
				if delErr := s.repo.DeleteByToken(ctx, device.Token); delErr != nil {
					slog.Error("failed to delete stale token",
						"token_prefix", tokenPrefix(device.Token),
						"error", delErr,
					)
				}
				continue
			}

			// Log non-fatal errors for individual devices but do not abort
			// the entire batch -- other devices may still be reachable.
			slog.Error("failed to send push notification",
				"user_id", userID,
				"device_id", device.ID.String(),
				"token_prefix", tokenPrefix(device.Token),
				"error", err,
			)
			continue
		}

		slog.Debug("push notification sent",
			"user_id", userID,
			"device_id", device.ID.String(),
			"platform", device.Platform,
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

// convertDataToStringMap converts a map[string]interface{} to map[string]string
// for the FCM data payload. Each value is formatted via fmt.Sprint.
func convertDataToStringMap(in map[string]interface{}) map[string]string {
	if len(in) == 0 {
		return nil
	}
	out := make(map[string]string, len(in))
	for k, v := range in {
		out[k] = fmt.Sprint(v)
	}
	return out
}

// isUnregisteredError checks whether the FCM error indicates an unregistered
// device token (e.g. "UNREGISTERED" or "invalid-registration-token").
// This handles both the firebase.google.com/go/v4/messaging error type
// (when wrapped) and string-matching as a safe fallback.
func isUnregisteredError(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "UNREGISTERED") ||
		strings.Contains(msg, "invalid-registration-token") ||
		strings.Contains(msg, "NotRegistered")
}
