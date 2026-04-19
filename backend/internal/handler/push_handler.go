package handler

import (
	"encoding/json"
	"net/http"

	"github.com/anynote/backend/internal/service"
)

// PushHandler handles device registration for push notifications.
type PushHandler struct {
	pushService service.PushService
}

// registerDeviceRequest is the expected body for POST /api/v1/devices/register.
type registerDeviceRequest struct {
	Token    string `json:"token"`
	Platform string `json:"platform"` // "android", "ios", "web"
}

// unregisterDeviceRequest is the expected body for POST /api/v1/devices/unregister.
type unregisterDeviceRequest struct {
	Token string `json:"token"`
}

// RegisterDeviceToken handles POST /api/v1/devices/register.
// Requires authentication. Registers a device token for push notifications.
func (h *PushHandler) RegisterDeviceToken(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req registerDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.Token == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "token is required")
		return
	}

	if req.Platform == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "platform is required")
		return
	}

	// Validate platform value.
	validPlatforms := map[string]bool{"android": true, "ios": true, "web": true}
	if !validPlatforms[req.Platform] {
		writeError(w, http.StatusBadRequest, "validation_error", "platform must be one of: android, ios, web")
		return
	}

	if err := h.pushService.RegisterDevice(r.Context(), userID, req.Token, req.Platform); err != nil {
		writeError(w, http.StatusInternalServerError, "register_error", "Failed to register device token")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "registered",
	})
}

// UnregisterDeviceToken handles POST /api/v1/devices/unregister.
// Requires authentication. Removes a device token.
func (h *PushHandler) UnregisterDeviceToken(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req unregisterDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.Token == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "token is required")
		return
	}

	if err := h.pushService.UnregisterDevice(r.Context(), req.Token); err != nil {
		writeError(w, http.StatusInternalServerError, "unregister_error", "Failed to unregister device token")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "unregistered",
	})
}
