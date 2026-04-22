//go:build integration

package repository

import (
	"context"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/testutil"
)

// ---------------------------------------------------------------------------
// Shared integration test infrastructure
// ---------------------------------------------------------------------------

// integrationPool holds the singleton *pgxpool.Pool for all integration tests
// in this package. Initialized once by ensurePool.
var integrationPool *pgxpool.Pool

// poolOnce guards the one-time setup of the testcontainer database.
var poolOnce sync.Once

// TestMain manages the lifecycle of the shared PostgreSQL testcontainer.
// Since testutil.SetupTestDB requires *testing.T and TestMain does not receive
// one, we delegate the actual container creation to ensurePool (called lazily
// from the first test). TestMain simply runs all tests and exits.
func TestMain(m *testing.M) {
	code := m.Run()
	if integrationPool != nil {
		integrationPool.Close()
	}
	os.Exit(code)
}

// ensurePool initializes the testcontainer database on first call and returns
// the shared connection pool. Subsequent calls return the same pool.
func ensurePool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	poolOnce.Do(func() {
		pc := testutil.SetupTestDB(t)
		integrationPool = pc.Pool
	})
	if integrationPool == nil {
		t.Fatal("integration pool not initialized")
	}
	return integrationPool
}

// ---------------------------------------------------------------------------
// Test helpers (sync-blob specific)
// ---------------------------------------------------------------------------

// fakeEncryptedData returns deterministic fake ciphertext for tests.
func fakeEncryptedData(suffix int) []byte {
	return []byte(fmt.Sprintf("encrypted-data-%d", suffix))
}

// makeTestBlob creates a SyncBlob with fake encrypted data for the given user.
func makeTestBlob(userID uuid.UUID, itemType string, version int) *domain.SyncBlob {
	return &domain.SyncBlob{
		ID:            uuid.New(),
		UserID:        userID,
		ItemType:      itemType,
		ItemID:        uuid.New(),
		Version:       version,
		EncryptedData: fakeEncryptedData(version),
		BlobSize:      32,
	}
}

// seedSyncTestUser creates a test user via SeedUser and returns the UUID.
func seedSyncTestUser(t *testing.T) uuid.UUID {
	t.Helper()
	pool := ensurePool(t)
	id := uuid.New()
	email := fmt.Sprintf("sync-%s@example.com", id.String()[:8])
	username := fmt.Sprintf("syncuser_%s", id.String()[:8])
	testutil.SeedUser(t, pool, id.String(), email, username)
	return id
}

// syncTestRepo initializes the DB if needed, cleans sync-related tables, and
// returns a fresh SyncBlobRepository. Each test should call this once.
func syncTestRepo(t *testing.T) *SyncBlobRepository {
	t.Helper()
	pool := ensurePool(t)
	testutil.CleanTable(t, pool, "sync_operation_logs", "sync_blobs", "users")
	return NewSyncBlobRepository(pool)
}

// ---------------------------------------------------------------------------
// Tests: Upsert
// ---------------------------------------------------------------------------

func TestUpsert_Insert(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)
	blob := makeTestBlob(userID, "note", 1)

	accepted, err := repo.Upsert(ctx, blob)
	if err != nil {
		t.Fatalf("Upsert: %v", err)
	}
	if !accepted {
		t.Error("expected accepted=true for new blob")
	}

	// Verify the blob was persisted.
	count, err := repo.CountItems(ctx, userID)
	if err != nil {
		t.Fatalf("CountItems: %v", err)
	}
	if count != 1 {
		t.Errorf("CountItems = %d, want 1", count)
	}
}

func TestUpsert_Update(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)
	blob := makeTestBlob(userID, "note", 1)

	accepted, err := repo.Upsert(ctx, blob)
	if err != nil {
		t.Fatalf("first Upsert: %v", err)
	}
	if !accepted {
		t.Fatal("first upsert should be accepted")
	}

	// Update with higher version using the same ItemID.
	blob.Version = 5
	blob.EncryptedData = fakeEncryptedData(5)

	accepted, err = repo.Upsert(ctx, blob)
	if err != nil {
		t.Fatalf("second Upsert: %v", err)
	}
	if !accepted {
		t.Error("expected accepted=true for higher version update")
	}

	latest, err := repo.GetLatestVersion(ctx, userID)
	if err != nil {
		t.Fatalf("GetLatestVersion: %v", err)
	}
	if latest != 5 {
		t.Errorf("GetLatestVersion = %d, want 5", latest)
	}
}

