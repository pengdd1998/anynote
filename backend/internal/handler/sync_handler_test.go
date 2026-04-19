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
)

// ---------------------------------------------------------------------------
// Mock SyncService
// ---------------------------------------------------------------------------

type mockSyncService struct {
	pullFn     func(ctx context.Context, userID uuid.UUID, sinceVersion int) (*domain.SyncPullResponse, error)
	pushFn     func(ctx context.Context, userID uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error)
	getStatusFn func(ctx context.Context, userID uuid.UUID) (*domain.SyncStatusResponse, error)
}

func (m *mockSyncService) Pull(ctx context.Context, userID uuid.UUID, sinceVersion int) (*domain.SyncPullResponse, error) {
	if m.pullFn != nil {
		return m.pullFn(ctx, userID, sinceVersion)
	}
	return nil, errors.New("not implemented")
}

func (m *mockSyncService) Push(ctx context.Context, userID uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
	if m.pushFn != nil {
		return m.pushFn(ctx, userID, req)
	}
	return nil, errors.New("not implemented")
}

func (m *mockSyncService) GetStatus(ctx context.Context, userID uuid.UUID) (*domain.SyncStatusResponse, error) {
	if m.getStatusFn != nil {
		return m.getStatusFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// setupSyncRouter creates a chi router wired with SyncHandler behind AuthMiddleware.
func setupSyncRouter(svc *mockSyncService) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestLogger)

	h := &SyncHandler{syncService: svc}

	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		r.Get("/api/v1/sync/pull", h.Pull)
		r.Post("/api/v1/sync/push", h.Push)
		r.Get("/api/v1/sync/status", h.Status)
	})

	return r
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/sync/pull
// ---------------------------------------------------------------------------

func TestSyncHandler_Pull_Success(t *testing.T) {
	userID := uuid.New()
	blobID := uuid.New()
	itemID := uuid.New()

	svc := &mockSyncService{
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int) (*domain.SyncPullResponse, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if sinceVersion != 5 {
				t.Errorf("sinceVersion = %d, want %d", sinceVersion, 5)
			}
			return &domain.SyncPullResponse{
				Blobs: []domain.SyncBlob{
					{
						ID:            blobID,
						UserID:        userID,
						ItemType:      "note",
						ItemID:        itemID,
						Version:       6,
						EncryptedData: []byte("encrypted"),
						BlobSize:      10,
					},
				},
				LatestVersion: 6,
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull?since=5", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.SyncPullResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.LatestVersion != 6 {
		t.Errorf("LatestVersion = %d, want %d", resp.LatestVersion, 6)
	}
	if len(resp.Blobs) != 1 {
		t.Fatalf("len(Blobs) = %d, want %d", len(resp.Blobs), 1)
	}
	if resp.Blobs[0].ItemID != itemID {
		t.Errorf("Blob.ItemID = %v, want %v", resp.Blobs[0].ItemID, itemID)
	}
}

func TestSyncHandler_Pull_EmptyResponse(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int) (*domain.SyncPullResponse, error) {
			return &domain.SyncPullResponse{
				Blobs:         []domain.SyncBlob{},
				LatestVersion: 10,
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull?since=10", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var resp domain.SyncPullResponse
	json.NewDecoder(rec.Body).Decode(&resp)

	if len(resp.Blobs) != 0 {
		t.Errorf("len(Blobs) = %d, want 0", len(resp.Blobs))
	}
	if resp.LatestVersion != 10 {
		t.Errorf("LatestVersion = %d, want 10", resp.LatestVersion)
	}
}

func TestSyncHandler_Pull_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int) (*domain.SyncPullResponse, error) {
			return nil, errors.New("database unavailable")
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusInternalServerError)
	}
}

func TestSyncHandler_Pull_Unauthorized(t *testing.T) {
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/sync/push
// ---------------------------------------------------------------------------

func TestSyncHandler_Push_Success(t *testing.T) {
	userID := uuid.New()
	itemID := uuid.New()

	svc := &mockSyncService{
		pushFn: func(ctx context.Context, uid uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
			return &domain.SyncPushResponse{
				Accepted: []uuid.UUID{itemID},
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	pushReq := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{
				ItemID:        itemID,
				ItemType:      "note",
				Version:       7,
				EncryptedData: []byte("encrypted-data"),
				BlobSize:      14,
			},
		},
	}
	body, _ := json.Marshal(pushReq)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.SyncPushResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if len(resp.Accepted) != 1 {
		t.Errorf("len(Accepted) = %d, want 1", len(resp.Accepted))
	}
	if resp.Accepted[0] != itemID {
		t.Errorf("Accepted[0] = %v, want %v", resp.Accepted[0], itemID)
	}
}

func TestSyncHandler_Push_Conflict(t *testing.T) {
	userID := uuid.New()
	itemID := uuid.New()

	svc := &mockSyncService{
		pushFn: func(ctx context.Context, uid uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
			return &domain.SyncPushResponse{
				Accepted: []uuid.UUID{},
				Conflicts: []domain.SyncConflict{
					{ItemID: itemID, ServerVersion: 9},
				},
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	pushReq := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{
				ItemID:  itemID,
				Version: 8,
			},
		},
	}
	body, _ := json.Marshal(pushReq)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.SyncPushResponse
	json.NewDecoder(rec.Body).Decode(&resp)

	if len(resp.Conflicts) != 1 {
		t.Fatalf("len(Conflicts) = %d, want 1", len(resp.Conflicts))
	}
	if resp.Conflicts[0].ServerVersion != 9 {
		t.Errorf("ServerVersion = %d, want 9", resp.Conflicts[0].ServerVersion)
	}
}

func TestSyncHandler_Push_EmptyBlobs(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	pushReq := domain.SyncPushRequest{Blobs: []domain.SyncPushItem{}}
	body, _ := json.Marshal(pushReq)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	// Empty blobs returns 200 with nil slices, not an error.
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}

func TestSyncHandler_Push_BatchTooLarge(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	// Create 1001 items to exceed the limit.
	items := make([]domain.SyncPushItem, 1001)
	for i := range items {
		items[i] = domain.SyncPushItem{
			ItemID:  uuid.New(),
			Version: i,
		}
	}

	pushReq := domain.SyncPushRequest{Blobs: items}
	body, _ := json.Marshal(pushReq)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "batch_too_large" {
		t.Errorf("error type = %q, want %q", errResp.Error, "batch_too_large")
	}
}

func TestSyncHandler_Push_InvalidBody(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestSyncHandler_Push_Unauthorized(t *testing.T) {
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	body, _ := json.Marshal(domain.SyncPushRequest{Blobs: []domain.SyncPushItem{}})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/sync/status
// ---------------------------------------------------------------------------

func TestSyncHandler_Status_Success(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		getStatusFn: func(ctx context.Context, uid uuid.UUID) (*domain.SyncStatusResponse, error) {
			return &domain.SyncStatusResponse{
				LatestVersion: 42,
				TotalItems:    150,
				LastSyncedAt:  time.Now(),
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/status", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.SyncStatusResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.LatestVersion != 42 {
		t.Errorf("LatestVersion = %d, want 42", resp.LatestVersion)
	}
	if resp.TotalItems != 150 {
		t.Errorf("TotalItems = %d, want 150", resp.TotalItems)
	}
}

func TestSyncHandler_Status_Unauthorized(t *testing.T) {
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/status", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}
