package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

const maxChatMessageContent = 100_000 // 100 KB per message

type AIHandler struct {
	aiService service.AIProxyService
	quotaSvc  service.QuotaService
}

func (h *AIHandler) Proxy(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	defer r.Body.Close()

	var req domain.AIProxyRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	// Per-field validation: limit message count to prevent abuse.
	if len(req.Messages) > 100 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Too many messages (max 100)")
		return
	}

	if len(req.Messages) == 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Messages are required")
		return
	}

	// Cap individual message content length.
	for i, msg := range req.Messages {
		if len(msg.Content) > maxChatMessageContent {
			writeError(w, r, http.StatusBadRequest, "validation_error",
				fmt.Sprintf("Message %d content exceeds maximum size (100 KB)", i+1))
			return
		}
	}

	// Cap max_tokens based on the user's quota plan.
	capForPlan := h.maxTokensCap(r.Context(), userID)
	if req.MaxTokens == nil || *req.MaxTokens == 0 {
		req.MaxTokens = &capForPlan
	} else if *req.MaxTokens > capForPlan {
		req.MaxTokens = &capForPlan
	}

	chunkCh, err := h.aiService.Proxy(r.Context(), userID.String(), req)
	if err != nil {
		if err == service.ErrQuotaExceeded {
			writeJSON(w, http.StatusTooManyRequests, domain.QuotaExceededResponse{
				Error:         "quota_exceeded",
				RetryAfter:    30,
				QueuePosition: 0,
			})
			return
		}
		writeError(w, r, http.StatusInternalServerError, "ai_error", "AI proxy failed")
		return
	}

	if req.Stream {
		h.handleStream(w, r, chunkCh)
	} else {
		h.handleNonStream(w, r, chunkCh)
	}
}

func (h *AIHandler) handleStream(w http.ResponseWriter, r *http.Request, chunkCh <-chan domain.StreamChunk) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, r, http.StatusInternalServerError, "streaming_not_supported", "")
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	for chunk := range chunkCh {
		if chunk.Error != "" {
			errorPayload, _ := json.Marshal(map[string]string{"error": chunk.Error})
			fmt.Fprintf(w, "event: error\ndata: %s\n\n", errorPayload)
			flusher.Flush()
			return
		}

		data, _ := json.Marshal(map[string]interface{}{
			"content": chunk.Content,
			"done":    chunk.Done,
		})
		fmt.Fprintf(w, "data: %s\n\n", data)
		flusher.Flush()

		if chunk.Done {
			return
		}
	}

	// Stream ended without Done marker
	fmt.Fprintf(w, "data: {\"done\":true}\n\n")
	flusher.Flush()
}

func (h *AIHandler) handleNonStream(w http.ResponseWriter, r *http.Request, chunkCh <-chan domain.StreamChunk) {
	var fullContent string
	for chunk := range chunkCh {
		if chunk.Error != "" {
			writeError(w, r, http.StatusInternalServerError, "ai_error", chunk.Error)
			return
		}
		fullContent += chunk.Content
		if chunk.Done {
			break
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"content": fullContent,
		"done":    true,
	})
}

const (
	maxTokensFree = 4096
	maxTokensPro  = 16384
)

// maxTokensCap returns the server-side max_tokens cap for the user's plan.
// Falls back to the free-tier cap on any error.
func (h *AIHandler) maxTokensCap(ctx context.Context, uid uuid.UUID) int {
	quota, err := h.quotaSvc.GetQuota(ctx, uid)
	if err != nil {
		return maxTokensFree
	}

	switch quota.Plan {
	case "pro", "lifetime":
		return maxTokensPro
	default:
		return maxTokensFree
	}
}

func (h *AIHandler) GetQuota(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	quota, err := h.quotaSvc.GetQuota(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "quota_error", "Failed to get quota")
		return
	}

	writeJSON(w, http.StatusOK, quota)
}