func TestUpsert_Conflict(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)
	blob := makeTestBlob(userID, "note", 10)

	accepted, err := repo.Upsert(ctx, blob)
	if err != nil {
		t.Fatalf("first Upsert: %v", err)
	}
	if !accepted {
		t.Fatal("first upsert should be accepted")
	}

	// Attempt to push a lower version for the same item.
	blob.Version = 3
	blob.EncryptedData = fakeEncryptedData(3)

	accepted, err = repo.Upsert(ctx, blob)
	if err != nil {
		t.Fatalf("conflict Upsert: %v", err)
	}
	if accepted {
		t.Error("expected accepted=false for lower version (conflict)")
	}

	// Upsert should have updated blob.Version to the server version.
	if blob.Version != 10 {
		t.Errorf("blob.Version after conflict = %d, want 10 (server version)", blob.Version)
	}
}

// ---------------------------------------------------------------------------
// Tests: BatchUpsert
// ---------------------------------------------------------------------------

func TestBatchUpsert_Multiple(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	var blobs []*domain.SyncBlob
	for i := 1; i <= 5; i++ {
		blobs = append(blobs, makeTestBlob(userID, "note", i))
	}

	results := repo.BatchUpsert(ctx, blobs)
	if len(results) != 5 {
		t.Fatalf("len(results) = %d, want 5", len(results))
	}

	for i, r := range results {
		if !r.Accepted {
			t.Errorf("result[%d]: accepted=false, want true", i)
		}
		if r.Error != nil {
			t.Errorf("result[%d]: unexpected error: %v", i, r.Error)
		}
		if r.ItemID != blobs[i].ItemID {
			t.Errorf("result[%d].ItemID mismatch", i)
		}
	}

	count, err := repo.CountItems(ctx, userID)
	if err != nil {
		t.Fatalf("CountItems: %v", err)
	}
	if count != 5 {
		t.Errorf("CountItems = %d, want 5", count)
	}
}

func TestBatchUpsert_WithConflicts(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	// Pre-insert two blobs at high versions.
	existing1 := makeTestBlob(userID, "note", 10)
	existing2 := makeTestBlob(userID, "tag", 20)
	repo.Upsert(ctx, existing1)
	repo.Upsert(ctx, existing2)

	// Batch with: 2 new blobs, 2 conflicting (lower versions), 1 update (higher version).
	new1 := makeTestBlob(userID, "note", 1)
	new2 := makeTestBlob(userID, "tag", 1)

	// Conflicts: same item_type+item_id, but lower version.
	conflict1 := &domain.SyncBlob{
		ID: uuid.New(), UserID: userID, ItemType: "note",
		ItemID: existing1.ItemID, Version: 5,
		EncryptedData: fakeEncryptedData(5), BlobSize: 32,
	}
	conflict2 := &domain.SyncBlob{
		ID: uuid.New(), UserID: userID, ItemType: "tag",
		ItemID: existing2.ItemID, Version: 15,
		EncryptedData: fakeEncryptedData(15), BlobSize: 32,
	}

	// Update: higher version for existing1.
	update1 := &domain.SyncBlob{
		ID: uuid.New(), UserID: userID, ItemType: "note",
		ItemID: existing1.ItemID, Version: 15,
		EncryptedData: fakeEncryptedData(15), BlobSize: 32,
	}

	blobs := []*domain.SyncBlob{new1, new2, conflict1, conflict2, update1}
	results := repo.BatchUpsert(ctx, blobs)

	if len(results) != 5 {
		t.Fatalf("len(results) = %d, want 5", len(results))
	}

	// new1, new2 accepted.
	if !results[0].Accepted {
		t.Error("new1 should be accepted")
	}
	if !results[1].Accepted {
		t.Error("new2 should be accepted")
	}

	// conflict1, conflict2 rejected.
	if results[2].Accepted {
		t.Error("conflict1 should be rejected")
	}
	if results[2].ServerVersion != 10 {
		t.Errorf("conflict1 ServerVersion = %d, want 10", results[2].ServerVersion)
	}
	if results[3].Accepted {
		t.Error("conflict2 should be rejected")
	}
	if results[3].ServerVersion != 20 {
		t.Errorf("conflict2 ServerVersion = %d, want 20", results[3].ServerVersion)
	}

	// update1 accepted.
	if !results[4].Accepted {
		t.Error("update1 (higher version) should be accepted")
	}

	// Total items: existing1 (updated), existing2 (kept), new1, new2 = 4.
	count, _ := repo.CountItems(ctx, userID)
	if count != 4 {
		t.Errorf("CountItems = %d, want 4", count)
	}
}

