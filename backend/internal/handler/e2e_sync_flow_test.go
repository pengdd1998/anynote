package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// E2E Sync Flow: push encrypted blobs -> pull -> status
// ---------------------------------------------------------------------------

// TestE2ESyncFlow exercises the complete sync lifecycle:
// push encrypted blobs, pull them back, and check sync status.
func TestE2ESyncFlow(t *testing.T) {
	userID := uuid.New()
	itemID := uuid.New()
	blobID := uuid.New()

	// State that flows between push -> pull.
	pushedVersion := 7
	pushedData := []byte("e2e-encrypted-blob-data")

	// ------ mock service ------

	syncSvc := &mockSyncService{
		pushFn: func(ctx context.Context, uid uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
			if uid != userID {
				t.Errorf("push: userID = %v, want %v", uid, userID)
			}
			if len(req.Blobs) != 1 {
				t.Fatalf("push: len(Blobs) = %d, want 1", len(req.Blobs))
			}
			b := req.Blobs[0]
			if b.ItemID != itemID {
				t.Errorf("push: ItemID = %v, want %v", b.ItemID, itemID)
			}
			if b.ItemType != "note" {
				t.Errorf("push: ItemType = %q, want %q", b.ItemType, "note")
			}

			pushedVersion = b.Version
			pushedData = b.EncryptedData

			return &domain.SyncPushResponse{
				Accepted: []uuid.UUID{itemID},
			}, nil
		},
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
			if uid != userID {
				t.Errorf("pull: userID = %v, want %v", uid, userID)
			}
			return &domain.SyncPullResponse{
				Blobs: []domain.SyncBlob{
					{
						ID:            blobID,
						UserID:        userID,
						ItemType:      "note",
						ItemID:        itemID,
						Version:       pushedVersion,
						EncryptedData: pushedData,
						BlobSize:      len(pushedData),
						CreatedAt:     time.Now(),
						UpdatedAt:     time.Now(),
					},
				},
				LatestVersion: pushedVersion,
			}, nil
		},
		getStatusFn: func(ctx context.Context, uid uuid.UUID) (*domain.SyncStatusResponse, error) {
			if uid != userID {
				t.Errorf("status: userID = %v, want %v", uid, userID)
			}
			return &domain.SyncStatusResponse{
				LatestVersion: pushedVersion,
				TotalItems:    1,
				LastSyncedAt:  time.Now(),
			}, nil
		},
	}

	// ------ build router ------

	h := &SyncHandler{syncService: syncSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)

	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/sync/push", h.Push)
		authR.Get("/api/v1/sync/pull", h.Pull)
		authR.Get("/api/v1/sync/status", h.Status)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	client := server.Client()
	authHeader := "Bearer " + generateTestToken(userID.String())

	// ------ Step 1: POST /api/v1/sync/push (expect 200) ------

	t.Run("step1_push", func(t *testing.T) {
		pushReq := domain.SyncPushRequest{
			Blobs: []domain.SyncPushItem{
				{
					ItemID:        itemID,
					ItemType:      "note",
					Version:       7,
					EncryptedData: []byte("e2e-encrypted-blob-data"),
					BlobSize:      24,
				},
			},
		}
		body, _ := json.Marshal(pushReq)

		req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/sync/push", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("push: new request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", authHeader)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("push request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("push: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var pushResp domain.SyncPushResponse
		if err := json.NewDecoder(resp.Body).Decode(&pushResp); err != nil {
			t.Fatalf("push: decode: %v", err)
		}
		if len(pushResp.Accepted) != 1 {
			t.Fatalf("push: len(Accepted) = %d, want 1", len(pushResp.Accepted))
		}
		if pushResp.Accepted[0] != itemID {
			t.Errorf("push: Accepted[0] = %v, want %v", pushResp.Accepted[0], itemID)
		}
	})

	// ------ Step 2: GET /api/v1/sync/pull (expect 200) ------

	t.Run("step2_pull", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/sync/pull?since=0", nil)
		if err != nil {
			t.Fatalf("pull: new request: %v", err)
		}
		req.Header.Set("Authorization", authHeader)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("pull request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("pull: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var pullResp domain.SyncPullResponse
		if err := json.NewDecoder(resp.Body).Decode(&pullResp); err != nil {
			t.Fatalf("pull: decode: %v", err)
		}
		if pullResp.LatestVersion != pushedVersion {
			t.Errorf("pull: LatestVersion = %d, want %d", pullResp.LatestVersion, pushedVersion)
		}
		if len(pullResp.Blobs) != 1 {
			t.Fatalf("pull: len(Blobs) = %d, want 1", len(pullResp.Blobs))
		}
		blob := pullResp.Blobs[0]
		if blob.ItemID != itemID {
			t.Errorf("pull: Blob.ItemID = %v, want %v", blob.ItemID, itemID)
		}
		if blob.Version != pushedVersion {
			t.Errorf("pull: Blob.Version = %d, want %d", blob.Version, pushedVersion)
		}
	})

	// ------ Step 3: GET /api/v1/sync/status (expect 200) ------

	t.Run("step3_status", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/sync/status", nil)
		if err != nil {
			t.Fatalf("status: new request: %v", err)
		}
		req.Header.Set("Authorization", authHeader)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("status request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("status: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var statusResp domain.SyncStatusResponse
		if err := json.NewDecoder(resp.Body).Decode(&statusResp); err != nil {
			t.Fatalf("status: decode: %v", err)
		}
		if statusResp.LatestVersion != pushedVersion {
			t.Errorf("status: LatestVersion = %d, want %d", statusResp.LatestVersion, pushedVersion)
		}
		if statusResp.TotalItems != 1 {
			t.Errorf("status: TotalItems = %d, want 1", statusResp.TotalItems)
		}
	})
}

