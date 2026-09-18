package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/anynote/backend/internal/domain"
)

// GetSalt must reject a missing email, reject malformed emails, serve the
// stored salt for existing accounts, and serve a deterministic fake salt for
// unknown accounts (anti-enumeration).
func TestAuthHandler_GetSalt(t *testing.T) {
	svc := &mockAuthService{
		getSaltByEmailFn: func(ctx context.Context, email string) (*domain.SaltResponse, error) {
			if email == "known@example.com" {
				return &domain.SaltResponse{Salt: []byte{1, 2, 3}}, nil
			}
			return nil, context.DeadlineExceeded
		},
	}
	r := setupAuthRouter(svc)

	// Missing email parameter -> 400.
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/salt", nil)
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("missing email: status = %d, want 400", rec.Code)
	}

	// Malformed email -> validation error status.
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/auth/salt?email=not-an-email", nil)
	r.ServeHTTP(rec, req)
	if rec.Code == http.StatusOK {
		t.Errorf("malformed email: status = %d, want non-200", rec.Code)
	}

	// Known account -> stored salt served with 200.
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/auth/salt?email=known@example.com", nil)
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Errorf("known account: status = %d, want 200", rec.Code)
	}

	// Unknown account (backend error) -> 200 with deterministic fake salt.
	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/api/v1/auth/salt?email=unknown@example.com", nil)
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Errorf("unknown account: status = %d, want 200", rec.Code)
	}

}
