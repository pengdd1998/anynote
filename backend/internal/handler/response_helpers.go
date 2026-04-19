package handler

import (
	"encoding/json"
	"net/http"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// writeJSON writes a JSON response with the given status code.
func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// writeError writes a standardized error response.
func writeError(w http.ResponseWriter, status int, errType, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(domain.ErrorResponse{
		Error:   errType,
		Message: message,
	})
}

// writeErrorFromSentinel maps service-layer sentinel errors to HTTP status codes
// and writes a standardized error response. Returns true if the error was handled.
func writeErrorFromSentinel(w http.ResponseWriter, err error) bool {
	switch err {
	case service.ErrEmailExists:
		writeError(w, http.StatusConflict, "email_exists", "Email already registered")
	case service.ErrUsernameExists:
		writeError(w, http.StatusConflict, "username_exists", "Username already taken")
	case service.ErrInvalidCredentials:
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "Invalid email or password")
	case service.ErrUserNotFound:
		writeError(w, http.StatusNotFound, "not_found", "User not found")
	case service.ErrQuotaExceeded:
		writeError(w, http.StatusTooManyRequests, "quota_exceeded", "AI quota exceeded")
	case service.ErrShareNotFound:
		writeError(w, http.StatusNotFound, "not_found", "Shared note not found")
	case service.ErrShareExpired:
		writeError(w, http.StatusGone, "expired", "Shared note has expired")
	case service.ErrShareMaxViews:
		writeError(w, http.StatusGone, "max_views", "Shared note has reached maximum views")
	case service.ErrCommentNotFound:
		writeError(w, http.StatusNotFound, "not_found", "Comment not found")
	case service.ErrNotCommentAuthor:
		writeError(w, http.StatusForbidden, "forbidden", "Only the comment author can delete it")
	default:
		return false
	}
	return true
}