// ---------------------------------------------------------------------------
// Tests: BatchDelete
// ---------------------------------------------------------------------------

func TestBatchDelete(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	b1 := makeTestBlob(userID, "note", 1)
	b2 := makeTestBlob(userID, "note", 2)
	b3 := makeTestBlob(userID, "tag", 3)

	repo.Upsert(ctx, b1)
	repo.Upsert(ctx, b2)
	repo.Upsert(ctx, b3)

	// Delete b1 and b2.
	deleted, err := repo.BatchDelete(ctx, userID, []uuid.UUID{b1.ItemID, b2.ItemID})
	if err != nil {
		t.Fatalf("BatchDelete: %v", err)
	}
	if deleted != 2 {
		t.Errorf("deleted = %d, want 2", deleted)
	}

	count, _ := repo.CountItems(ctx, userID)
	if count != 1 {
		t.Errorf("CountItems after delete = %d, want 1", count)
	}
}

func TestBatchDelete_Empty(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	deleted, err := repo.BatchDelete(ctx, userID, nil)
	if err != nil {
		t.Fatalf("BatchDelete with nil: %v", err)
	}
	if deleted != 0 {
		t.Errorf("deleted = %d, want 0 for nil itemIDs", deleted)
	}

	deleted, err = repo.BatchDelete(ctx, userID, []uuid.UUID{})
	if err != nil {
		t.Fatalf("BatchDelete with empty slice: %v", err)
	}
	if deleted != 0 {
		t.Errorf("deleted = %d, want 0 for empty itemIDs", deleted)
	}
}

// ---------------------------------------------------------------------------
// Tests: PullSince
// ---------------------------------------------------------------------------

func TestPullSince(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	// Insert blobs at versions 1, 3, 5, 7, 9.
	for _, v := range []int{1, 3, 5, 7, 9} {
		repo.Upsert(ctx, makeTestBlob(userID, "note", v))
	}

	// Pull everything since version 5 (should get versions 7 and 9).
	blobs, err := repo.PullSince(ctx, userID, 5)
	if err != nil {
		t.Fatalf("PullSince: %v", err)
	}
	if len(blobs) != 2 {
		t.Fatalf("len(blobs) = %d, want 2", len(blobs))
	}

	// Verify versions are ordered ascending.
	if blobs[0].Version != 7 {
		t.Errorf("blobs[0].Version = %d, want 7", blobs[0].Version)
	}
	if blobs[1].Version != 9 {
		t.Errorf("blobs[1].Version = %d, want 9", blobs[1].Version)
	}

	// Pull since version 9 should return nothing.
	blobs, err = repo.PullSince(ctx, userID, 9)
	if err != nil {
		t.Fatalf("PullSince(9): %v", err)
	}
	if len(blobs) != 0 {
		t.Errorf("len(blobs) since 9 = %d, want 0", len(blobs))
	}
}

// ---------------------------------------------------------------------------
// Tests: PullSincePaginated
// ---------------------------------------------------------------------------

