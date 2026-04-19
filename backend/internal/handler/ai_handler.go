package handler

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

type AIHandler struct {
	aiService service.AIProxyService
	quotaSvc  service.QuotaService
}

func (h *AIHandler) Proxy(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.AIProxyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if len(req.Messages) == 0 {
		writeError(w, http.StatusBadRequest, "validation_error", "Messages are required")
		return
	}

	chunkCh, err := h.aiService.Proxy(r.Context(), userID, req)
	if err != nil {
		if err == service.ErrQuotaExceeded {
			writeJSON(w, http.StatusTooManyRequests, domain.QuotaExceededResponse{
				Error:         "quota_exceeded",
				RetryAfter:    30,
				QueuePosition: 0,
			})
			return
		}
		writeError(w, http.StatusInternalServerError, "ai_error", "AI proxy failed")
		return
	}

	if req.Stream {
		h.handleStream(w, r, chunkCh)
	} else {
		h.handleNonStream(w, chunkCh)
	}
}

func (h *AIHandler) handleStream(w http.ResponseWriter, r *http.Request, chunkCh <-chan domain.StreamChunk) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, http.StatusInternalServerError, "streaming_not_supported", "")
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	for chunk := range chunkCh {
		if chunk.Error != "" {
			fmt.Fprintf(w, "event: error\ndata: {\"error\":\"%s\"}\n\n", chunk.Error)
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

func (h *AIHandler) handleNonStream(w http.ResponseWriter, chunkCh <-chan domain.StreamChunk) {
	var fullContent string
	for chunk := range chunkCh {
		if chunk.Error != "" {
			writeError(w, http.StatusInternalServerError, "ai_error", chunk.Error)
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

func (h *AIHandler) GetQuota(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	quota, err := h.quotaSvc.GetQuota(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "quota_error", "Failed to get quota")
		return
	}

	writeJSON(w, http.StatusOK, quota)
}