// TestE2ESyncFlow_PushConflict verifies that a push returning a conflict
// correctly surfaces the conflict data to the client.
func TestE2ESyncFlow_PushConflict(t *testing.T) {
	userID := uuid.New()
	itemID := uuid.New()

	syncSvc := &mockSyncService{
		pushFn: func(ctx context.Context, uid uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
			return &domain.SyncPushResponse{
				Accepted: []uuid.UUID{},
				Conflicts: []domain.SyncConflict{
					{ItemID: itemID, ServerVersion: 10},
				},
			}, nil
		},
	}

	h := &SyncHandler{syncService: syncSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/sync/push", h.Push)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	pushReq := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: itemID, ItemType: "note", Version: 8},
		},
	}
	body, _ := json.Marshal(pushReq)

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/sync/push", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("push request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var pushResp domain.SyncPushResponse
	if err := json.NewDecoder(resp.Body).Decode(&pushResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(pushResp.Conflicts) != 1 {
		t.Fatalf("len(Conflicts) = %d, want 1", len(pushResp.Conflicts))
	}
	if pushResp.Conflicts[0].ServerVersion != 10 {
		t.Errorf("ServerVersion = %d, want 10", pushResp.Conflicts[0].ServerVersion)
	}
	if pushResp.Conflicts[0].ItemID != itemID {
		t.Errorf("Conflict.ItemID = %v, want %v", pushResp.Conflicts[0].ItemID, itemID)
	}
}

// TestE2ESyncFlow_UnauthorizedPush verifies that push without a token
// returns 401.
func TestE2ESyncFlow_UnauthorizedPush(t *testing.T) {
	syncSvc := &mockSyncService{}
	h := &SyncHandler{syncService: syncSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/sync/push", h.Push)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: uuid.New(), Version: 1},
		},
	})

	resp, err := server.Client().Post(server.URL+"/api/v1/sync/push", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}

// TestE2ESyncFlow_PullIncremental verifies that pull with a since parameter
// returns only blobs with versions greater than the given value.
func TestE2ESyncFlow_PullIncremental(t *testing.T) {
	userID := uuid.New()
	sinceVersion := 5

	syncSvc := &mockSyncService{
		pullFn: func(ctx context.Context, uid uuid.UUID, since int, limit int, cursor int) (*domain.SyncPullResponse, error) {
			if since != sinceVersion {
				t.Errorf("pull: since = %d, want %d", since, sinceVersion)
			}
			return &domain.SyncPullResponse{
				Blobs:         []domain.SyncBlob{},
				LatestVersion: 10,
			}, nil
		},
	}

	h := &SyncHandler{syncService: syncSvc}
	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Get("/api/v1/sync/pull", h.Pull)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/sync/pull?since=5", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("pull request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var pullResp domain.SyncPullResponse
	if err := json.NewDecoder(resp.Body).Decode(&pullResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if pullResp.LatestVersion != 10 {
		t.Errorf("LatestVersion = %d, want 10", pullResp.LatestVersion)
	}
}
