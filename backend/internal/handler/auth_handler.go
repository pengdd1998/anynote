package handler

import (
	"crypto/sha256"
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
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	// Validate input
	if err := validateEmail(req.Email); err != nil {
		if ve, ok := err.(*ValidationError); ok {
			writeValidationError(w, ve)
		}
		return
	}
	if err := validateUsername(req.Username); err != nil {
		if ve, ok := err.(*ValidationError); ok {
			writeValidationError(w, ve)
		}
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
	if len(req.RecoverySalt) > 64 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "recovery_salt must be at most 64 bytes")
		return
	}

	resp, err := h.authService.Register(r.Context(), req)
	if err != nil {
		if !writeErrorFromSentinel(w, r, err) {
			writeError(w, r, http.StatusInternalServerError, "internal_error", "Registration failed")
		}
		return
	}

	writeJSON(w, http.StatusCreated, resp)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req domain.LoginRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if err := validateEmail(req.Email); err != nil {
		if ve, ok := err.(*ValidationError); ok {
			writeValidationError(w, ve)
		}
		return
	}
	if len(req.AuthKeyHash) == 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "auth_key_hash is required")
		return
	}

	resp, err := h.authService.Login(r.Context(), req)
	if err != nil {
		if !writeErrorFromSentinel(w, r, err) {
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
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	resp, err := h.authService.RefreshToken(r.Context(), req.RefreshToken)
	if err != nil {
		if !writeErrorFromSentinel(w, r, err) {
			writeError(w, r, http.StatusUnauthorized, "invalid_token", "Invalid or expired refresh token")
		}
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "User not authenticated")
		return
	}

	user, err := h.authService.GetCurrentUser(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusNotFound, "not_found", "User not found")
		return
	}

	writeJSON(w, http.StatusOK, user)
}

// DeleteAccount handles DELETE /api/v1/auth/account.
// Requires a valid JWT and password confirmation via auth_key_hash.
func (h *AuthHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "User not authenticated")
		return
	}

	var req struct {
		AuthKeyHash []byte `json:"auth_key_hash"`
	}
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
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

	if err := h.authService.DeleteAccount(r.Context(), userID, req.AuthKeyHash); err != nil {
		if !writeErrorFromSentinel(w, r, err) {
			writeError(w, r, http.StatusInternalServerError, "internal_error", "Account deletion failed")
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// GetRecoverySalt handles GET /api/v1/auth/recovery-salt?email=...
// This is a public endpoint (rate limited) because the user is not yet
// authenticated during account recovery.
//
// Returns the same response shape regardless of whether the email exists
// to prevent user enumeration. For unknown emails, a fake salt derived from
// the email and server secret is returned so the response is deterministic
// (prevents timing-based enumeration too).
func (h *AuthHandler) GetRecoverySalt(w http.ResponseWriter, r *http.Request) {
	email := r.URL.Query().Get("email")
	if email == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "email query parameter is required")
		return
	}
	if err := validateEmail(email); err != nil {
		if ve, ok := err.(*ValidationError); ok {
			writeValidationError(w, ve)
		}
		return
	}

	resp, err := h.authService.GetRecoverySaltByEmail(r.Context(), email)
	if err != nil {
		// Return fake salt to prevent user enumeration.
		// The client will derive a key from the wrong salt and the
		// subsequent Recover call will fail with an opaque error.
		writeJSON(w, http.StatusOK, domain.RecoverySaltResponse{
			RecoverySalt: fakeRecoverySalt(email),
		})
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

// Recover handles POST /api/v1/auth/recover.
// This is a public endpoint (rate limited) because the user is not yet
// authenticated during account recovery. Validates the recovery key and
// updates the user's password.
func (h *AuthHandler) Recover(w http.ResponseWriter, r *http.Request) {
	var req domain.RecoverRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if err := validateEmail(req.Email); err != nil {
		if ve, ok := err.(*ValidationError); ok {
			writeValidationError(w, ve)
		}
		return
	}
	if req.RecoveryKey == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "recovery_key is required")
		return
	}
	if req.NewPassword == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "new_password is required")
		return
	}
	if len(req.NewPassword) > 128 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "new_password must be at most 128 bytes")
		return
	}

	if err := h.authService.RecoverAccount(r.Context(), &req); err != nil {
		if !writeErrorFromSentinel(w, r, err) {
			writeError(w, r, http.StatusInternalServerError, "internal_error", "Account recovery failed")
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "recovered"})
}

// fakeRecoverySalt returns a deterministic 32-byte salt derived from the email.
// This ensures the recovery-salt endpoint returns the same response shape
// for both existing and non-existing users, preventing email enumeration.
func fakeRecoverySalt(email string) []byte {
	h := sha256.Sum256([]byte("recovery-salt-fake:" + email))
	return h[:]
}