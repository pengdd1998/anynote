package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock ShareService
// ---------------------------------------------------------------------------

type mockShareService struct {
	createShareFn    func(ctx context.Context, userID uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error)
	getShareFn       func(ctx context.Context, id string) (*domain.GetShareResponse, error)
	discoverFeedFn   func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error)
	toggleReactionFn func(ctx context.Context, userID uuid.UUID, shareID string, reactionType string) (*domain.ReactResponse, error)
}

func (m *mockShareService) CreateShare(ctx context.Context, userID uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
	if m.createShareFn != nil {
		return m.createShareFn(ctx, userID, req)
	}
	return nil, errors.New("not implemented")
}

func (m *mockShareService) GetShare(ctx context.Context, id string) (*domain.GetShareResponse, error) {
	if m.getShareFn != nil {
		return m.getShareFn(ctx, id)
	}
	return nil, errors.New("not implemented")
}

func (m *mockShareService) DiscoverFeed(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
	if m.discoverFeedFn != nil {
		return m.discoverFeedFn(ctx, limit, offset)
	}
	return nil, errors.New("not implemented")
}

func (m *mockShareService) ToggleReaction(ctx context.Context, userID uuid.UUID, shareID string, reactionType string) (*domain.ReactResponse, error) {
	if m.toggleReactionFn != nil {
		return m.toggleReactionFn(ctx, userID, shareID, reactionType)
	}
	return nil, errors.New("not implemented")
}

// ---------------------------------------------------------------------------
// Router setup helper
// ---------------------------------------------------------------------------

// setupShareRouter creates a chi Mux with share routes wired, matching the
// real route layout from router.go.
func setupShareRouter(svc *mockShareService) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestLogger)

	h := &ShareHandler{shareService: svc}

	// Public routes (no auth).
	r.Get("/api/v1/share/{id}", h.GetShare)
	r.Get("/api/v1/share/discover", h.DiscoverFeed)

	// Authenticated routes.
	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		r.Post("/api/v1/share", h.CreateShare)
		r.Post("/api/v1/share/{id}/react", h.ToggleReaction)
	})

	return r
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/share (CreateShare)
// ---------------------------------------------------------------------------

func TestShareHandler_CreateShare_Success(t *testing.T) {
	shareID := "abc123def456abc123def456abc123de"
	userID := uuid.New()

	svc := &mockShareService{
		createShareFn: func(ctx context.Context, uid uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			return &domain.CreateShareResponse{
				ID:  shareID,
				URL: "/share/" + shareID,
			}, nil
		},
	}

	router := setupShareRouter(svc)

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "enc-content-blob",
		EncryptedTitle:   "enc-title-blob",
		ShareKeyHash:     "keyhash123",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusCreated, rec.Body.String())
	}

	var resp domain.CreateShareResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.ID != shareID {
		t.Errorf("ID = %q, want %q", resp.ID, shareID)
	}
	if resp.URL != "/share/"+shareID {
		t.Errorf("URL = %q, want %q", resp.URL, "/share/"+shareID)
	}
}

func TestShareHandler_CreateShare_Unauthorized(t *testing.T) {
	svc := &mockShareService{}
	router := setupShareRouter(svc)

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "content",
		EncryptedTitle:   "title",
		ShareKeyHash:     "hash",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestShareHandler_CreateShare_InvalidBody(t *testing.T) {
	svc := &mockShareService{}
	router := setupShareRouter(svc)

	userID := uuid.New()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/share", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "invalid_request" {
		t.Errorf("error type = %q, want %q", errResp.Error, "invalid_request")
	}
}

func TestShareHandler_CreateShare_MissingEncryptedContent(t *testing.T) {
	svc := &mockShareService{}
	router := setupShareRouter(svc)

	userID := uuid.New()
	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedTitle: "title",
		ShareKeyHash:   "hash",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error, "validation_error")
	}
}

func TestShareHandler_CreateShare_MissingShareKeyHash(t *testing.T) {
	svc := &mockShareService{}
	router := setupShareRouter(svc)

	userID := uuid.New()
	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "content",
		EncryptedTitle:   "title",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error, "validation_error")
	}
}

