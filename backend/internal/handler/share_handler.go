package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
	"github.com/go-chi/chi/v5"
)

type ShareHandler struct {
	shareService service.ShareService
}

// CreateShare creates a new shared note. Requires authentication.
// The server only stores the client-encrypted blob and metadata.
// The decryption key is never sent to the server.
func (h *ShareHandler) CreateShare(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.CreateShareRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.EncryptedContent == "" || req.EncryptedTitle == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "encrypted_content and encrypted_title are required")
		return
	}

	if req.ShareKeyHash == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "share_key_hash is required")
		return
	}

	resp, err := h.shareService.CreateShare(r.Context(), parseUUID(userID), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "create_error", "Failed to create shared note")
		return
	}

	writeJSON(w, http.StatusCreated, resp)
}

// GetShare retrieves a shared note by ID. No authentication required.
// Returns the encrypted blob; the client must decrypt locally.
func (h *ShareHandler) GetShare(w http.ResponseWriter, r *http.Request) {
	shareID := chi.URLParam(r, "id")
	if shareID == "" {
		writeError(w, http.StatusBadRequest, "missing_id", "Share ID is required")
		return
	}

	resp, err := h.shareService.GetShare(r.Context(), shareID)
	if err != nil {
		switch err {
		case service.ErrShareNotFound:
			writeError(w, http.StatusNotFound, "not_found", "Shared note not found")
		case service.ErrShareExpired:
			writeError(w, http.StatusGone, "expired", "Shared note has expired")
		case service.ErrShareMaxViews:
			writeError(w, http.StatusGone, "max_views", "Shared note has reached maximum views")
		default:
			writeError(w, http.StatusInternalServerError, "internal_error", "Failed to retrieve shared note")
		}
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

// DiscoverFeed returns public shared notes for the discovery feed.
// No authentication required. Supports pagination via query params.
func (h *ShareHandler) DiscoverFeed(w http.ResponseWriter, r *http.Request) {
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

	items, err := h.shareService.DiscoverFeed(r.Context(), limit, offset)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Failed to fetch discovery feed")
		return
	}

	// Return empty array instead of null when no items.
	if items == nil {
		items = []domain.DiscoverFeedItem{}
	}
	writeJSON(w, http.StatusOK, items)
}

// ToggleReaction toggles a heart or bookmark reaction on a shared note.
// Requires authentication.
func (h *ShareHandler) ToggleReaction(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	shareID := chi.URLParam(r, "id")
	if shareID == "" {
		writeError(w, http.StatusBadRequest, "missing_id", "Share ID is required")
		return
	}

	var req domain.ReactRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	resp, err := h.shareService.ToggleReaction(r.Context(), parseUUID(userID), shareID, req.ReactionType)
	if err != nil {
		switch err {
		case service.ErrShareNotFound:
			writeError(w, http.StatusNotFound, "not_found", "Shared note not found")
		case service.ErrInvalidReaction:
			writeError(w, http.StatusBadRequest, "invalid_reaction", "reaction_type must be 'heart' or 'bookmark'")
		default:
			writeError(w, http.StatusInternalServerError, "internal_error", "Failed to toggle reaction")
		}
		return
	}

	writeJSON(w, http.StatusOK, resp)
}
