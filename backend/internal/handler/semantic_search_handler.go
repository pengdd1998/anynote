package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// SemanticSearchHandler handles vector search HTTP endpoints.
//
// Privacy: the client embeds note text with its own LLM provider and
// uploads vectors only. These endpoints therefore never receive (or log)
// note content.
type SemanticSearchHandler struct {
	svc service.SemanticSearchService
}

func NewSemanticSearchHandler(svc service.SemanticSearchService) *SemanticSearchHandler {
	return &SemanticSearchHandler{svc: svc}
}

// UpsertEmbedding handles PUT /search/embeddings.
func (h *SemanticSearchHandler) UpsertEmbedding(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.UpsertEmbeddingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}
	if req.NoteID == uuid.Nil {
		writeError(w, r, http.StatusBadRequest, "validation_error", "note_id is required")
		return
	}

	if err := h.svc.UpsertEmbedding(r.Context(), userID, req.NoteID, req.Lang, req.Embedding); err != nil {
		if errors.Is(err, service.ErrInvalidEmbedding) {
			writeError(w, r, http.StatusBadRequest, "validation_error", "embedding must be 1..4096 finite floats")
			return
		}
		writeError(w, r, http.StatusInternalServerError, "embedding_upsert_error", "Failed to store embedding")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// DeleteEmbedding handles DELETE /search/embeddings/{noteId}.
func (h *SemanticSearchHandler) DeleteEmbedding(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	noteID, err := uuid.Parse(chi.URLParam(r, "noteId"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "validation_error", "invalid note id")
		return
	}

	if err := h.svc.DeleteEmbedding(r.Context(), userID, noteID); err != nil {
		writeError(w, r, http.StatusInternalServerError, "embedding_delete_error", "Failed to delete embedding")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// Search handles POST /search/semantic.
func (h *SemanticSearchHandler) Search(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.SemanticSearchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	hits, err := h.svc.Search(r.Context(), userID, req.QueryVector, req.Limit)
	if err != nil {
		if errors.Is(err, service.ErrInvalidEmbedding) {
			writeError(w, r, http.StatusBadRequest, "validation_error", "query_vector must be 1..4096 finite floats")
			return
		}
		writeError(w, r, http.StatusInternalServerError, "semantic_search_error", "Failed to search")
		return
	}
	if hits == nil {
		hits = []domain.SemanticSearchHit{}
	}
	writeJSON(w, http.StatusOK, domain.SemanticSearchResponse{Hits: hits})
}

// ListEmbeddings handles GET /search/embeddings.
func (h *SemanticSearchHandler) ListEmbeddings(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	list, err := h.svc.ListEmbeddings(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "embedding_list_error", "Failed to list embeddings")
		return
	}
	if list == nil {
		list = []domain.NoteEmbedding{}
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"embeddings": list})
}
