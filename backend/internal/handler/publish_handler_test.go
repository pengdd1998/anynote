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
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock PublishService
// ---------------------------------------------------------------------------

type mockPublishService struct {
	publishFn  func(ctx context.Context, userID uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error)
	historyFn  func(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error)
	getByIDFn  func(ctx context.Context, userID uuid.UUID, id uuid.UUID) (*domain.PublishLog, error)
}

func (m *mockPublishService) Publish(ctx context.Context, userID uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
	if m.publishFn != nil {
		return m.publishFn(ctx, userID, req)
	}
	return nil, errors.New("not implemented")
}

func (m *mockPublishService) GetHistory(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	if m.historyFn != nil {
		return m.historyFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockPublishService) GetByID(ctx context.Context, userID uuid.UUID, id uuid.UUID) (*domain.PublishLog, error) {
	if m.getByIDFn != nil {
		return m.getByIDFn(ctx, userID, id)
	}
	return nil, errors.New("not implemented")
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func setupPublishRouter(svc *mockPublishService) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestLogger)

	h := &PublishHandler{publishService: svc}

	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		r.Post("/api/v1/publish", h.Publish)
		r.Get("/api/v1/publish/history", h.History)
		r.Get("/api/v1/publish/{id}", h.GetByID)
	})

	return r
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/publish
// ---------------------------------------------------------------------------

func TestPublishHandler_Publish_Success(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()

	svc := &mockPublishService{
		publishFn: func(ctx context.Context, uid uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if req.Platform != "xiaohongshu" {
				t.Errorf("Platform = %q, want %q", req.Platform, "xiaohongshu")
			}
			return &domain.PublishLog{
				ID:       logID,
				UserID:   userID,
				Platform: "xiaohongshu",
				Title:    req.Title,
				Content:  req.Content,
				Status:   "pending",
			}, nil
		},
	}

	router := setupPublishRouter(svc)

	body, _ := json.Marshal(publishRequest{
		Platform:      "xiaohongshu",
		ContentItemID: "item-123",
		Title:         "My Note",
		Content:       "Note content",
		Tags:          []string{"tag1", "tag2"},
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/publish", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusAccepted, rec.Body.String())
	}

	var resp domain.PublishLog
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.ID != logID {
		t.Errorf("ID = %v, want %v", resp.ID, logID)
	}
	if resp.Status != "pending" {
		t.Errorf("Status = %q, want %q", resp.Status, "pending")
	}
	if resp.Platform != "xiaohongshu" {
		t.Errorf("Platform = %q, want %q", resp.Platform, "xiaohongshu")
	}
}

func TestPublishHandler_Publish_MissingPlatform(t *testing.T) {
	userID := uuid.New()
	svc := &mockPublishService{}
	router := setupPublishRouter(svc)

	body, _ := json.Marshal(publishRequest{
		Title:   "Test",
		Content: "Content",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/publish", bytes.NewReader(body))
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

func TestPublishHandler_Publish_InvalidBody(t *testing.T) {
	userID := uuid.New()
	svc := &mockPublishService{}
	router := setupPublishRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/publish", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestPublishHandler_Publish_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockPublishService{
		publishFn: func(ctx context.Context, uid uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
			return nil, errors.New("queue unavailable")
		},
	}

	router := setupPublishRouter(svc)

	body, _ := json.Marshal(publishRequest{
		Platform: "xiaohongshu",
		Title:    "Test",
		Content:  "Content",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/publish", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

func TestPublishHandler_Publish_Unauthorized(t *testing.T) {
	svc := &mockPublishService{}
	router := setupPublishRouter(svc)

	body, _ := json.Marshal(publishRequest{
		Platform: "xiaohongshu",
		Title:    "Test",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/publish", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/publish/history
// ---------------------------------------------------------------------------

func TestPublishHandler_History_Success(t *testing.T) {
	userID := uuid.New()
	logID1 := uuid.New()
	logID2 := uuid.New()

	svc := &mockPublishService{
		historyFn: func(ctx context.Context, uid uuid.UUID) ([]domain.PublishLog, error) {
			return []domain.PublishLog{
				{
					ID:        logID1,
					UserID:    userID,
					Platform:  "xiaohongshu",
					Title:     "Post 1",
					Status:    "published",
					CreatedAt: time.Now(),
				},
				{
					ID:        logID2,
					UserID:    userID,
					Platform:  "xiaohongshu",
					Title:     "Post 2",
					Status:    "pending",
					CreatedAt: time.Now(),
				},
			}, nil
		},
	}

	router := setupPublishRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/publish/history", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var logs []domain.PublishLog
	if err := json.NewDecoder(rec.Body).Decode(&logs); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if len(logs) != 2 {
		t.Fatalf("len(logs) = %d, want 2", len(logs))
	}
	if logs[0].Title != "Post 1" {
		t.Errorf("logs[0].Title = %q, want %q", logs[0].Title, "Post 1")
	}
	if logs[1].Status != "pending" {
		t.Errorf("logs[1].Status = %q, want %q", logs[1].Status, "pending")
	}
}

func TestPublishHandler_History_Empty(t *testing.T) {
	userID := uuid.New()

	svc := &mockPublishService{
		historyFn: func(ctx context.Context, uid uuid.UUID) ([]domain.PublishLog, error) {
			return []domain.PublishLog{}, nil
		},
	}

	router := setupPublishRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/publish/history", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}

func TestPublishHandler_History_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockPublishService{
		historyFn: func(ctx context.Context, uid uuid.UUID) ([]domain.PublishLog, error) {
			return nil, errors.New("database error")
		},
	}

	router := setupPublishRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/publish/history", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

func TestPublishHandler_History_Unauthorized(t *testing.T) {
	svc := &mockPublishService{}
	router := setupPublishRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/publish/history", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/publish/{id}
// ---------------------------------------------------------------------------

func TestPublishHandler_GetByID_Success(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()

	svc := &mockPublishService{
		getByIDFn: func(ctx context.Context, uid uuid.UUID, id uuid.UUID) (*domain.PublishLog, error) {
			if id != logID {
				t.Errorf("logID = %v, want %v", id, logID)
			}
			return &domain.PublishLog{
				ID:           logID,
				UserID:       userID,
				Platform:     "xiaohongshu",
				Title:        "Published Note",
				Status:       "published",
				PlatformURL:  "https://xiaohongshu.com/post/123",
				PublishedAt:  func() *time.Time { t := time.Now(); return &t }(),
				CreatedAt:    time.Now(),
			}, nil
		},
	}

	router := setupPublishRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/publish/"+logID.String(), nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.PublishLog
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.Title != "Published Note" {
		t.Errorf("Title = %q, want %q", resp.Title, "Published Note")
	}
	if resp.PlatformURL != "https://xiaohongshu.com/post/123" {
		t.Errorf("PlatformURL = %q, want %q", resp.PlatformURL, "https://xiaohongshu.com/post/123")
	}
}

func TestPublishHandler_GetByID_NotFound(t *testing.T) {
	userID := uuid.New()
	logID := uuid.New()

	svc := &mockPublishService{
		getByIDFn: func(ctx context.Context, uid uuid.UUID, id uuid.UUID) (*domain.PublishLog, error) {
			return nil, errors.New("not found")
		},
	}

	router := setupPublishRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/publish/"+logID.String(), nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusNotFound, rec.Body.String())
	}
}

func TestPublishHandler_GetByID_Unauthorized(t *testing.T) {
	svc := &mockPublishService{}
	router := setupPublishRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/publish/"+uuid.New().String(), nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}
