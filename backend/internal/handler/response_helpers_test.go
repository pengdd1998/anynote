package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5/middleware"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

func TestWriteJSON(t *testing.T) {
	w := httptest.NewRecorder()
	data := map[string]string{"key": "value"}
	writeJSON(w, http.StatusOK, data)

	if w.Code != http.StatusOK {
		t.Errorf("writeJSON status = %d, want %d", w.Code, http.StatusOK)
	}

	ct := w.Header().Get("Content-Type")
	if ct != "application/json; charset=utf-8" {
		t.Errorf("Content-Type = %q, want %q", ct, "application/json; charset=utf-8")
	}

	var result map[string]string
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if result["key"] != "value" {
		t.Errorf("response key = %q, want %q", result["key"], "value")
	}
}

func TestWriteError(t *testing.T) {
	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/test", nil)
	// Add chi request ID to context for request_id extraction.
	ctx := context.WithValue(r.Context(), middleware.RequestIDKey, "test-req-123")
	r = r.WithContext(ctx)

	writeError(w, r, http.StatusBadRequest, "test_error", "something went wrong")

	if w.Code != http.StatusBadRequest {
		t.Errorf("writeError status = %d, want %d", w.Code, http.StatusBadRequest)
	}

	ct := w.Header().Get("Content-Type")
	if ct != "application/json; charset=utf-8" {
		t.Errorf("Content-Type = %q, want %q", ct, "application/json; charset=utf-8")
	}

	var resp domain.ErrorResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Error.Code != "test_error" {
		t.Errorf("error code = %q, want %q", resp.Error.Code, "test_error")
	}
	if resp.Error.Message != "something went wrong" {
		t.Errorf("error message = %q, want %q", resp.Error.Message, "something went wrong")
	}
	if resp.RequestID != "test-req-123" {
		t.Errorf("request_id = %q, want %q", resp.RequestID, "test-req-123")
	}
}

func TestWriteError_NilRequest(t *testing.T) {
	w := httptest.NewRecorder()
	// Passing nil request should not panic; request_id should be empty.
	writeError(w, nil, http.StatusInternalServerError, "internal_error", "something broke")

	if w.Code != http.StatusInternalServerError {
		t.Errorf("writeError status = %d, want %d", w.Code, http.StatusInternalServerError)
	}

	var resp domain.ErrorResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Error.Code != "internal_error" {
		t.Errorf("error code = %q, want %q", resp.Error.Code, "internal_error")
	}
	if resp.RequestID != "" {
		t.Errorf("request_id = %q, want empty string", resp.RequestID)
	}
}

func TestWriteErrorFromSentinel(t *testing.T) {
	tests := []struct {
		name        string
		err         error
		wantStatus  int
		wantErrCode string
		wantHandled bool
	}{
		{"email_exists", service.ErrEmailExists, http.StatusConflict, "email_exists", true},
		{"username_exists", service.ErrUsernameExists, http.StatusConflict, "username_exists", true},
		{"invalid_credentials", service.ErrInvalidCredentials, http.StatusUnauthorized, "invalid_credentials", true},
		{"user_not_found", service.ErrUserNotFound, http.StatusNotFound, "not_found", true},
		{"quota_exceeded", service.ErrQuotaExceeded, http.StatusTooManyRequests, "quota_exceeded", true},
		{"share_not_found", service.ErrShareNotFound, http.StatusNotFound, "not_found", true},
		{"share_expired", service.ErrShareExpired, http.StatusGone, "expired", true},
		{"share_max_views", service.ErrShareMaxViews, http.StatusGone, "max_views", true},
		{"unknown_error", errors.New("something else"), 0, "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			r := httptest.NewRequest("GET", "/test", nil)
			handled := writeErrorFromSentinel(w, r, tt.err)

			if handled != tt.wantHandled {
				t.Errorf("handled = %v, want %v", handled, tt.wantHandled)
			}

			if tt.wantHandled {
				if w.Code != tt.wantStatus {
					t.Errorf("status = %d, want %d", w.Code, tt.wantStatus)
				}

				var resp domain.ErrorResponse
				if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
					t.Fatalf("failed to decode response: %v", err)
				}
				if resp.Error.Code != tt.wantErrCode {
					t.Errorf("error code = %q, want %q", resp.Error.Code, tt.wantErrCode)
				}
			}
		})
	}
}
