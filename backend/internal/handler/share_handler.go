package handler

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
	"github.com/go-chi/chi/v5"
)

const (
	maxEncryptedContentLen = 1_048_576 // 1 MB
	maxEncryptedTitleLen   = 500
	maxShareKeyHashLen     = 256
)

type ShareHandler struct {
	shareService service.ShareService
}

// CreateShare creates a new shared note. Requires authentication.
// The server only stores the client-encrypted blob and metadata.
// The decryption key is never sent to the server.
func (h *ShareHandler) CreateShare(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.CreateShareRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.EncryptedContent == "" || req.EncryptedTitle == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "encrypted_content and encrypted_title are required")
		return
	}

	if len(req.EncryptedContent) > maxEncryptedContentLen {
		writeError(w, r, http.StatusBadRequest, "validation_error", "encrypted_content must be at most 1 MB")
		return
	}
	if len(req.EncryptedTitle) > maxEncryptedTitleLen {
		writeError(w, r, http.StatusBadRequest, "validation_error", "encrypted_title must be at most 500 characters")
		return
	}

	if req.ShareKeyHash == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "share_key_hash is required")
		return
	}
	if len(req.ShareKeyHash) > maxShareKeyHashLen {
		writeError(w, r, http.StatusBadRequest, "validation_error", "share_key_hash must be at most 256 characters")
		return
	}

	resp, err := h.shareService.CreateShare(r.Context(), userID, req)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "create_error", "Failed to create shared note")
		return
	}

	writeJSON(w, http.StatusCreated, resp)
}

// GetShare retrieves a shared note by ID. No authentication required.
// If the share has a password (HasPassword=true), the client must send the
// password via the X-Share-Password header or share_password query parameter.
// The password is hashed and compared against the stored ShareKeyHash.
// Returns the encrypted blob; the client must decrypt locally.
func (h *ShareHandler) GetShare(w http.ResponseWriter, r *http.Request) {
	shareID := chi.URLParam(r, "id")
	if shareID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Share ID is required")
		return
	}

	resp, err := h.shareService.GetShare(r.Context(), shareID)
	if err != nil {
		if !writeErrorFromSentinel(w, r, err) {
			writeError(w, r, http.StatusInternalServerError, "internal_error", "Failed to retrieve shared note")
		}
		return
	}

	// If the share is password-protected, verify the password hash.
	if resp.HasPassword {
		providedPassword := r.Header.Get("X-Share-Password")
		if providedPassword == "" {
			providedPassword = r.URL.Query().Get("share_password")
		}
		if providedPassword == "" {
			writeError(w, r, http.StatusForbidden, "password_required", "This shared note requires a password")
			return
		}

		// Hash the provided password and compare with stored hash.
		hash := sha256.Sum256([]byte(providedPassword))
		providedHash := hex.EncodeToString(hash[:])
		if providedHash != resp.ShareKeyHash {
			writeError(w, r, http.StatusForbidden, "wrong_password", "Incorrect password")
			return
		}
	}

	// Clear the server-side hash before sending to client.
	resp.ShareKeyHash = ""
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
		writeError(w, r, http.StatusInternalServerError, "internal_error", "Failed to fetch discovery feed")
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
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	shareID := chi.URLParam(r, "id")
	if shareID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Share ID is required")
		return
	}

	var req domain.ReactRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	resp, err := h.shareService.ToggleReaction(r.Context(), userID, shareID, req.ReactionType)
	if err != nil {
		if !writeErrorFromSentinel(w, r, err) {
			writeError(w, r, http.StatusInternalServerError, "internal_error", "Failed to toggle reaction")
		}
		return
	}

	writeJSON(w, http.StatusOK, resp)
}
