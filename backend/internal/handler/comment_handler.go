package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// CommentHandler handles HTTP requests for encrypted comments on shared notes.
type CommentHandler struct {
	commentService service.CommentService
}

// CreateComment creates a new encrypted comment on a shared note.
// POST /api/v1/share/{id}/comments
func (h *CommentHandler) CreateComment(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	sharedNoteID := chi.URLParam(r, "id")
	if sharedNoteID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Shared note ID is required")
		return
	}

	var req domain.CreateCommentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.EncryptedContent == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "encrypted_content is required")
		return
	}
	if len(req.EncryptedContent) > maxEncryptedContentLen {
		writeError(w, r, http.StatusBadRequest, "validation_error", "encrypted_content must be at most 1 MB")
		return
	}

	comment, err := h.commentService.CreateComment(r.Context(), sharedNoteID, userID, req)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "create_error", "Failed to create comment")
		return
	}

	writeJSON(w, http.StatusCreated, comment)
}

// ListComments returns encrypted comments for a shared note, paginated.
// GET /api/v1/share/{id}/comments?limit=50&offset=0
func (h *CommentHandler) ListComments(w http.ResponseWriter, r *http.Request) {
	sharedNoteID := chi.URLParam(r, "id")
	if sharedNoteID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Shared note ID is required")
		return
	}

	limit := 50
	offset := 0

	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}
	if limit > 100 {
		limit = 100
	}

	if v := r.URL.Query().Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			offset = n
		}
	}

	resp, err := h.commentService.ListComments(r.Context(), sharedNoteID, limit, offset)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "internal_error", "Failed to list comments")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

// DeleteComment soft-deletes a comment. Only the comment author can delete.
// DELETE /api/v1/comments/{id}
func (h *CommentHandler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	commentIDStr := chi.URLParam(r, "id")
	if commentIDStr == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Comment ID is required")
		return
	}

	commentID, err := parseUUID(commentIDStr)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_id", "Invalid comment ID format")
		return
	}

	err = h.commentService.DeleteComment(r.Context(), commentID, userID)
	if err != nil {
		if !writeErrorFromSentinel(w, r, err) {
			writeError(w, r, http.StatusInternalServerError, "delete_error", "Failed to delete comment")
		}
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
