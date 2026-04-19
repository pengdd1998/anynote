package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

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
	if ct != "application/json" {
		t.Errorf("Content-Type = %q, want %q", ct, "application/json")
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
	writeError(w, http.StatusBadRequest, "test_error", "something went wrong")

	if w.Code != http.StatusBadRequest {
		t.Errorf("writeError status = %d, want %d", w.Code, http.StatusBadRequest)
	}

	ct := w.Header().Get("Content-Type")
	if ct != "application/json" {
		t.Errorf("Content-Type = %q, want %q", ct, "application/json")
	}

	var resp domain.ErrorResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Error != "test_error" {
		t.Errorf("error = %q, want %q", resp.Error, "test_error")
	}
	if resp.Message != "something went wrong" {
		t.Errorf("message = %q, want %q", resp.Message, "something went wrong")
	}
}

func TestWriteErrorFromSentinel(t *testing.T) {
	tests := []struct {
		name         string
		err          error
		wantStatus   int
		wantErrType  string
		wantHandled  bool
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
			handled := writeErrorFromSentinel(w, tt.err)

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
				if resp.Error != tt.wantErrType {
					t.Errorf("error = %q, want %q", resp.Error, tt.wantErrType)
				}
			}
		})
	}
}
