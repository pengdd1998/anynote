//go:build integration

package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/repository"
	"github.com/anynote/backend/internal/service"
	"github.com/anynote/backend/internal/testutil"
)

// ---------------------------------------------------------------------------
// Shared integration test infrastructure (handler package)
// ---------------------------------------------------------------------------

// integrationPool holds the singleton *pgxpool.Pool for all handler integration
// tests. Initialized once by ensureHandlerPool.
var integrationPool *pgxpool.Pool

// handlerPoolOnce guards the one-time setup of the testcontainer database.
var handlerPoolOnce sync.Once

// TestMain manages the shared PostgreSQL testcontainer lifecycle for all
// integration tests in the handler package. When the integration build tag is
// not set this file is excluded entirely, so the regular unit-test TestMain (if
// any) takes over. The pool is created lazily on first use so that TestMain
// itself does not need a *testing.T.
func TestMain(m *testing.M) {
	code := m.Run()
	if integrationPool != nil {
		integrationPool.Close()
	}
	os.Exit(code)
}

// ensureHandlerPool lazily creates the testcontainer database and returns the
// shared connection pool. All integration tests should call this once.
func ensureHandlerPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	handlerPoolOnce.Do(func() {
		pc := testutil.SetupTestDB(t)
		integrationPool = pc.Pool
	})
	if integrationPool == nil {
		t.Fatal("integration pool not initialized")
	}
	return integrationPool
}

// seedTestUser creates a test user in the database and returns the UUID.
func seedTestUser(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
	t.Helper()
	id := uuid.New()
	email := fmt.Sprintf("handler-%s@example.com", id.String()[:8])
	username := fmt.Sprintf("handleruser_%s", id.String()[:8])
	testutil.SeedUser(t, pool, id.String(), email, username)
	return id
}

// setupIntegrationEnv initializes the DB, cleans tables, creates a real
// repository/service/handler stack, and returns the pool, userID, token, and
// a chi.Router wired with the sync routes behind AuthMiddleware.
func setupIntegrationEnv(t *testing.T) (*pgxpool.Pool, uuid.UUID, string, *chi.Mux) {
	t.Helper()
	pool := ensureHandlerPool(t)

	// Clean tables in dependency order.
	testutil.CleanTable(t, pool, "sync_operation_logs", "sync_blobs", "users")

	userID := seedTestUser(t, pool)

	// Build the real repository -> service -> handler stack.
	repo := repository.NewSyncBlobRepository(pool)
	syncSvc := service.NewSyncService(repo)
	syncH := &SyncHandler{syncService: syncSvc}

	// Build a chi.Router that mirrors the real route layout.
	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/sync/push", syncH.Push)
		authR.Get("/api/v1/sync/pull", syncH.Pull)
		authR.Get("/api/v1/sync/status", syncH.Status)
		authR.Post("/api/v1/sync/batch-delete", syncH.BatchDelete)
	})

	token := generateTestToken(userID.String())

	return pool, userID, token, r
}

// doJSONPost is a test helper that sends a JSON POST to the router and returns
// the response status code and decoded body.
func doJSONPost(t *testing.T, router *chi.Mux, token, path string, payload interface{}) (int, []byte) {
	t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec.Code, rec.Body.Bytes()
}

// doGet is a test helper that sends a GET to the router and returns the
// response status code and decoded body.
func doGet(t *testing.T, router *chi.Mux, token, path string) (int, []byte) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec.Code, rec.Body.Bytes()
}

// ---------------------------------------------------------------------------
// Test: full push -> status -> update -> conflict -> pull flow
// ---------------------------------------------------------------------------

