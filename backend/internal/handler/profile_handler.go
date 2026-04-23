package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/anynote/backend/internal/service"
)

// ProfileHandler handles profile-related HTTP endpoints.
type ProfileHandler struct {
	profileSvc service.ProfileService
}

// NewProfileHandler creates a new ProfileHandler.
func NewProfileHandler(profileSvc service.ProfileService) *ProfileHandler {
	return &ProfileHandler{profileSvc: profileSvc}
}

// UpdateProfileRequest is the payload for PUT /api/v1/profile.
type UpdateProfileRequest struct {
	DisplayName    string `json:"display_name"`
	Bio            string `json:"bio"`
	PublicEnabled  *bool  `json:"public_profile_enabled,omitempty"`
}

// GetPublicProfile returns a user's public profile by username.
// GET /api/v1/profile/{username}
func (h *ProfileHandler) GetPublicProfile(w http.ResponseWriter, r *http.Request) {
	username := chi.URLParam(r, "username")
	if username == "" {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Username is required")
		return
	}

	profile, err := h.profileSvc.GetPublicProfile(r.Context(), username)
	if err != nil {
		writeError(w, r, http.StatusNotFound, "not_found", "Profile not found")
		return
	}

	writeJSON(w, http.StatusOK, profile)
}

// UpdateProfile updates the authenticated user's own profile.
// PUT /api/v1/profile
func (h *ProfileHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	defer r.Body.Close()

	var req UpdateProfileRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	// Validate field lengths.
	if len(req.DisplayName) > 100 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Display name must be 100 characters or less")
		return
	}
	if len(req.Bio) > 500 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Bio must be 500 characters or less")
		return
	}

	// Default public_profile_enabled to false if not provided.
	publicEnabled := false
	if req.PublicEnabled != nil {
		publicEnabled = *req.PublicEnabled
	}

	if err := h.profileSvc.UpdateProfile(r.Context(), userID, req.DisplayName, req.Bio, publicEnabled); err != nil {
		writeError(w, r, http.StatusInternalServerError, "profile_error", "Failed to update profile")
		return
	}

	// Return the updated profile.
	profile, err := h.profileSvc.GetOwnProfile(r.Context(), userID)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
		return
	}

	writeJSON(w, http.StatusOK, profile)
}
