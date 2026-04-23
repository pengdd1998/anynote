package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// NoteLinkHandler handles note link HTTP endpoints.
type NoteLinkHandler struct {
	noteLinkSvc service.NoteLinkService
}

// NewNoteLinkHandler creates a new NoteLinkHandler.
func NewNoteLinkHandler(svc service.NoteLinkService) *NoteLinkHandler {
	return &NoteLinkHandler{noteLinkSvc: svc}
}

func (h *NoteLinkHandler) CreateLinks(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.CreateNoteLinksRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if len(req.Links) == 0 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "At least one link is required")
		return
	}
	if len(req.Links) > 100 {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Too many links (max 100)")
		return
	}

	links, err := h.noteLinkSvc.CreateLinks(r.Context(), userID, req.Links)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "create_links_error", "Failed to create links")
		return
	}

	writeJSON(w, http.StatusOK, domain.NoteLinksResponse{Links: links})
}

func (h *NoteLinkHandler) GetBacklinks(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	noteID, err := uuid.Parse(chi.URLParam(r, "noteId"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_note_id", "Invalid note ID")
		return
	}

	links, err := h.noteLinkSvc.GetBacklinks(r.Context(), userID, noteID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "backlinks_error", "Failed to get backlinks")
		return
	}

	if links == nil {
		links = []domain.NoteLink{}
	}
	writeJSON(w, http.StatusOK, domain.NoteLinksResponse{Links: links})
}

func (h *NoteLinkHandler) GetOutboundLinks(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	noteID, err := uuid.Parse(chi.URLParam(r, "noteId"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_note_id", "Invalid note ID")
		return
	}

	links, err := h.noteLinkSvc.GetOutboundLinks(r.Context(), userID, noteID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "links_error", "Failed to get links")
		return
	}

	if links == nil {
		links = []domain.NoteLink{}
	}
	writeJSON(w, http.StatusOK, domain.NoteLinksResponse{Links: links})
}

func (h *NoteLinkHandler) GetGraph(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	graph, err := h.noteLinkSvc.GetGraph(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "graph_error", "Failed to get graph")
		return
	}

	writeJSON(w, http.StatusOK, graph)
}

func (h *NoteLinkHandler) DeleteLink(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	sourceID, err := uuid.Parse(chi.URLParam(r, "sourceId"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_source_id", "Invalid source ID")
		return
	}

	targetID, err := uuid.Parse(chi.URLParam(r, "targetId"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_target_id", "Invalid target ID")
		return
	}

	if err := h.noteLinkSvc.DeleteLink(r.Context(), userID, sourceID, targetID); err != nil {
		writeError(w, r, http.StatusNotFound, "delete_error", "Link not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}
