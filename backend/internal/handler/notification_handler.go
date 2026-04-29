package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/anynote/backend/internal/service"
)

// NotificationHandler handles notification-related HTTP endpoints.
type NotificationHandler struct {
	notifSvc service.NotificationService
}

// NewNotificationHandler creates a new NotificationHandler.
func NewNotificationHandler(notifSvc service.NotificationService) *NotificationHandler {
	return &NotificationHandler{notifSvc: notifSvc}
}

// ListNotifications handles GET /api/v1/notifications?limit=20&offset=0.
// Returns paginated notifications for the authenticated user.
func (h *NotificationHandler) ListNotifications(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	limit := 20
	offset := 0

	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}
	if v := r.URL.Query().Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			offset = n
		}
	}

	notifications, err := h.notifSvc.ListNotifications(r.Context(), userID.String(), limit, offset)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "list_error", "Failed to list notifications")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"notifications": notifications,
		"limit":         limit,
		"offset":        offset,
	})
}

// GetUnreadCount handles GET /api/v1/notifications/unread-count.
// Returns the number of unread notifications.
func (h *NotificationHandler) GetUnreadCount(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	count, err := h.notifSvc.GetUnreadCount(r.Context(), userID.String())
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "count_error", "Failed to get unread count")
		return
	}

	writeJSON(w, http.StatusOK, map[string]int{"unread_count": count})
}

// MarkRead handles POST /api/v1/notifications/{id}/read.
// Marks a single notification as read.
func (h *NotificationHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	notifID := chi.URLParam(r, "id")
	if notifID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Notification ID is required")
		return
	}

	if err := h.notifSvc.MarkRead(r.Context(), notifID, userID.String()); err != nil {
		if err == service.ErrNotificationNotFound {
			writeError(w, r, http.StatusNotFound, "not_found", "Notification not found")
			return
		}
		writeError(w, r, http.StatusInternalServerError, "mark_read_error", "Failed to mark notification as read")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "read"})
}

// MarkAllRead handles POST /api/v1/notifications/read-all.
// Marks all notifications for the user as read.
func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	if err := h.notifSvc.MarkAllRead(r.Context(), userID.String()); err != nil {
		writeError(w, r, http.StatusInternalServerError, "mark_all_read_error", "Failed to mark all notifications as read")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "all_read"})
}

// HandleGetPreferences handles GET /api/v1/notifications/preferences.
// Returns the user's notification preferences as a JSON object.
func (h *NotificationHandler) HandleGetPreferences(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	prefs, err := h.notifSvc.GetNotificationPreferences(r.Context(), userID.String())
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "preferences_error", "Failed to get notification preferences")
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_, _ = w.Write(prefs)
}

// HandleUpdatePreferences handles PUT /api/v1/notifications/preferences.
// Updates the user's notification preferences. The request body must be a JSON
// object where all values are booleans (e.g. {"pushNotifications": true, "reminderNotifications": false}).
func (h *NotificationHandler) HandleUpdatePreferences(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var prefs map[string]bool
	if err := json.NewDecoder(r.Body).Decode(&prefs); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_json", "Request body must be a JSON object with boolean values")
		return
	}

	prefsJSON, err := json.Marshal(prefs)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_preferences", "Failed to encode preferences")
		return
	}

	if err := h.notifSvc.UpdateNotificationPreferences(r.Context(), userID.String(), prefsJSON); err != nil {
		writeError(w, r, http.StatusInternalServerError, "preferences_error", "Failed to update notification preferences")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
