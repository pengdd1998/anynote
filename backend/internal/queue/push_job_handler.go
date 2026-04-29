package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/hibiken/asynq"

	"github.com/anynote/backend/internal/service"
)

// PushJobHandler processes push notification jobs from the asynq queue.
type PushJobHandler struct {
	pushSvc service.PushService
}

// NewPushJobHandler creates a new push job handler.
func NewPushJobHandler(pushSvc service.PushService) *PushJobHandler {
	return &PushJobHandler{pushSvc: pushSvc}
}

// ProcessTask handles a push notification task.
func (h *PushJobHandler) ProcessTask(ctx context.Context, t *asynq.Task) error {
	var payload PushPayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		return fmt.Errorf("unmarshal push payload: %w", err)
	}

	if payload.UserID == "" {
		slog.Warn("push job missing user_id, skipping")
		return nil // Don't retry
	}

	// Convert map[string]string to map[string]interface{} for service.PushPayload.
	data := make(map[string]interface{}, len(payload.Data))
	for k, v := range payload.Data {
		data[k] = v
	}

	err := h.pushSvc.SendPush(ctx, payload.UserID, service.PushPayload{
		Title: payload.Title,
		Body:  payload.Body,
		Data:  data,
	})
	if err != nil {
		return fmt.Errorf("send push: %w", err) // Will be retried by asynq
	}

	slog.Info("push notification sent", "user_id", payload.UserID)
	return nil
}
