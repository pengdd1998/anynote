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
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	sinceStr := r.URL.Query().Get("since")
	since := 0
	if sinceStr != "" {
		if v, err := strconv.Atoi(sinceStr); err == nil {
			since = v
		}
	}

	resp, err := h.syncService.Pull(r.Context(), parseUUID(userID), since)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "sync_error", "Pull failed")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) Push(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.SyncPushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if len(req.Blobs) == 0 {
		writeJSON(w, http.StatusOK, domain.SyncPushResponse{Accepted: nil, Conflicts: nil})
		return
	}

	// Limit batch size
	if len(req.Blobs) > 1000 {
		writeError(w, http.StatusBadRequest, "batch_too_large", "Maximum 1000 items per push")
		return
	}

	resp, err := h.syncService.Push(r.Context(), parseUUID(userID), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "sync_error", "Push failed")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *SyncHandler) Status(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	resp, err := h.syncService.GetStatus(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "sync_error", "Failed to get status")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}
