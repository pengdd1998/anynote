package handler

import (
	"encoding/json"
	"net/http"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
	"github.com/go-chi/chi/v5"
)

type LLMConfigHandler struct {
	llmService service.LLMConfigService
}

func (h *LLMConfigHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	configs, err := h.llmService.List(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "list_error", "Failed to list configs")
		return
	}

	writeJSON(w, http.StatusOK, configs)
}

func (h *LLMConfigHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var cfg domain.LLMConfig
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&cfg); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	// Copy APIKey (JSON input field) to DecryptedKey for the service layer.
	cfg.DecryptedKey = cfg.APIKey

	if cfg.Name == "" || cfg.Provider == "" || cfg.BaseURL == "" || cfg.DecryptedKey == "" || cfg.Model == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "name, provider, base_url, api_key, and model are required")
		return
	}

	result, err := h.llmService.Create(r.Context(), userID, cfg)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "create_error", "Failed to create config")
		return
	}

	writeJSON(w, http.StatusCreated, result)
}

func (h *LLMConfigHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	configID := chi.URLParam(r, "id")
	if configID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Config ID is required")
		return
	}

	parsedID, err := parseUUID(configID)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_id", "Invalid config ID format")
		return
	}

	var cfg domain.LLMConfig
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&cfg); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	cfg.ID = parsedID
	result, err := h.llmService.Update(r.Context(), userID, cfg)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "update_error", "Failed to update config")
		return
	}

	writeJSON(w, http.StatusOK, result)
}

func (h *LLMConfigHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	configID := chi.URLParam(r, "id")
	if configID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Config ID is required")
		return
	}

	parsedID, err := parseUUID(configID)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_id", "Invalid config ID format")
		return
	}

	if err := h.llmService.Delete(r.Context(), userID, parsedID); err != nil {
		writeError(w, r, http.StatusInternalServerError, "delete_error", "Failed to delete config")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *LLMConfigHandler) TestConnection(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	configID := chi.URLParam(r, "id")
	if configID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_id", "Config ID is required")
		return
	}

	parsedID, err := parseUUID(configID)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_id", "Invalid config ID format")
		return
	}

	if err := h.llmService.TestConnection(r.Context(), userID, parsedID); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Connection successful",
	})
}

func (h *LLMConfigHandler) ListProviders(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, h.llmService.ListProviders())
}
