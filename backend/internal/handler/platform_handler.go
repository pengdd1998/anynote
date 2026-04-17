package handler

import (
	"encoding/json"
	"net/http"

	"github.com/anynote/backend/internal/service"
	"github.com/go-chi/chi/v5"
)

type PlatformHandler struct {
	platformService service.PlatformService
}

func (h *PlatformHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	connections, err := h.platformService.List(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "list_error", "Failed to list platforms")
		return
	}

	writeJSON(w, http.StatusOK, connections)
}

func (h *PlatformHandler) Connect(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platform := chi.URLParam(r, "platform")
	if platform == "" {
		writeError(w, http.StatusBadRequest, "missing_platform", "Platform name is required")
		return
	}

	conn, err := h.platformService.Connect(r.Context(), parseUUID(userID), platform)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "connect_error", "Failed to connect platform")
		return
	}

	writeJSON(w, http.StatusOK, conn)
}

func (h *PlatformHandler) Disconnect(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platform := chi.URLParam(r, "platform")
	if platform == "" {
		writeError(w, http.StatusBadRequest, "missing_platform", "Platform name is required")
		return
	}

	if err := h.platformService.Disconnect(r.Context(), parseUUID(userID), platform); err != nil {
		writeError(w, http.StatusInternalServerError, "disconnect_error", "Failed to disconnect platform")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *PlatformHandler) Verify(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platform := chi.URLParam(r, "platform")
	if platform == "" {
		writeError(w, http.StatusBadRequest, "missing_platform", "Platform name is required")
		return
	}

	conn, err := h.platformService.Verify(r.Context(), parseUUID(userID), platform)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]interface{}{
			"valid":  false,
			"error":  err.Error(),
		})
		return
	}

	writeJSON(w, http.StatusOK, conn)
}

// ── Helpers ────────────────────────────────────────

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, status int, errType, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(domain.ErrorResponse{
		Error:   errType,
		Message: message,
	})
}
