package handler

import (
	"encoding/json"
	"net/http"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

type AuthHandler struct {
	authService service.AuthService
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req domain.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	// Validate input
	if err := validateEmail(req.Email); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}
	if err := validateUsername(req.Username); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}
	if len(req.AuthKeyHash) == 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "auth_key_hash is required")
		return
	}
	if len(req.AuthKeyHash) > 128 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "auth_key_hash must be at most 128 bytes")
		return
	}
	if len(req.Salt) > 64 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "salt must be at most 64 bytes")
		return
	}
	if len(req.RecoveryKey) > 1024 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "recovery_key must be at most 1024 bytes")
		return
	}

	resp, err := h.authService.Register(r.Context(), req)
	if err != nil {
		switch err {
		case service.ErrEmailExists:
			writeError(w, r, http.StatusConflict, "email_exists", "Email already registered")
		case service.ErrUsernameExists:
			writeError(w, r, http.StatusConflict, "username_exists", "Username already taken")
		default:
			writeError(w, r, http.StatusInternalServerError, "internal_error", "Registration failed")
		}
		return
	}

	writeJSON(w, http.StatusCreated, resp)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req domain.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if err := validateEmail(req.Email); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}
	if len(req.AuthKeyHash) == 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "auth_key_hash is required")
		return
	}

	resp, err := h.authService.Login(r.Context(), req)
	if err != nil {
		if err == service.ErrInvalidCredentials {
			writeError(w, r, http.StatusUnauthorized, "invalid_credentials", "Invalid email or password")
		} else {
			writeError(w, r, http.StatusInternalServerError, "internal_error", "Login failed")
		}
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	resp, err := h.authService.RefreshToken(r.Context(), req.RefreshToken)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "invalid_token", "Invalid or expired refresh token")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "User not authenticated")
		return
	}

	user, err := h.authService.GetCurrentUser(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, r, http.StatusNotFound, "not_found", "User not found")
		return
	}

	writeJSON(w, http.StatusOK, user)
}

// DeleteAccount handles DELETE /api/v1/auth/account.
// Requires a valid JWT and password confirmation via auth_key_hash.
func (h *AuthHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "User not authenticated")
		return
	}

	var req struct {
		AuthKeyHash []byte `json:"auth_key_hash"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if len(req.AuthKeyHash) == 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "auth_key_hash is required")
		return
	}
	if len(req.AuthKeyHash) > 128 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "auth_key_hash must be at most 128 bytes")
		return
	}

	if err := h.authService.DeleteAccount(r.Context(), parseUUID(userID), req.AuthKeyHash); err != nil {
		if err == service.ErrInvalidCredentials {
			writeError(w, r, http.StatusUnauthorized, "invalid_credentials", "Invalid password")
		} else if err == service.ErrUserNotFound {
			writeError(w, r, http.StatusNotFound, "not_found", "User not found")
		} else {
			writeError(w, r, http.StatusInternalServerError, "internal_error", "Account deletion failed")
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}