func TestShareHandler_CreateShare_ServiceError(t *testing.T) {
	svc := &mockShareService{
		createShareFn: func(ctx context.Context, uid uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
			return nil, errors.New("internal failure")
		},
	}

	router := setupShareRouter(svc)
	userID := uuid.New()

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "content",
		EncryptedTitle:   "title",
		ShareKeyHash:     "hash",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/share/{id} (GetShare)
// ---------------------------------------------------------------------------

func TestShareHandler_GetShare_Success(t *testing.T) {
	shareID := "abc123def456abc123def456abc123de"
	svc := &mockShareService{
		getShareFn: func(ctx context.Context, id string) (*domain.GetShareResponse, error) {
			if id != shareID {
				t.Errorf("id = %q, want %q", id, shareID)
			}
			return &domain.GetShareResponse{
				ID:               id,
				EncryptedContent: "enc-content",
				EncryptedTitle:   "enc-title",
				ViewCount:        1,
			}, nil
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/"+shareID, nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.GetShareResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.ID != shareID {
		t.Errorf("ID = %q, want %q", resp.ID, shareID)
	}
	if resp.EncryptedContent != "enc-content" {
		t.Errorf("EncryptedContent = %q, want %q", resp.EncryptedContent, "enc-content")
	}
}

func TestShareHandler_GetShare_NotFound(t *testing.T) {
	svc := &mockShareService{
		getShareFn: func(ctx context.Context, id string) (*domain.GetShareResponse, error) {
			return nil, service.ErrShareNotFound
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/nonexistent", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusNotFound, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "not_found" {
		t.Errorf("error type = %q, want %q", errResp.Error, "not_found")
	}
}

func TestShareHandler_GetShare_Expired(t *testing.T) {
	svc := &mockShareService{
		getShareFn: func(ctx context.Context, id string) (*domain.GetShareResponse, error) {
			return nil, service.ErrShareExpired
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/expired-share", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusGone {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusGone, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "expired" {
		t.Errorf("error type = %q, want %q", errResp.Error, "expired")
	}
}

func TestShareHandler_GetShare_MaxViewsReached(t *testing.T) {
	svc := &mockShareService{
		getShareFn: func(ctx context.Context, id string) (*domain.GetShareResponse, error) {
			return nil, service.ErrShareMaxViews
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/maxed-share", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusGone {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusGone, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "max_views" {
		t.Errorf("error type = %q, want %q", errResp.Error, "max_views")
	}
}

func TestShareHandler_GetShare_InternalError(t *testing.T) {
	svc := &mockShareService{
		getShareFn: func(ctx context.Context, id string) (*domain.GetShareResponse, error) {
			return nil, errors.New("unexpected db error")
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/some-share", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/share/discover (DiscoverFeed)
// ---------------------------------------------------------------------------

func TestShareHandler_DiscoverFeed_Success(t *testing.T) {
	svc := &mockShareService{
		discoverFeedFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			return []domain.DiscoverFeedItem{
				{ID: "share1", EncryptedTitle: "title1", ViewCount: 10, ReactionHeart: 3},
				{ID: "share2", EncryptedTitle: "title2", ViewCount: 5, ReactionHeart: 1},
			}, nil
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/discover", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var items []domain.DiscoverFeedItem
	if err := json.NewDecoder(rec.Body).Decode(&items); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(items) != 2 {
		t.Errorf("items count = %d, want 2", len(items))
	}
}

func TestShareHandler_DiscoverFeed_EmptyResult(t *testing.T) {
	svc := &mockShareService{
		discoverFeedFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			return nil, nil
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/discover", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var items []domain.DiscoverFeedItem
	if err := json.NewDecoder(rec.Body).Decode(&items); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	// Handler converts nil to empty slice, so JSON should be [] not null.
	if items == nil {
		t.Error("items should not be nil (handler should return empty array)")
	}
	if len(items) != 0 {
		t.Errorf("items count = %d, want 0", len(items))
	}
}

func TestShareHandler_DiscoverFeed_WithPagination(t *testing.T) {
	var capturedLimit, capturedOffset int
	svc := &mockShareService{
		discoverFeedFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			capturedLimit = limit
			capturedOffset = offset
			return []domain.DiscoverFeedItem{}, nil
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/discover?limit=5&offset=10", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if capturedLimit != 5 {
		t.Errorf("limit = %d, want 5", capturedLimit)
	}
	if capturedOffset != 10 {
		t.Errorf("offset = %d, want 10", capturedOffset)
	}
}

func TestShareHandler_DiscoverFeed_ServiceError(t *testing.T) {
	svc := &mockShareService{
		discoverFeedFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			return nil, errors.New("db failure")
		},
	}

	router := setupShareRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/discover", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/share/{id}/react (ToggleReaction)
// ---------------------------------------------------------------------------

func TestShareHandler_ToggleReaction_Success(t *testing.T) {
	shareID := "abc123def456abc123def456abc123de"
	userID := uuid.New()

	svc := &mockShareService{
		toggleReactionFn: func(ctx context.Context, uid uuid.UUID, sid string, rType string) (*domain.ReactResponse, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if sid != shareID {
				t.Errorf("shareID = %q, want %q", sid, shareID)
			}
			if rType != "heart" {
				t.Errorf("reactionType = %q, want %q", rType, "heart")
			}
			return &domain.ReactResponse{ReactionType: "heart", Active: true, Count: 1}, nil
		},
	}

	router := setupShareRouter(svc)

	body, _ := json.Marshal(domain.ReactRequest{ReactionType: "heart"})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/"+shareID+"/react", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.ReactResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !resp.Active {
		t.Error("Active should be true")
	}
	if resp.Count != 1 {
		t.Errorf("Count = %d, want 1", resp.Count)
	}
}

func TestShareHandler_ToggleReaction_Unauthorized(t *testing.T) {
	svc := &mockShareService{}
	router := setupShareRouter(svc)

	body, _ := json.Marshal(domain.ReactRequest{ReactionType: "heart"})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/abc/react", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestShareHandler_ToggleReaction_InvalidBody(t *testing.T) {
	svc := &mockShareService{}
	router := setupShareRouter(svc)

	userID := uuid.New()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/abc/react", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

func TestShareHandler_ToggleReaction_ShareNotFound(t *testing.T) {
	svc := &mockShareService{
		toggleReactionFn: func(ctx context.Context, uid uuid.UUID, sid string, rType string) (*domain.ReactResponse, error) {
			return nil, service.ErrShareNotFound
		},
	}

	router := setupShareRouter(svc)
	userID := uuid.New()

	body, _ := json.Marshal(domain.ReactRequest{ReactionType: "heart"})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/nonexistent/react", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusNotFound, rec.Body.String())
	}
}

func TestShareHandler_ToggleReaction_InvalidReactionType(t *testing.T) {
	svc := &mockShareService{
		toggleReactionFn: func(ctx context.Context, uid uuid.UUID, sid string, rType string) (*domain.ReactResponse, error) {
			return nil, service.ErrInvalidReaction
		},
	}

	router := setupShareRouter(svc)
	userID := uuid.New()

	body, _ := json.Marshal(domain.ReactRequest{ReactionType: "invalid"})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/abc/react", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "invalid_reaction" {
		t.Errorf("error type = %q, want %q", errResp.Error, "invalid_reaction")
	}
}

func TestShareHandler_ToggleReaction_InternalError(t *testing.T) {
	svc := &mockShareService{
		toggleReactionFn: func(ctx context.Context, uid uuid.UUID, sid string, rType string) (*domain.ReactResponse, error) {
			return nil, errors.New("unexpected error")
		},
	}

	router := setupShareRouter(svc)
	userID := uuid.New()

	body, _ := json.Marshal(domain.ReactRequest{ReactionType: "heart"})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/abc/react", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Confirm testJWTSecret and generateTestToken are available.
// These are defined in auth_handler_test.go in the same package.
// ---------------------------------------------------------------------------

// Re-declare testJWTSecret if not already available (same package, so it is
// already declared in auth_handler_test.go). The Go test runner merges all
// _test.go files in the same package, so this is not needed. However, if
// share_handler_test.go is run in isolation (e.g. during IDE analysis), the
// compiler would complain. We avoid re-declaring by using a simple reference.
var _ = jwt.MapClaims{} // Ensure the import is used.
var _ = time.Now()      // Ensure the time import is used.
