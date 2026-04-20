package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"github.com/hibiken/asynq"

	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/service"
)

// PublishJobPayload is the structured payload for publish jobs.
type PublishJobPayload struct {
	UserID           string   `json:"user_id"`
	Platform         string   `json:"platform"`
	PublishLogID     string   `json:"publish_log_id"`
	Title            string   `json:"title"`
	Content          string   `json:"content"`
	Tags             []string `json:"tags"`
	EncryptedAuthRef string   `json:"encrypted_auth_ref,omitempty"`
}

// PublishJobHandler processes publish jobs by loading the platform adapter,
// decrypting stored auth data, and executing the publish operation.
type PublishJobHandler struct {
	registry    *platform.Registry
	publishRepo service.PublishLogRepository
	platformRep service.PlatformConnectionRepository
	pushSvc     service.PushService // optional; nil means no push notifications
	masterKey   []byte
}

// NewPublishJobHandler creates a new publish job handler.
func NewPublishJobHandler(
	registry *platform.Registry,
	publishRepo service.PublishLogRepository,
	platformRep service.PlatformConnectionRepository,
	masterKey []byte,
	pushSvc ...service.PushService,
) *PublishJobHandler {
	h := &PublishJobHandler{
		registry:    registry,
		publishRepo: publishRepo,
		platformRep: platformRep,
		masterKey:   masterKey,
	}
	if len(pushSvc) > 0 {
		h.pushSvc = pushSvc[0]
	}
	return h
}

// HandleTask is the asynq handler function for publish tasks.
func (h *PublishJobHandler) HandleTask(ctx context.Context, t *asynq.Task) error {
	var payload PublishJobPayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		slog.Error("publish job: failed to unmarshal payload", "error", err)
		return fmt.Errorf("unmarshal payload: %w", err)
	}

	logID, err := uuid.Parse(payload.PublishLogID)
	if err != nil {
		slog.Error("publish job: invalid publish log ID", "publish_log_id", payload.PublishLogID)
		return nil // Non-retriable
	}

	userID, err := uuid.Parse(payload.UserID)
	if err != nil {
		slog.Error("publish job: invalid user ID", "user_id", payload.UserID)
		return nil // Non-retriable
	}

	slog.Info("processing publish job",
		"user_id", payload.UserID,
		"platform", payload.Platform,
		"publish_log_id", payload.PublishLogID,
	)

	// Update status to publishing
	if err := h.publishRepo.UpdateStatus(ctx, logID, "publishing", "", ""); err != nil {
		slog.Error("publish job: failed to update status to publishing",
			"publish_log_id", payload.PublishLogID, "error", err,
		)
	}

	// Load platform adapter
	adapter, err := h.registry.Get(payload.Platform)
	if err != nil {
		slog.Error("publish job: unsupported platform",
			"platform", payload.Platform, "error", err,
		)
		_ = h.publishRepo.UpdateStatus(ctx, logID, "failed", fmt.Sprintf("unsupported platform: %s", payload.Platform), "")
		return nil // Non-retriable
	}

	// Load encrypted auth data from the platform_connections table.
	conn, err := h.platformRep.GetByPlatform(ctx, userID, payload.Platform)
	if err != nil {
		slog.Error("publish job: platform not connected",
			"user_id", payload.UserID, "platform", payload.Platform, "error", err,
		)
		_ = h.publishRepo.UpdateStatus(ctx, logID, "failed", "platform not connected", "")
		return nil // Non-retriable
	}

	if len(conn.EncryptedAuth) == 0 {
		slog.Error("publish job: no auth data stored",
			"user_id", payload.UserID, "platform", payload.Platform,
		)
		_ = h.publishRepo.UpdateStatus(ctx, logID, "failed", "platform authentication expired", "")
		return nil // Non-retriable
	}

	// Execute publish using the encrypted auth data.
	// The adapter internally decrypts the auth data using the master key.
	params := platform.PublishParams{
		Title:   payload.Title,
		Content: payload.Content,
		Tags:    payload.Tags,
	}

	result, err := adapter.Publish(ctx, conn.EncryptedAuth, h.masterKey, params)
	if err != nil {
		slog.Error("publish job: publish failed",
			"platform", payload.Platform, "error", err,
		)
		_ = h.publishRepo.UpdateStatus(ctx, logID, "failed", err.Error(), "")

		// Notify the user that publishing failed.
		h.sendPublishPush(context.Background(), payload.UserID, payload.Platform, payload.PublishLogID, false, err.Error())

		// Retriable: return error to asynq so it retries up to MaxRetry
		return fmt.Errorf("publish failed: %w", err)
	}

	// Update status to published
	platformURL := ""
	platformPostID := ""
	if result != nil {
		platformURL = result.PlatformURL
		platformPostID = result.PlatformID
	}
	if err := h.publishRepo.UpdateStatus(ctx, logID, "published", "", platformURL); err != nil {
		slog.Error("publish job: failed to update status to published",
			"publish_log_id", payload.PublishLogID, "error", err,
		)
	}

	slog.Info("publish job completed",
		"publish_log_id", payload.PublishLogID,
		"platform", payload.Platform,
		"platform_url", platformURL,
		"platform_post_id", platformPostID,
	)

	// Notify the user that publishing succeeded.
	h.sendPublishPush(context.Background(), payload.UserID, payload.Platform, payload.PublishLogID, true, "")

	return nil
}

// sendPublishPush sends a push notification to the user about a publish result.
// Errors are logged but never propagated to avoid interfering with the job outcome.
func (h *PublishJobHandler) sendPublishPush(ctx context.Context, userID, platform, publishLogID string, success bool, errMsg string) {
	if h.pushSvc == nil {
		return
	}

	var title, body string
	if success {
		title = "Publish Complete"
		body = fmt.Sprintf("Your note has been published to %s", platform)
	} else {
		title = "Publish Failed"
		body = fmt.Sprintf("Failed to publish to %s: %s", platform, errMsg)
	}

	payload := service.PushPayload{
		Title:    title,
		Body:     body,
		Priority: "normal",
		Data: map[string]interface{}{
			"type":           "publish_result",
			"platform":       platform,
			"publish_log_id": publishLogID,
			"success":        success,
		},
	}

	if err := h.pushSvc.SendPush(ctx, userID, payload); err != nil {
		slog.Error("failed to send publish result push",
			"user_id", userID,
			"platform", platform,
			"success", success,
			"error", err,
		)
	}
}
