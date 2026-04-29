package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/anynote/backend/internal/domain"
)

// Notification-related sentinel errors.
var (
	ErrNotificationNotFound = errors.New("notification not found")
)

// NotificationRepo defines the data access interface for notification operations.
type NotificationRepo interface {
	Create(ctx context.Context, n *domain.Notification) error
	GetByUser(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, error)
	GetUnreadCount(ctx context.Context, userID string) (int, error)
	MarkRead(ctx context.Context, id, userID string) error
	MarkAllRead(ctx context.Context, userID string) error
	Delete(ctx context.Context, id, userID string) error

	// Notification preferences (stored on users table).
	GetNotificationPreferences(ctx context.Context, userID string) (json.RawMessage, error)
	UpdateNotificationPreferences(ctx context.Context, userID string, prefs json.RawMessage) error
}

// NotificationService provides notification persistence business logic.
type NotificationService interface {
	CreateNotification(ctx context.Context, userID, nType, title, body string, data json.RawMessage) error
	ListNotifications(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, error)
	GetUnreadCount(ctx context.Context, userID string) (int, error)
	MarkRead(ctx context.Context, id, userID string) error
	MarkAllRead(ctx context.Context, userID string) error

	// Notification preferences.
	GetNotificationPreferences(ctx context.Context, userID string) (json.RawMessage, error)
	UpdateNotificationPreferences(ctx context.Context, userID string, prefs json.RawMessage) error
}

type notificationService struct {
	repo NotificationRepo
}

// NewNotificationService creates a new notification service.
func NewNotificationService(repo NotificationRepo) NotificationService {
	return &notificationService{repo: repo}
}

// validNotificationTypes is the set of recognised notification type values.
var validNotificationTypes = map[string]bool{
	"sync_conflict":     true,
	"share_received":    true,
	"reminder":          true,
	"system":            true,
	"payment":           true,
	"publish_started":   true,
	"publish_completed": true,
	"collab_invite":     true,
}

// CreateNotification validates the type and persists a new notification.
func (s *notificationService) CreateNotification(ctx context.Context, userID, nType, title, body string, data json.RawMessage) error {
	if !validNotificationTypes[nType] {
		return fmt.Errorf("invalid notification type: %s", nType)
	}

	if data == nil {
		data = json.RawMessage(`{}`)
	}

	n := &domain.Notification{
		UserID: userID,
		Type:   nType,
		Title:  title,
		Body:   body,
		Data:   data,
	}

	return s.repo.Create(ctx, n)
}

// ListNotifications returns paginated notifications for a user.
func (s *notificationService) ListNotifications(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	notifications, err := s.repo.GetByUser(ctx, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	if notifications == nil {
		return []domain.Notification{}, nil
	}
	return notifications, nil
}

// GetUnreadCount returns the number of unread notifications for a user.
func (s *notificationService) GetUnreadCount(ctx context.Context, userID string) (int, error) {
	return s.repo.GetUnreadCount(ctx, userID)
}

// MarkRead marks a single notification as read.
func (s *notificationService) MarkRead(ctx context.Context, id, userID string) error {
	err := s.repo.MarkRead(ctx, id, userID)
	if err != nil {
		return ErrNotificationNotFound
	}
	return nil
}

// MarkAllRead marks all notifications for a user as read.
func (s *notificationService) MarkAllRead(ctx context.Context, userID string) error {
	return s.repo.MarkAllRead(ctx, userID)
}

// GetNotificationPreferences returns the user's notification preferences as raw JSON.
func (s *notificationService) GetNotificationPreferences(ctx context.Context, userID string) (json.RawMessage, error) {
	prefs, err := s.repo.GetNotificationPreferences(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get notification preferences: %w", err)
	}
	return prefs, nil
}

// UpdateNotificationPreferences validates and persists the user's notification preferences.
// The prefs value must be a valid JSON object where all values are booleans.
func (s *notificationService) UpdateNotificationPreferences(ctx context.Context, userID string, prefs json.RawMessage) error {
	// Validate that prefs is a JSON object with boolean values only.
	var parsed map[string]bool
	if err := json.Unmarshal(prefs, &parsed); err != nil {
		return fmt.Errorf("invalid preferences: must be a JSON object with boolean values: %w", err)
	}

	// Re-marshal to ensure canonical form (no extra whitespace, sorted keys).
	canonical, err := json.Marshal(parsed)
	if err != nil {
		return fmt.Errorf("marshal preferences: %w", err)
	}

	if err := s.repo.UpdateNotificationPreferences(ctx, userID, canonical); err != nil {
		return fmt.Errorf("update notification preferences: %w", err)
	}
	return nil
}
