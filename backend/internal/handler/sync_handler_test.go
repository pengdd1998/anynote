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
	pullFn        func(ctx context.Context, userID uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error)
	pushFn        func(ctx context.Context, userID uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error)
	getStatusFn   func(ctx context.Context, userID uuid.UUID) (*domain.SyncStatusResponse, error)
	getStatsFn    func(ctx context.Context, userID uuid.UUID) (*domain.SyncStatsResponse, error)
	listTagsFn    func(ctx context.Context, userID uuid.UUID) (*domain.ListTagsResponse, error)
	batchDeleteFn func(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (*domain.BatchDeleteResponse, error)
	getProgressFn func(ctx context.Context, userID uuid.UUID) (*domain.SyncProgressResponse, error)
}

func (m *mockSyncService) Pull(ctx context.Context, userID uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
	if m.pullFn != nil {
		return m.pullFn(ctx, userID, sinceVersion, limit, cursor)
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

func (m *mockSyncService) GetStats(ctx context.Context, userID uuid.UUID) (*domain.SyncStatsResponse, error) {
	if m.getStatsFn != nil {
		return m.getStatsFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockSyncService) ListTags(ctx context.Context, userID uuid.UUID) (*domain.ListTagsResponse, error) {
	if m.listTagsFn != nil {
		return m.listTagsFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockSyncService) BatchDelete(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (*domain.BatchDeleteResponse, error) {
	if m.batchDeleteFn != nil {
		return m.batchDeleteFn(ctx, userID, itemIDs)
	}
	return nil, errors.New("not implemented")
}

func (m *mockSyncService) GetProgress(ctx context.Context, userID uuid.UUID) (*domain.SyncProgressResponse, error) {
	if m.getProgressFn != nil {
		return m.getProgressFn(ctx, userID)
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
		r.Get("/api/v1/sync/stats", h.Stats)
		r.Get("/api/v1/sync/progress", h.Progress)
		r.Post("/api/v1/sync/batch-delete", h.BatchDelete)
		r.Get("/api/v1/tags", h.ListTags)
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
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
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
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
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
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
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
					{ItemID: itemID, ItemType: "note", ServerVersion: 9, ClientVersion: 8},
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

func TestSyncHandler_Status_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		getStatusFn: func(ctx context.Context, uid uuid.UUID) (*domain.SyncStatusResponse, error) {
			return nil, errors.New("database error")
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/status", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: Pull edge cases
// ---------------------------------------------------------------------------

func TestSyncHandler_Pull_NegativeSince(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull?since=-5", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

func TestSyncHandler_Pull_InvalidSince(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
			if sinceVersion != 0 {
				t.Errorf("sinceVersion = %d, want 0 (invalid param should default to 0)", sinceVersion)
			}
			return &domain.SyncPullResponse{LatestVersion: 1}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull?since=notanumber", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}
}

func TestSyncHandler_Pull_DefaultSince(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
			if sinceVersion != 0 {
				t.Errorf("sinceVersion = %d, want 0 (no param should default to 0)", sinceVersion)
			}
			return &domain.SyncPullResponse{LatestVersion: 1}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}

func TestSyncHandler_Push_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		pushFn: func(ctx context.Context, uid uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
			return nil, errors.New("database unavailable")
		},
	}

	router := setupSyncRouter(svc)

	pushReq := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: uuid.New(), Version: 1},
		},
	}
	body, _ := json.Marshal(pushReq)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/sync/stats
// ---------------------------------------------------------------------------

func TestSyncHandler_Stats_Success(t *testing.T) {
	userID := uuid.New()
	now := time.Now()

	svc := &mockSyncService{
		getStatsFn: func(ctx context.Context, uid uuid.UUID) (*domain.SyncStatsResponse, error) {
			return &domain.SyncStatsResponse{
				TotalItems: 42,
				ItemsByType: map[string]int{
					"note":       30,
					"tag":        10,
					"collection": 2,
				},
				LastSyncedAt:   now,
				TotalConflicts: 3,
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/stats", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.SyncStatsResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.TotalItems != 42 {
		t.Errorf("TotalItems = %d, want 42", resp.TotalItems)
	}
	if resp.ItemsByType["note"] != 30 {
		t.Errorf("ItemsByType[note] = %d, want 30", resp.ItemsByType["note"])
	}
	if resp.ItemsByType["tag"] != 10 {
		t.Errorf("ItemsByType[tag] = %d, want 10", resp.ItemsByType["tag"])
	}
	if resp.TotalConflicts != 3 {
		t.Errorf("TotalConflicts = %d, want 3", resp.TotalConflicts)
	}
}

func TestSyncHandler_Stats_Unauthorized(t *testing.T) {
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/stats", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestSyncHandler_Stats_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		getStatsFn: func(ctx context.Context, uid uuid.UUID) (*domain.SyncStatsResponse, error) {
			return nil, errors.New("database error")
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/stats", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/tags
// ---------------------------------------------------------------------------

func TestSyncHandler_ListTags_Success(t *testing.T) {
	userID := uuid.New()
	tag1 := uuid.New()
	tag2 := uuid.New()
	now := time.Now()

	svc := &mockSyncService{
		listTagsFn: func(ctx context.Context, uid uuid.UUID) (*domain.ListTagsResponse, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			return &domain.ListTagsResponse{
				Tags: []domain.TagListItem{
					{ItemID: tag1, Version: 3, BlobSize: 128, UpdatedAt: now},
					{ItemID: tag2, Version: 5, BlobSize: 256, UpdatedAt: now},
				},
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/tags", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.ListTagsResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if len(resp.Tags) != 2 {
		t.Fatalf("len(Tags) = %d, want 2", len(resp.Tags))
	}
	if resp.Tags[0].ItemID != tag1 {
		t.Errorf("Tags[0].ItemID = %v, want %v", resp.Tags[0].ItemID, tag1)
	}
	if resp.Tags[1].Version != 5 {
		t.Errorf("Tags[1].Version = %d, want 5", resp.Tags[1].Version)
	}
}

func TestSyncHandler_ListTags_Empty(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		listTagsFn: func(ctx context.Context, uid uuid.UUID) (*domain.ListTagsResponse, error) {
			return &domain.ListTagsResponse{Tags: nil}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/tags", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}

func TestSyncHandler_ListTags_Unauthorized(t *testing.T) {
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/tags", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestSyncHandler_ListTags_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		listTagsFn: func(ctx context.Context, uid uuid.UUID) (*domain.ListTagsResponse, error) {
			return nil, errors.New("database unavailable")
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/tags", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/sync/batch-delete
// ---------------------------------------------------------------------------

func TestSyncHandler_BatchDelete_Success(t *testing.T) {
	userID := uuid.New()
	id1 := uuid.New()
	id2 := uuid.New()

	svc := &mockSyncService{
		batchDeleteFn: func(ctx context.Context, uid uuid.UUID, itemIDs []uuid.UUID) (*domain.BatchDeleteResponse, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if len(itemIDs) != 2 {
				t.Errorf("len(itemIDs) = %d, want 2", len(itemIDs))
			}
			return &domain.BatchDeleteResponse{Deleted: 2}, nil
		},
	}

	router := setupSyncRouter(svc)

	body, _ := json.Marshal(domain.BatchDeleteRequest{ItemIDs: []uuid.UUID{id1, id2}})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/batch-delete", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.BatchDeleteResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.Deleted != 2 {
		t.Errorf("Deleted = %d, want 2", resp.Deleted)
	}
}

func TestSyncHandler_BatchDelete_EmptyList(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	body, _ := json.Marshal(domain.BatchDeleteRequest{ItemIDs: []uuid.UUID{}})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/batch-delete", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

func TestSyncHandler_BatchDelete_BatchTooLarge(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	ids := make([]uuid.UUID, 1001)
	for i := range ids {
		ids[i] = uuid.New()
	}

	body, _ := json.Marshal(domain.BatchDeleteRequest{ItemIDs: ids})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/batch-delete", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "batch_too_large" {
		t.Errorf("error type = %q, want %q", errResp.Error, "batch_too_large")
	}
}

func TestSyncHandler_BatchDelete_InvalidBody(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/batch-delete", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestSyncHandler_BatchDelete_Unauthorized(t *testing.T) {
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	body, _ := json.Marshal(domain.BatchDeleteRequest{ItemIDs: []uuid.UUID{uuid.New()}})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/batch-delete", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestSyncHandler_BatchDelete_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		batchDeleteFn: func(ctx context.Context, uid uuid.UUID, itemIDs []uuid.UUID) (*domain.BatchDeleteResponse, error) {
			return nil, errors.New("database unavailable")
		},
	}

	router := setupSyncRouter(svc)

	body, _ := json.Marshal(domain.BatchDeleteRequest{ItemIDs: []uuid.UUID{uuid.New()}})
	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/batch-delete", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/sync/progress
// ---------------------------------------------------------------------------

func TestSyncHandler_Progress_Success(t *testing.T) {
	userID := uuid.New()
	now := time.Now()

	svc := &mockSyncService{
		getProgressFn: func(ctx context.Context, uid uuid.UUID) (*domain.SyncProgressResponse, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			return &domain.SyncProgressResponse{
				TotalItems:    100,
				LatestVersion: 42,
				LastSyncedAt:  now,
				ConflictCount: 2,
				HealthStatus:  "ok",
				PushCount24h:  15,
				PullCount24h:  8,
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/progress", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.SyncProgressResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.TotalItems != 100 {
		t.Errorf("TotalItems = %d, want 100", resp.TotalItems)
	}
	if resp.HealthStatus != "ok" {
		t.Errorf("HealthStatus = %q, want %q", resp.HealthStatus, "ok")
	}
	if resp.PushCount24h != 15 {
		t.Errorf("PushCount24h = %d, want 15", resp.PushCount24h)
	}
}

func TestSyncHandler_Progress_Unauthorized(t *testing.T) {
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/progress", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestSyncHandler_Progress_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		getProgressFn: func(ctx context.Context, uid uuid.UUID) (*domain.SyncProgressResponse, error) {
			return nil, errors.New("database error")
		},
	}

	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/progress", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}
