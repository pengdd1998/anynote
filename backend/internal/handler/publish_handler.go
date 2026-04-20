package handler

import (
	"encoding/json"
	"net/http"

	"github.com/anynote/backend/internal/service"
	"github.com/go-chi/chi/v5"
)

type PublishHandler struct {
	publishService service.PublishService
}

type publishRequest struct {
	Platform      string   `json:"platform"`
	ContentItemID string   `json:"content_item_id"`
	Title         string   `json:"title"`
	Content       string   `json:"content"`
	Tags          []string `json:"tags"`
	ScheduleAt    *string  `json:"schedule_at,omitempty"`
}

func (h *PublishHandler) Publish(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req publishRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.Platform == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Platform is required")
		return
	}

	log, err := h.publishService.Publish(r.Context(), parseUUID(userID), service.PublishRequest{
		Platform:      req.Platform,
		ContentItemID: req.ContentItemID,
		Title:         req.Title,
		Content:       req.Content,
		Tags:          req.Tags,
	})
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "publish_error", "Failed to publish")
		return
	}

	writeJSON(w, http.StatusAccepted, log)
}

func (h *PublishHandler) History(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	logs, err := h.publishService.GetHistory(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "history_error", "Failed to get history")
		return
	}

	writeJSON(w, http.StatusOK, logs)
}

func (h *PublishHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	id := chi.URLParam(r, "id")
	if id == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Publish log ID is required")
		return
	}

	log, err := h.publishService.GetByID(r.Context(), parseUUID(userID), parseUUID(id))
	if err != nil {
		writeError(w, r, http.StatusNotFound, "not_found", "Publish log not found")
		return
	}

	writeJSON(w, http.StatusOK, log)
}
