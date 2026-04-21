package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5/middleware"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// writeJSON writes a JSON response with the given status code.
func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		slog.Error("failed to encode JSON response", "error", err)
	}
}

// writeError writes a standardized error response with the request ID extracted
// from the request context (set by chi RequestID middleware).
func writeError(w http.ResponseWriter, r *http.Request, status int, code string, message string) {
	requestID := ""
	if r != nil {
		requestID = middleware.GetReqID(r.Context())
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(domain.ErrorResponse{
		Error: domain.ErrorDetail{
			Code:    code,
			Message: message,
		},
		RequestID: requestID,
	}); err != nil {
		slog.Error("failed to encode error JSON response", "error", err)
	}
}

// writeErrorFromSentinel maps service-layer sentinel errors to HTTP status codes
// and writes a standardized error response. Returns true if the error was handled.
func writeErrorFromSentinel(w http.ResponseWriter, r *http.Request, err error) bool {
	switch err {
	case service.ErrEmailExists:
		writeError(w, r, http.StatusConflict, "email_exists", "Email already registered")
	case service.ErrUsernameExists:
		writeError(w, r, http.StatusConflict, "username_exists", "Username already taken")
	case service.ErrInvalidCredentials:
		writeError(w, r, http.StatusUnauthorized, "invalid_credentials", "Invalid email or password")
	case service.ErrUserNotFound:
		writeError(w, r, http.StatusNotFound, "not_found", "User not found")
	case service.ErrQuotaExceeded:
		writeError(w, r, http.StatusTooManyRequests, "quota_exceeded", "AI quota exceeded")
	case service.ErrShareNotFound:
		writeError(w, r, http.StatusNotFound, "not_found", "Shared note not found")
	case service.ErrShareExpired:
		writeError(w, r, http.StatusGone, "expired", "Shared note has expired")
	case service.ErrShareMaxViews:
		writeError(w, r, http.StatusGone, "max_views", "Shared note has reached maximum views")
	case service.ErrCommentNotFound:
		writeError(w, r, http.StatusNotFound, "not_found", "Comment not found")
	case service.ErrNotCommentAuthor:
		writeError(w, r, http.StatusForbidden, "forbidden", "Only the comment author can delete it")
	case service.ErrNotOwner:
		writeError(w, r, http.StatusForbidden, "forbidden", "You do not own this resource")
	case service.ErrInvalidReaction:
		writeError(w, r, http.StatusBadRequest, "invalid_reaction", "reaction_type must be 'heart' or 'bookmark'")
	case service.ErrInvalidTokenType:
		writeError(w, r, http.StatusUnauthorized, "invalid_token", "Invalid token type")
	default:
		return false
	}
	return true
}