func TestPullSincePaginated(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	// Insert 5 blobs.
	for i := 1; i <= 5; i++ {
		repo.Upsert(ctx, makeTestBlob(userID, "note", i))
	}

	// Request first page of 2 since version 0.
	page1, err := repo.PullSincePaginated(ctx, userID, 0, 2)
	if err != nil {
		t.Fatalf("PullSincePaginated page1: %v", err)
	}
	if len(page1) != 2 {
		t.Fatalf("len(page1) = %d, want 2", len(page1))
	}
	if page1[0].Version != 1 || page1[1].Version != 2 {
		t.Errorf("page1 versions = [%d, %d], want [1, 2]", page1[0].Version, page1[1].Version)
	}

	// Request second page since version 2.
	page2, err := repo.PullSincePaginated(ctx, userID, 2, 2)
	if err != nil {
		t.Fatalf("PullSincePaginated page2: %v", err)
	}
	if len(page2) != 2 {
		t.Fatalf("len(page2) = %d, want 2", len(page2))
	}
	if page2[0].Version != 3 || page2[1].Version != 4 {
		t.Errorf("page2 versions = [%d, %d], want [3, 4]", page2[0].Version, page2[1].Version)
	}
}

// ---------------------------------------------------------------------------
// Tests: HasMoreSince
// ---------------------------------------------------------------------------

