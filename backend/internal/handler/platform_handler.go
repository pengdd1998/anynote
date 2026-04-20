package handler

import (
	"encoding/base64"
	"fmt"
	"net/http"
	"time"

	"github.com/anynote/backend/internal/service"
	"github.com/go-chi/chi/v5"
)

type PlatformHandler struct {
	platformService service.PlatformService
	masterKey       []byte
}

// NewPlatformHandler creates a handler with the required master key for
// encrypting/decrypting platform auth data.
func NewPlatformHandler(svc service.PlatformService, masterKey []byte) *PlatformHandler {
	return &PlatformHandler{
		platformService: svc,
		masterKey:       masterKey,
	}
}

func (h *PlatformHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	connections, err := h.platformService.List(r.Context(), parseUUID(userID))
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "list_error", "Failed to list platforms")
		return
	}

	writeJSON(w, http.StatusOK, connections)
}

// Connect initiates the platform authentication flow.
// For QR-code-based platforms (e.g. XHS), the response is an SSE stream:
//
//   - First event: type=qr_code, data=<base64-encoded PNG>
//   - Subsequent events: type=status, data={status: "waiting"|"done"|"failed"}
//   - Final event: type=status, data={status: "done", connection: {...}}
func (h *PlatformHandler) Connect(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platformName := chi.URLParam(r, "platform")
	if err := validateRequired(platformName, "platform"); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}

	// Start the auth flow and get the QR code.
	authRef, qrPNG, err := h.platformService.StartAuth(r.Context(), parseUUID(userID), platformName, h.masterKey)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "connect_error", fmt.Sprintf("Failed to start auth: %s", err.Error()))
		return
	}

	// Use SSE to stream the QR code and then poll for completion.
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, r, http.StatusInternalServerError, "streaming_error", "Streaming not supported")
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	// Send the QR code as the first event.
	qrB64 := base64.StdEncoding.EncodeToString(qrPNG)
	fmt.Fprintf(w, "event: qr_code\ndata: {\"auth_ref\":\"%s\",\"qr_png_base64\":\"%s\"}\n\n", authRef, qrB64)
	flusher.Flush()

	// Poll for auth completion.
	pollCtx := r.Context()
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()
	timeout := time.After(3 * time.Minute)

	for {
		select {
		case <-pollCtx.Done():
			return
		case <-timeout:
			fmt.Fprintf(w, "event: status\ndata: {\"status\":\"failed\",\"error\":\"authentication timed out\"}\n\n")
			flusher.Flush()
			return
		case <-ticker.C:
			encryptedAuth, pollErr := h.platformService.PollAuth(pollCtx, parseUUID(userID), platformName, authRef, h.masterKey)
			if pollErr != nil {
				fmt.Fprintf(w, "event: status\ndata: {\"status\":\"failed\",\"error\":\"%s\"}\n\n", pollErr.Error())
				flusher.Flush()
				return
			}
			if encryptedAuth == nil {
				// Still waiting.
				fmt.Fprintf(w, "event: status\ndata: {\"status\":\"waiting\"}\n\n")
				flusher.Flush()
				continue
			}

			// Auth succeeded.
			fmt.Fprintf(w, "event: status\ndata: {\"status\":\"done\"}\n\n")
			flusher.Flush()
			return
		}
	}
}

func (h *PlatformHandler) Disconnect(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platformName := chi.URLParam(r, "platform")
	if err := validateRequired(platformName, "platform"); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}

	if err := h.platformService.Disconnect(r.Context(), parseUUID(userID), platformName); err != nil {
		writeError(w, r, http.StatusInternalServerError, "disconnect_error", "Failed to disconnect platform")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *PlatformHandler) Verify(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r.Context())
	if userID == "" {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platformName := chi.URLParam(r, "platform")
	if err := validateRequired(platformName, "platform"); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}

	conn, err := h.platformService.Verify(r.Context(), parseUUID(userID), platformName)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]interface{}{
			"valid": false,
			"error": err.Error(),
		})
		return
	}

	writeJSON(w, http.StatusOK, conn)
}
