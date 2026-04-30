package handler

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strconv"

	"golang.org/x/crypto/bcrypt"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
	"github.com/go-chi/chi/v5"
)

const (
	maxEncryptedContentLen = 1_048_576 // 1 MB
	maxEncryptedTitleLen   = 500
	maxShareKeyHashLen     = 256 // bcrypt hashes are ~60 chars, but allow margin
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

	// Re-hash the client-provided hash with bcrypt for secure storage.
	// The client sends SHA-256(password); we bcrypt that before storing
	// so that a database leak does not allow fast brute-force attacks.
	if req.HasPassword {
		bcryptHash, bErr := bcrypt.GenerateFromPassword([]byte(req.ShareKeyHash), bcrypt.DefaultCost)
		if bErr != nil {
			writeError(w, r, http.StatusInternalServerError, "hash_error", "Failed to hash share password")
			return
		}
		req.ShareKeyHash = string(bcryptHash)
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
// password via the X-Share-Password header.
// The password is hashed and compared against the stored bcrypt hash.
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
	if resp == nil {
		writeError(w, r, http.StatusNotFound, "not_found", "Shared note not found")
		return
	}

	// If the share is password-protected, verify the password hash.
	// Password must be sent via the X-Share-Password header (not query param,
	// which leaks to access logs and browser history).
	if resp.HasPassword {
		providedPassword := r.Header.Get("X-Share-Password")
		if providedPassword == "" {
			writeError(w, r, http.StatusForbidden, "password_required", "This shared note requires a password. Send it via X-Share-Password header.")
			return
		}

		// Hash the provided password with SHA-256 (matching client behavior),
		// then verify against the stored bcrypt hash.
		shaHash := sha256.Sum256([]byte(providedPassword))
		providedHash := hex.EncodeToString(shaHash[:])

		stored := []byte(resp.ShareKeyHash)
		if err := bcrypt.CompareHashAndPassword(stored, []byte(providedHash)); err != nil {
			// Fallback: legacy shares used plain SHA-256 comparison.
			if subtle.ConstantTimeCompare([]byte(providedHash), stored) != 1 {
				writeError(w, r, http.StatusForbidden, "wrong_password", "Incorrect password")
				return
			}
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
