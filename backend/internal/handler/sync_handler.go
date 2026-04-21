package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

type SyncHandler struct {
	syncService service.SyncService
}

func (h *SyncHandler) Pull(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	sinceStr := r.URL.Query().Get("since")
	since := 0
	if sinceStr != "" {
		if v, err := strconv.Atoi(sinceStr); err == nil {
			since = v
		}
	}

	if since < 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "since must be non-negative")
		return
	}

	// Parse optional cursor (last version from previous page, 0 = first page).
	cursorStr := r.URL.Query().Get("cursor")
	cursor := 0
	if cursorStr != "" {
		if v, err := strconv.Atoi(cursorStr); err == nil {
			cursor = v
		}
	}

	if cursor < 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "cursor must be non-negative")
		return
	}

	// Parse optional limit (default 100, max 500).
	limitStr := r.URL.Query().Get("limit")
	limit := 100
	if limitStr != "" {
		if v, err := strconv.Atoi(limitStr); err == nil {
			limit = v
		}
	}

	if limit < 1 {
		limit = 100
	} else if limit > 500 {
		limit = 500
	}

	resp, err := h.syncService.Pull(r.Context(), parseUUID(userID), since, limit, cursor)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "sync_error", "Pull failed")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) Push(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	defer r.Body.Close()

	var req domain.SyncPushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if len(req.Blobs) == 0 {
		writeJSON(w, http.StatusOK, domain.SyncPushResponse{Accepted: nil, Conflicts: nil})
		return
	}

	// Limit batch size
	if len(req.Blobs) > 1000 {
		writeError(w, r, http.StatusBadRequest, "batch_too_large", "Maximum 1000 items per push")
		return
	}

	resp, err := h.syncService.Push(r.Context(), parseUUID(userID), req)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "sync_error", "Push failed")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) Status(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	resp, err := h.syncService.GetStatus(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "sync_error", "Failed to get status")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) Stats(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	resp, err := h.syncService.GetStats(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "sync_error", "Failed to get sync stats")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) ListTags(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	resp, err := h.syncService.ListTags(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "sync_error", "Failed to list tags")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) BatchDelete(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	defer r.Body.Close()

	var req domain.BatchDeleteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if len(req.ItemIDs) == 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "item_ids must not be empty")
		return
	}

	if len(req.ItemIDs) > 1000 {
		writeError(w, r, http.StatusBadRequest, "batch_too_large", "Maximum 1000 items per batch delete")
		return
	}

	resp, err := h.syncService.BatchDelete(r.Context(), parseUUID(userID), req.ItemIDs)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "sync_error", "Batch delete failed")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) Progress(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	resp, err := h.syncService.GetProgress(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "sync_error", "Failed to get sync progress")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}
