package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// DeviceHandler handles HTTP requests for device identity management.
type DeviceHandler struct {
	deviceSvc service.DeviceService
}

// NewDeviceHandler creates a new DeviceHandler.
func NewDeviceHandler(deviceSvc service.DeviceService) *DeviceHandler {
	return &DeviceHandler{deviceSvc: deviceSvc}
}

// registerDeviceBody is the expected JSON body for POST /api/v1/devices/register.
type registerDeviceBody struct {
	DeviceID   string `json:"device_id"`
	DeviceName string `json:"device_name"`
	Platform   string `json:"platform"`
}

// RegisterDevice handles POST /api/v1/devices/register.
// Upserts a device identity record for the authenticated user.
func (h *DeviceHandler) RegisterDevice(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req registerDeviceBody
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.DeviceID == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "device_id is required")
		return
	}
	if len(req.DeviceID) > 128 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "device_id must be at most 128 characters")
		return
	}
	if len(req.DeviceName) > 255 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "device_name must be at most 255 characters")
		return
	}
	if len(req.Platform) > 32 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "platform must be at most 32 characters")
		return
	}

	device, err := h.deviceSvc.RegisterDevice(r.Context(), userID, req.DeviceID, req.DeviceName, req.Platform)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "register_error", "Failed to register device")
		return
	}

	writeJSON(w, http.StatusOK, device)
}

// ListDevices handles GET /api/v1/devices.
// Returns all devices registered for the authenticated user.
func (h *DeviceHandler) ListDevices(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	devices, err := h.deviceSvc.ListDevices(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "list_error", "Failed to list devices")
		return
	}

	// Ensure the response always contains an array, even when empty.
	if devices == nil {
		devices = make([]*domain.Device, 0)
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"devices": devices,
	})
}

// DeleteDevice handles DELETE /api/v1/devices/{deviceID}.
// Removes a specific device identity for the authenticated user.
func (h *DeviceHandler) DeleteDevice(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	deviceID := chi.URLParam(r, "deviceID")
	if deviceID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_device_id", "Device ID is required")
		return
	}

	if err := h.deviceSvc.DeleteDevice(r.Context(), userID, deviceID); err != nil {
		writeError(w, r, http.StatusNotFound, "not_found", "Device not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}
