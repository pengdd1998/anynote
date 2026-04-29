// Package handler implements HTTP handlers for the AnyNote API.
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// AIAgentHandler handles AI agent HTTP endpoints.
type AIAgentHandler struct {
	agentSvc service.AIAgentService
}

// NewAIAgentHandler creates a new AIAgentHandler.
func NewAIAgentHandler(svc service.AIAgentService) *AIAgentHandler {
	return &AIAgentHandler{agentSvc: svc}
}

func (h *AIAgentHandler) ExecuteAction(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.AIAgentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.Action == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Action is required")
		return
	}

	validActions := map[string]bool{
		"organize":  true,
		"summarize": true,
		"create_note": true,
	}
	if !validActions[req.Action] {
		writeError(w, r, http.StatusBadRequest, "validation_error", "Invalid action. Valid: organize, summarize, create_note")
		return
	}

	resp, err := h.agentSvc.ExecuteAction(r.Context(), userID.String(), req)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "agent_error", "AI agent failed")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}