func TestHasMoreSince(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	// Insert blobs at versions 1, 5, 10.
	for _, v := range []int{1, 5, 10} {
		repo.Upsert(ctx, makeTestBlob(userID, "note", v))
	}

	// There are blobs newer than version 5.
	hasMore, err := repo.HasMoreSince(ctx, userID, 5)
	if err != nil {
		t.Fatalf("HasMoreSince(5): %v", err)
	}
	if !hasMore {
		t.Error("expected hasMore=true since version 5")
	}

	// No blobs newer than version 10.
	hasMore, err = repo.HasMoreSince(ctx, userID, 10)
	if err != nil {
		t.Fatalf("HasMoreSince(10): %v", err)
	}
	if hasMore {
		t.Error("expected hasMore=false since version 10 (latest)")
	}

	// No blobs at all for a random user.
	hasMore, err = repo.HasMoreSince(ctx, userID, 100)
	if err != nil {
		t.Fatalf("HasMoreSince(100): %v", err)
	}
	if hasMore {
		t.Error("expected hasMore=false since version 100 (beyond all)")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetLatestVersion
// ---------------------------------------------------------------------------

func TestGetLatestVersion(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	// No blobs yet.
	v, err := repo.GetLatestVersion(ctx, userID)
	if err != nil {
		t.Fatalf("GetLatestVersion (empty): %v", err)
	}
	if v != 0 {
		t.Errorf("GetLatestVersion on empty = %d, want 0", v)
	}

	// Insert blobs.
	repo.Upsert(ctx, makeTestBlob(userID, "note", 3))
	repo.Upsert(ctx, makeTestBlob(userID, "tag", 7))
	repo.Upsert(ctx, makeTestBlob(userID, "note", 12))

	v, err = repo.GetLatestVersion(ctx, userID)
	if err != nil {
		t.Fatalf("GetLatestVersion: %v", err)
	}
	if v != 12 {
		t.Errorf("GetLatestVersion = %d, want 12", v)
	}
}

// ---------------------------------------------------------------------------
// Tests: CountItems
// ---------------------------------------------------------------------------

func TestCountItems(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	count, err := repo.CountItems(ctx, userID)
	if err != nil {
		t.Fatalf("CountItems (empty): %v", err)
	}
	if count != 0 {
		t.Errorf("CountItems on empty = %d, want 0", count)
	}

	repo.Upsert(ctx, makeTestBlob(userID, "note", 1))
	repo.Upsert(ctx, makeTestBlob(userID, "note", 2))
	repo.Upsert(ctx, makeTestBlob(userID, "tag", 3))

	count, err = repo.CountItems(ctx, userID)
	if err != nil {
		t.Fatalf("CountItems: %v", err)
	}
	if count != 3 {
		t.Errorf("CountItems = %d, want 3", count)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetStatusSummary
// ---------------------------------------------------------------------------

func TestGetStatusSummary(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	// Empty user.
	summary, err := repo.GetStatusSummary(ctx, userID)
	if err != nil {
		t.Fatalf("GetStatusSummary (empty): %v", err)
	}
	if summary.LatestVersion != 0 {
		t.Errorf("empty LatestVersion = %d, want 0", summary.LatestVersion)
	}
	if summary.TotalItems != 0 {
		t.Errorf("empty TotalItems = %d, want 0", summary.TotalItems)
	}

	// Insert blobs.
	repo.Upsert(ctx, makeTestBlob(userID, "note", 3))
	repo.Upsert(ctx, makeTestBlob(userID, "note", 8))

	summary, err = repo.GetStatusSummary(ctx, userID)
	if err != nil {
		t.Fatalf("GetStatusSummary: %v", err)
	}
	if summary.LatestVersion != 8 {
		t.Errorf("LatestVersion = %d, want 8", summary.LatestVersion)
	}
	if summary.TotalItems != 2 {
		t.Errorf("TotalItems = %d, want 2", summary.TotalItems)
	}
	if summary.LastUpdated.IsZero() {
		t.Error("LastUpdated should not be zero after inserting blobs")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetItemsByType
// ---------------------------------------------------------------------------

func TestGetItemsByType(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	// Insert blobs of various types.
	repo.Upsert(ctx, makeTestBlob(userID, "note", 1))
	repo.Upsert(ctx, makeTestBlob(userID, "note", 2))
	repo.Upsert(ctx, makeTestBlob(userID, "tag", 3))
	repo.Upsert(ctx, makeTestBlob(userID, "collection", 4))

	typeCounts, err := repo.GetItemsByType(ctx, userID)
	if err != nil {
		t.Fatalf("GetItemsByType: %v", err)
	}

	if typeCounts["note"] != 2 {
		t.Errorf("note count = %d, want 2", typeCounts["note"])
	}
	if typeCounts["tag"] != 1 {
		t.Errorf("tag count = %d, want 1", typeCounts["tag"])
	}
	if typeCounts["collection"] != 1 {
		t.Errorf("collection count = %d, want 1", typeCounts["collection"])
	}
	if _, ok := typeCounts["content"]; ok {
		t.Error("unexpected 'content' key in type counts")
	}
}

// ---------------------------------------------------------------------------
// Tests: OperationLogs (InsertOperationLog, GetConflictCount, GetOperationCounts)
// ---------------------------------------------------------------------------

func TestOperationLogs(t *testing.T) {
	repo := syncTestRepo(t)
	ctx := context.Background()

	userID := seedSyncTestUser(t)

	now := time.Now().UTC().Truncate(time.Microsecond)

	// Insert a push operation log (successful, version > 0).
	pushLog := &domain.SyncOperationLog{
		ID:            uuid.New(),
		UserID:        userID,
		OperationType: "push",
		ItemType:      "note",
		ItemID:        uuid.New(),
		Version:       5,
		CreatedAt:     now,
	}
	err := repo.InsertOperationLog(ctx, pushLog)
	if err != nil {
		t.Fatalf("InsertOperationLog (push): %v", err)
	}

	// Insert a pull operation log.
	pullLog := &domain.SyncOperationLog{
		ID:            uuid.New(),
		UserID:        userID,
		OperationType: "pull",
		ItemType:      "tag",
		ItemID:        uuid.New(),
		Version:       3,
		CreatedAt:     now,
	}
	err = repo.InsertOperationLog(ctx, pullLog)
	if err != nil {
		t.Fatalf("InsertOperationLog (pull): %v", err)
	}

	// Insert a conflict log (version=0 sentinel).
	conflictLog := &domain.SyncOperationLog{
		ID:            uuid.New(),
		UserID:        userID,
		OperationType: "push",
		ItemType:      "note",
		ItemID:        uuid.New(),
		Version:       0, // conflict sentinel
		CreatedAt:     now,
	}
	err = repo.InsertOperationLog(ctx, conflictLog)
	if err != nil {
		t.Fatalf("InsertOperationLog (conflict): %v", err)
	}

	// Verify conflict count.
	conflictCount, err := repo.GetConflictCount(ctx, userID)
	if err != nil {
		t.Fatalf("GetConflictCount: %v", err)
	}
	if conflictCount != 1 {
		t.Errorf("conflictCount = %d, want 1", conflictCount)
	}

	// Verify operation counts (push with version > 0, pull).
	pushCount, pullCount, err := repo.GetOperationCounts(ctx, userID)
	if err != nil {
		t.Fatalf("GetOperationCounts: %v", err)
	}
	if pushCount != 1 {
		t.Errorf("pushCount = %d, want 1", pushCount)
	}
	if pullCount != 1 {
		t.Errorf("pullCount = %d, want 1", pullCount)
	}
}
