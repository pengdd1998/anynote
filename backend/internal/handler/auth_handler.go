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
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.Email == "" || req.Username == "" || len(req.AuthKeyHash) == 0 {
		writeError(w, http.StatusBadRequest, "validation_error", "Email, username, and auth_key_hash are required")
		return
	}

	resp, err := h.authService.Register(r.Context(), req)
	if err != nil {
		switch err {
		case service.ErrEmailExists:
			writeError(w, http.StatusConflict, "email_exists", "Email already registered")
		case service.ErrUsernameExists:
			writeError(w, http.StatusConflict, "username_exists", "Username already taken")
		default:
			writeError(w, http.StatusInternalServerError, "internal_error", "Registration failed")
		}
		return
	}

	writeJSON(w, http.StatusCreated, resp)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req domain.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.Email == "" || len(req.AuthKeyHash) == 0 {
		writeError(w, http.StatusBadRequest, "validation_error", "Email and auth_key_hash are required")
		return
	}

	resp, err := h.authService.Login(r.Context(), req)
	if err != nil {
		if err == service.ErrInvalidCredentials {
			writeError(w, http.StatusUnauthorized, "invalid_credentials", "Invalid email or password")
		} else {
			writeError(w, http.StatusInternalServerError, "internal_error", "Login failed")
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
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	resp, err := h.authService.RefreshToken(r.Context(), req.RefreshToken)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid_token", "Invalid or expired refresh token")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "User not authenticated")
		return
	}

	user, err := h.authService.GetCurrentUser(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "User not found")
		return
	}

	writeJSON(w, http.StatusOK, user)
}
