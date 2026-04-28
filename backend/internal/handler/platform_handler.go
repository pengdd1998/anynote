package handler

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
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
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	connections, err := h.platformService.List(r.Context(), userID)
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
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platformName := chi.URLParam(r, "platform")
	if err := validateRequired(platformName, "platform"); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}

	// Start the auth flow and get the QR code.
	authRef, qrPNG, err := h.platformService.StartAuth(r.Context(), userID, platformName, h.masterKey)
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
	writeSSE(w, flusher, "qr_code", map[string]string{"auth_ref": authRef, "qr_png_base64": qrB64})

	// Poll for auth completion.
	pollCtx := r.Context()
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()
	defer h.platformService.CancelAuth(userID, platformName, authRef)
	timeout := time.After(3 * time.Minute)

	for {
		select {
		case <-pollCtx.Done():
			return
		case <-timeout:
			writeSSE(w, flusher, "status", map[string]string{"status": "failed", "error": "authentication timed out"})
			return
		case <-ticker.C:
			encryptedAuth, pollErr := h.platformService.PollAuth(pollCtx, userID, platformName, authRef, h.masterKey)
			if pollErr != nil {
				writeSSE(w, flusher, "status", map[string]string{"status": "failed", "error": sanitizeError(pollErr)})
				return
			}
			if encryptedAuth == nil {
				// Still waiting.
				writeSSE(w, flusher, "status", map[string]string{"status": "waiting"})
				continue
			}

			// Auth succeeded.
			writeSSE(w, flusher, "status", map[string]string{"status": "done"})
			return
		}
	}
}

func (h *PlatformHandler) Disconnect(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platformName := chi.URLParam(r, "platform")
	if err := validateRequired(platformName, "platform"); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}

	if err := h.platformService.Disconnect(r.Context(), userID, platformName); err != nil {
		writeError(w, r, http.StatusInternalServerError, "disconnect_error", "Failed to disconnect platform")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *PlatformHandler) Verify(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	platformName := chi.URLParam(r, "platform")
	if err := validateRequired(platformName, "platform"); err != nil {
		writeValidationError(w, err.(*ValidationError))
		return
	}

	conn, err := h.platformService.Verify(r.Context(), userID, platformName)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]interface{}{
			"valid": false,
			"error": err.Error(),
		})
		return
	}

	writeJSON(w, http.StatusOK, conn)
}

// writeSSE marshals data to JSON and writes a server-sent event.
func writeSSE(w http.ResponseWriter, flusher http.Flusher, event string, data interface{}) {
	jsonData, err := json.Marshal(data)
	if err != nil {
		slog.Error("failed to marshal SSE data", "error", err)
		return
	}
	fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event, jsonData)
	flusher.Flush()
}

// sanitizeError truncates and sanitizes error messages to avoid leaking
// internal details in SSE responses.
func sanitizeError(err error) string {
	msg := err.Error()
	if len(msg) > 200 {
		msg = msg[:200] + "..."
	}
	return msg
}