// TestE2E_SyncPushPull exercises the full HTTP handler -> service ->
// repository -> PostgreSQL stack for the sync flow:
//   - Push 3 encrypted blobs, verify all accepted
//   - Get sync status, verify latest_version and total_items
//   - Push 1 blob at higher version (update), verify accepted
//   - Push 1 blob at lower version (conflict), verify conflict with server version
//   - Pull with since_version=0, verify all blobs returned
//   - Pull with since_version < latest, verify only newer blobs returned
func TestE2E_SyncPushPull(t *testing.T) {
	_, userID, token, router := setupIntegrationEnv(t)

	// Generate unique item IDs for the test.
	item1 := uuid.New()
	item2 := uuid.New()
	item3 := uuid.New()

	// -- Step 1: Push 3 encrypted blobs --

	pushReq := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: item1, ItemType: "note", Version: 1, EncryptedData: []byte("enc-data-1"), BlobSize: 10},
			{ItemID: item2, ItemType: "tag", Version: 2, EncryptedData: []byte("enc-data-2"), BlobSize: 10},
			{ItemID: item3, ItemType: "note", Version: 3, EncryptedData: []byte("enc-data-3"), BlobSize: 10},
		},
	}

	status, body := doJSONPost(t, router, token, "/api/v1/sync/push", pushReq)
	if status != http.StatusOK {
		t.Fatalf("push step1: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var pushResp domain.SyncPushResponse
	if err := json.Unmarshal(body, &pushResp); err != nil {
		t.Fatalf("push step1: unmarshal: %v", err)
	}
	if len(pushResp.Accepted) != 3 {
		t.Fatalf("push step1: len(Accepted) = %d, want 3", len(pushResp.Accepted))
	}
	if len(pushResp.Conflicts) != 0 {
		t.Fatalf("push step1: len(Conflicts) = %d, want 0", len(pushResp.Conflicts))
	}

	// -- Step 2: Get sync status --

	status, body = doGet(t, router, token, "/api/v1/sync/status")
	if status != http.StatusOK {
		t.Fatalf("status step2: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var statusResp domain.SyncStatusResponse
	if err := json.Unmarshal(body, &statusResp); err != nil {
		t.Fatalf("status step2: unmarshal: %v", err)
	}
	if statusResp.LatestVersion != 3 {
		t.Errorf("status step2: LatestVersion = %d, want 3", statusResp.LatestVersion)
	}
	if statusResp.TotalItems != 3 {
		t.Errorf("status step2: TotalItems = %d, want 3", statusResp.TotalItems)
	}

	// -- Step 3: Push update for item1 at higher version --

	updateReq := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: item1, ItemType: "note", Version: 10, EncryptedData: []byte("enc-data-1-v10"), BlobSize: 14},
		},
	}

	status, body = doJSONPost(t, router, token, "/api/v1/sync/push", updateReq)
	if status != http.StatusOK {
		t.Fatalf("push step3: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var updateResp domain.SyncPushResponse
	if err := json.Unmarshal(body, &updateResp); err != nil {
		t.Fatalf("push step3: unmarshal: %v", err)
	}
	if len(updateResp.Accepted) != 1 {
		t.Fatalf("push step3: len(Accepted) = %d, want 1", len(updateResp.Accepted))
	}
	if updateResp.Accepted[0] != item1 {
		t.Errorf("push step3: Accepted[0] = %v, want %v", updateResp.Accepted[0], item1)
	}

	// -- Step 4: Push item1 at lower version (conflict) --

	conflictReq := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: item1, ItemType: "note", Version: 5, EncryptedData: []byte("enc-data-1-v5"), BlobSize: 14},
		},
	}

	status, body = doJSONPost(t, router, token, "/api/v1/sync/push", conflictReq)
	if status != http.StatusOK {
		t.Fatalf("push step4: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var conflictResp domain.SyncPushResponse
	if err := json.Unmarshal(body, &conflictResp); err != nil {
		t.Fatalf("push step4: unmarshal: %v", err)
	}
	if len(conflictResp.Conflicts) != 1 {
		t.Fatalf("push step4: len(Conflicts) = %d, want 1", len(conflictResp.Conflicts))
	}
	if conflictResp.Conflicts[0].ItemID != item1 {
		t.Errorf("push step4: Conflict.ItemID = %v, want %v", conflictResp.Conflicts[0].ItemID, item1)
	}
	if conflictResp.Conflicts[0].ServerVersion != 10 {
		t.Errorf("push step4: Conflict.ServerVersion = %d, want 10", conflictResp.Conflicts[0].ServerVersion)
	}
	if conflictResp.Conflicts[0].ClientVersion != 5 {
		t.Errorf("push step4: Conflict.ClientVersion = %d, want 5", conflictResp.Conflicts[0].ClientVersion)
	}

	// -- Step 5: Pull all blobs since version 0 --

	status, body = doGet(t, router, token, "/api/v1/sync/pull?since=0")
	if status != http.StatusOK {
		t.Fatalf("pull step5: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var pullAll domain.SyncPullResponse
	if err := json.Unmarshal(body, &pullAll); err != nil {
		t.Fatalf("pull step5: unmarshal: %v", err)
	}
	// We expect 3 items: item1 (v10), item2 (v2), item3 (v3).
	if len(pullAll.Blobs) != 3 {
		t.Fatalf("pull step5: len(Blobs) = %d, want 3", len(pullAll.Blobs))
	}
	if pullAll.LatestVersion != 10 {
		t.Errorf("pull step5: LatestVersion = %d, want 10", pullAll.LatestVersion)
	}

	// Verify the returned blobs contain the expected items.
	found := map[uuid.UUID]bool{}
	for _, b := range pullAll.Blobs {
		found[b.ItemID] = true
		if b.UserID != userID {
			t.Errorf("pull step5: blob for item %s has UserID = %v, want %v", b.ItemID, b.UserID, userID)
		}
	}
	for _, id := range []uuid.UUID{item1, item2, item3} {
		if !found[id] {
			t.Errorf("pull step5: item %s not found in pull response", id)
		}
	}

	// -- Step 6: Pull with since_version=3 (should get only item1 at v10) --

	status, body = doGet(t, router, token, "/api/v1/sync/pull?since=3")
	if status != http.StatusOK {
		t.Fatalf("pull step6: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var pullDelta domain.SyncPullResponse
	if err := json.Unmarshal(body, &pullDelta); err != nil {
		t.Fatalf("pull step6: unmarshal: %v", err)
	}
	// Only item1 (v10) should be returned since it has version > 3.
	if len(pullDelta.Blobs) != 1 {
		t.Fatalf("pull step6: len(Blobs) = %d, want 1", len(pullDelta.Blobs))
	}
	if pullDelta.Blobs[0].ItemID != item1 {
		t.Errorf("pull step6: Blob.ItemID = %v, want %v", pullDelta.Blobs[0].ItemID, item1)
	}
	if pullDelta.Blobs[0].Version != 10 {
		t.Errorf("pull step6: Blob.Version = %d, want 10", pullDelta.Blobs[0].Version)
	}
}

// ---------------------------------------------------------------------------
// Test: batch delete flow
// ---------------------------------------------------------------------------

// TestE2E_SyncBatchDelete verifies the batch delete flow:
//   - Push 3 blobs
//   - Batch-delete 2 of them
//   - Verify deleted count
//   - Pull to verify only 1 remains
func TestE2E_SyncBatchDelete(t *testing.T) {
	_, _, token, router := setupIntegrationEnv(t)

	// Generate unique item IDs.
	item1 := uuid.New()
	item2 := uuid.New()
	item3 := uuid.New()

	// -- Step 1: Push 3 blobs --

	pushReq := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: item1, ItemType: "note", Version: 1, EncryptedData: []byte("del-data-1"), BlobSize: 10},
			{ItemID: item2, ItemType: "tag", Version: 2, EncryptedData: []byte("del-data-2"), BlobSize: 10},
			{ItemID: item3, ItemType: "note", Version: 3, EncryptedData: []byte("del-data-3"), BlobSize: 10},
		},
	}

	status, body := doJSONPost(t, router, token, "/api/v1/sync/push", pushReq)
	if status != http.StatusOK {
		t.Fatalf("push: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var pushResp domain.SyncPushResponse
	if err := json.Unmarshal(body, &pushResp); err != nil {
		t.Fatalf("push: unmarshal: %v", err)
	}
	if len(pushResp.Accepted) != 3 {
		t.Fatalf("push: len(Accepted) = %d, want 3", len(pushResp.Accepted))
	}

	// -- Step 2: Batch-delete item1 and item2 --

	delReq := domain.BatchDeleteRequest{
		ItemIDs: []uuid.UUID{item1, item2},
	}

	status, body = doJSONPost(t, router, token, "/api/v1/sync/batch-delete", delReq)
	if status != http.StatusOK {
		t.Fatalf("batch-delete: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var delResp domain.BatchDeleteResponse
	if err := json.Unmarshal(body, &delResp); err != nil {
		t.Fatalf("batch-delete: unmarshal: %v", err)
	}
	if delResp.Deleted != 2 {
		t.Errorf("batch-delete: Deleted = %d, want 2", delResp.Deleted)
	}

	// -- Step 3: Pull and verify only item3 remains --

	status, body = doGet(t, router, token, "/api/v1/sync/pull?since=0")
	if status != http.StatusOK {
		t.Fatalf("pull: status = %d, want %d; body: %s", status, http.StatusOK, body)
	}

	var pullResp domain.SyncPullResponse
	if err := json.Unmarshal(body, &pullResp); err != nil {
		t.Fatalf("pull: unmarshal: %v", err)
	}
	if len(pullResp.Blobs) != 1 {
		t.Fatalf("pull: len(Blobs) = %d, want 1", len(pullResp.Blobs))
	}
	if pullResp.Blobs[0].ItemID != item3 {
		t.Errorf("pull: Blob.ItemID = %v, want %v", pullResp.Blobs[0].ItemID, item3)
	}
	if pullResp.Blobs[0].Version != 3 {
		t.Errorf("pull: Blob.Version = %d, want 3", pullResp.Blobs[0].Version)
	}
}

// ---------------------------------------------------------------------------
// Test: user isolation (cross-user data should not leak)
// ---------------------------------------------------------------------------

// TestE2E_SyncUserIsolation verifies that one user cannot see or modify
// another user's sync data through the API.
func TestE2E_SyncUserIsolation(t *testing.T) {
	pool := ensureHandlerPool(t)
	testutil.CleanTable(t, pool, "sync_operation_logs", "sync_blobs", "users")

	// Create two separate users.
	userA := seedTestUser(t, pool)
	userB := seedTestUser(t, pool)

	tokenA := generateTestToken(userA.String())
	tokenB := generateTestToken(userB.String())

	repo := repository.NewSyncBlobRepository(pool)
	syncSvc := service.NewSyncService(repo)
	syncH := &SyncHandler{syncService: syncSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/sync/push", syncH.Push)
		authR.Get("/api/v1/sync/pull", syncH.Pull)
		authR.Get("/api/v1/sync/status", syncH.Status)
	})

	// User A pushes a blob.
	itemA := uuid.New()
	pushA := domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: itemA, ItemType: "note", Version: 1, EncryptedData: []byte("user-a-data"), BlobSize: 11},
		},
	}
	status, _ := doJSONPost(t, r, tokenA, "/api/v1/sync/push", pushA)
	if status != http.StatusOK {
		t.Fatalf("user A push: status = %d, want %d", status, http.StatusOK)
	}

	// User B pulls with since=0 -- should get zero blobs.
	status, body := doGet(t, r, tokenB, "/api/v1/sync/pull?since=0")
	if status != http.StatusOK {
		t.Fatalf("user B pull: status = %d, want %d", status, http.StatusOK)
	}
	var pullB domain.SyncPullResponse
	if err := json.Unmarshal(body, &pullB); err != nil {
		t.Fatalf("user B pull: unmarshal: %v", err)
	}
	if len(pullB.Blobs) != 0 {
		t.Errorf("user B pull: len(Blobs) = %d, want 0 (no data from user A)", len(pullB.Blobs))
	}

	// User B status should show zero items.
	status, body = doGet(t, r, tokenB, "/api/v1/sync/status")
	if status != http.StatusOK {
		t.Fatalf("user B status: status = %d, want %d", status, http.StatusOK)
	}
	var statusB domain.SyncStatusResponse
	if err := json.Unmarshal(body, &statusB); err != nil {
		t.Fatalf("user B status: unmarshal: %v", err)
	}
	if statusB.TotalItems != 0 {
		t.Errorf("user B status: TotalItems = %d, want 0", statusB.TotalItems)
	}

	// User A status should show 1 item.
	status, body = doGet(t, r, tokenA, "/api/v1/sync/status")
	if status != http.StatusOK {
		t.Fatalf("user A status: status = %d, want %d", status, http.StatusOK)
	}
	var statusA domain.SyncStatusResponse
	if err := json.Unmarshal(body, &statusA); err != nil {
		t.Fatalf("user A status: unmarshal: %v", err)
	}
	if statusA.TotalItems != 1 {
		t.Errorf("user A status: TotalItems = %d, want 1", statusA.TotalItems)
	}

	// Verify raw DB state to be thorough.
	ctx := context.Background()
	count, err := repo.CountItems(ctx, userA)
	if err != nil {
		t.Fatalf("count user A items: %v", err)
	}
	if count != 1 {
		t.Errorf("user A DB count = %d, want 1", count)
	}
	count, err = repo.CountItems(ctx, userB)
	if err != nil {
		t.Fatalf("count user B items: %v", err)
	}
	if count != 0 {
		t.Errorf("user B DB count = %d, want 0", count)
	}
}
