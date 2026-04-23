package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

const maxChatMessageContent = 100_000 // 100 KB per message

// maxChunkSize is the maximum allowed size for a single SSE chunk content.
// Chunks exceeding this limit are truncated to protect clients from oversized
// payloads from misbehaving LLM providers.
const maxChunkSize = 1 * 1024 * 1024 // 1 MB

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

	// Validate that each message has a recognized role.
	validRoles := map[string]bool{"system": true, "user": true, "assistant": true}
	for i, msg := range req.Messages {
		if !validRoles[msg.Role] {
			writeError(w, r, http.StatusBadRequest, "validation_error",
				fmt.Sprintf("Message %d has invalid role %q; valid roles: system, user, assistant", i+1, msg.Role))
			return
		}
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

	// Determine mode label from request: stream or sync.
	mode := aiModeSync
	if req.Stream {
		mode = aiModeStream
	}

	chunkCh, err := h.aiService.Proxy(r.Context(), userID.String(), req)
	if err != nil {
		if err == service.ErrQuotaExceeded {
			IncAIProxyRequest("", mode, "error")
			writeJSON(w, http.StatusTooManyRequests, domain.QuotaExceededResponse{
				Error:         "quota_exceeded",
				RetryAfter:    30,
				QueuePosition: 0,
			})
			return
		}
		IncAIProxyRequest("", mode, "error")
		writeError(w, r, http.StatusInternalServerError, "ai_error", "AI proxy failed")
		return
	}

	if req.Stream {
		IncAIActiveStreams()
		h.handleStream(w, r, chunkCh)
		DecAIActiveStreams()
	} else {
		h.handleNonStream(w, r, chunkCh)
	}
	IncAIProxyRequest("", mode, "success")
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

	for {
		select {
		case <-r.Context().Done():
			// Client disconnected; stop writing immediately.
			return
		case chunk, ok := <-chunkCh:
			if !ok {
				// Stream ended without Done marker
				fmt.Fprintf(w, "data: {\"done\":true}\n\n")
				flusher.Flush()
				return
			}
			if chunk.Error != "" {
				errorPayload, _ := json.Marshal(map[string]string{"error": chunk.Error})
				fmt.Fprintf(w, "event: error\ndata: %s\n\n", errorPayload)
				flusher.Flush()
				return
			}

			// Truncate oversized chunks before writing to SSE.
			content := chunk.Content
			if len(content) > maxChunkSize {
				slog.Warn("SSE chunk truncated: exceeds maxChunkSize",
					"original_size", len(content),
					"max_size", maxChunkSize,
				)
				content = content[:maxChunkSize]
			}

			data, _ := json.Marshal(map[string]interface{}{
				"content": content,
				"done":    chunk.Done,
			})
			fmt.Fprintf(w, "data: %s\n\n", data)
			flusher.Flush()

			if chunk.Done {
				return
			}
		}
	}
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
