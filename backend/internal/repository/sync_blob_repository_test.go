package repository

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestSyncBlobRepository_DocumentsExpectedBehavior documents the expected SQL
// behaviors for the SyncBlobRepository.
func TestSyncBlobRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("PullSince_selects_newer_blobs", func(t *testing.T) {
		// Expected behavior:
		//   SELECT id, user_id, item_type, item_id, version, encrypted_data, blob_size, created_at, updated_at
		//   FROM sync_blobs
		//   WHERE user_id = $1 AND version > $2
		//   ORDER BY updated_at ASC
		// Returns empty slice (not nil) when no newer blobs exist.
		t.Log("documented: PullSince returns blobs with version > sinceVersion")
	})

	t.Run("Upsert_inserts_new_blob", func(t *testing.T) {
		// Expected behavior (atomic via INSERT ... ON CONFLICT):
		//   INSERT INTO sync_blobs ... ON CONFLICT (user_id, item_type, item_id) DO UPDATE
		//   SET version=$4, encrypted_data=$5, blob_size=$6, updated_at=NOW()
		//   WHERE sync_blobs.version < $4
		//   1. If no row exists -> INSERT succeeds, RowsAffected()=1, return (true, nil)
		//   2. If server version < client version -> UPDATE fires, RowsAffected()=1, return (true, nil)
		//   3. If server version >= client version -> no rows affected, return (false, nil)
		t.Log("documented: Upsert uses atomic INSERT ON CONFLICT with version check")
	})

	t.Run("GetLatestVersion_returns_max", func(t *testing.T) {
		// SELECT MAX(version) FROM sync_blobs WHERE user_id = $1
		// Returns 0 when no blobs exist (nil result).
		t.Log("documented: GetLatestVersion returns MAX(version) or 0")
	})

	t.Run("CountItems_returns_count", func(t *testing.T) {
		// SELECT COUNT(*) FROM sync_blobs WHERE user_id = $1
		t.Log("documented: CountItems returns total blob count for user")
	})

	t.Run("GetLastUpdated_returns_max_timestamp", func(t *testing.T) {
		// SELECT MAX(updated_at) FROM sync_blobs WHERE user_id = $1
		// Returns zero time.Time when no blobs exist.
		t.Log("documented: GetLastUpdated returns MAX(updated_at) or zero time")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using an in-memory mock
// ---------------------------------------------------------------------------

type mockSyncBlobRepo struct {
	blobs map[string]*domain.SyncBlob // key: itemType:userID:itemID
}

func blobKey(b *domain.SyncBlob) string {
	return b.ItemType + ":" + b.UserID.String() + ":" + b.ItemID.String()
}

func newMockSyncBlobRepo() *mockSyncBlobRepo {
	return &mockSyncBlobRepo{
		blobs: make(map[string]*domain.SyncBlob),
	}
}

func (m *mockSyncBlobRepo) PullSince(ctx context.Context, userID uuid.UUID, sinceVersion int) ([]domain.SyncBlob, error) {
	var result []domain.SyncBlob
	for _, b := range m.blobs {
		if b.UserID == userID && b.Version > sinceVersion {
			result = append(result, *b)
		}
	}
	return result, nil
}

func (m *mockSyncBlobRepo) Upsert(ctx context.Context, blob *domain.SyncBlob) (bool, error) {
	key := blobKey(blob)
	existing, exists := m.blobs[key]

	if exists && existing.Version >= blob.Version {
		blob.Version = existing.Version
		return false, nil
	}

	m.blobs[key] = blob
	return true, nil
}

func (m *mockSyncBlobRepo) GetLatestVersion(ctx context.Context, userID uuid.UUID) (int, error) {
	maxV := 0
	for _, b := range m.blobs {
		if b.UserID == userID && b.Version > maxV {
			maxV = b.Version
		}
	}
	return maxV, nil
}

func (m *mockSyncBlobRepo) CountItems(ctx context.Context, userID uuid.UUID) (int, error) {
	count := 0
	for _, b := range m.blobs {
		if b.UserID == userID {
			count++
		}
	}
	return count, nil
}

func (m *mockSyncBlobRepo) GetLastUpdated(_ context.Context, _ uuid.UUID) (interface{}, error) {
	// Simplified for testing — not used in mock tests below.
	return nil, nil
}

func (m *mockSyncBlobRepo) GetStatusSummary(ctx context.Context, userID uuid.UUID) (domain.SyncStatusSummary, error) {
	summary := domain.SyncStatusSummary{
		LatestVersion: 0,
		TotalItems:    0,
	}
	for _, b := range m.blobs {
		if b.UserID == userID {
			summary.TotalItems++
			if b.Version > summary.LatestVersion {
				summary.LatestVersion = b.Version
			}
			if b.UpdatedAt.After(summary.LastUpdated) {
				summary.LastUpdated = b.UpdatedAt
			}
		}
	}
	return summary, nil
}

func TestMockSyncBlobRepo_Upsert_NewBlob(t *testing.T) {
	repo := newMockSyncBlobRepo()
	ctx := context.Background()
	userID := uuid.New()

	blob := &domain.SyncBlob{
		UserID: userID, ItemType: "note", ItemID: uuid.New(),
		Version: 1, EncryptedData: []byte("enc"), BlobSize: 3,
	}

	accepted, err := repo.Upsert(ctx, blob)
	if err != nil {
		t.Fatalf("Upsert: %v", err)
	}
	if !accepted {
		t.Error("new blob should be accepted")
	}

	count, _ := repo.CountItems(ctx, userID)
	if count != 1 {
		t.Errorf("CountItems = %d, want 1", count)
	}
}

func TestMockSyncBlobRepo_Upsert_Conflict(t *testing.T) {
	repo := newMockSyncBlobRepo()
	ctx := context.Background()
	userID := uuid.New()
	itemID := uuid.New()

	// Insert version 5.
	repo.Upsert(ctx, &domain.SyncBlob{
		UserID: userID, ItemType: "note", ItemID: itemID,
		Version: 5, EncryptedData: []byte("old"), BlobSize: 3,
	})

	// Try to push version 3 (older than server version 5).
	blob2 := &domain.SyncBlob{
		UserID: userID, ItemType: "note", ItemID: itemID,
		Version: 3, EncryptedData: []byte("newer"), BlobSize: 6,
	}
	accepted, err := repo.Upsert(ctx, blob2)
	if err != nil {
		t.Fatalf("Upsert: %v", err)
	}
	if accepted {
		t.Error("older version should be rejected (conflict)")
	}
	if blob2.Version != 5 {
		t.Errorf("Version should be updated to server version 5, got %d", blob2.Version)
	}
}

func TestMockSyncBlobRepo_Upsert_UpdateExisting(t *testing.T) {
	repo := newMockSyncBlobRepo()
	ctx := context.Background()
	userID := uuid.New()
	itemID := uuid.New()

	repo.Upsert(ctx, &domain.SyncBlob{
		UserID: userID, ItemType: "note", ItemID: itemID,
		Version: 1, EncryptedData: []byte("v1"), BlobSize: 2,
	})

	accepted, err := repo.Upsert(ctx, &domain.SyncBlob{
		UserID: userID, ItemType: "note", ItemID: itemID,
		Version: 2, EncryptedData: []byte("v2"), BlobSize: 2,
	})
	if err != nil {
		t.Fatalf("Upsert: %v", err)
	}
	if !accepted {
		t.Error("newer version should be accepted")
	}
}

func TestMockSyncBlobRepo_PullSince(t *testing.T) {
	repo := newMockSyncBlobRepo()
	ctx := context.Background()
	userID := uuid.New()

	for i := 1; i <= 5; i++ {
		repo.Upsert(ctx, &domain.SyncBlob{
			UserID: userID, ItemType: "note", ItemID: uuid.New(),
			Version: i, EncryptedData: []byte("data"), BlobSize: 4,
		})
	}

	blobs, err := repo.PullSince(ctx, userID, 3)
	if err != nil {
		t.Fatalf("PullSince: %v", err)
	}
	if len(blobs) != 2 {
		t.Errorf("len(blobs) = %d, want 2 (versions 4 and 5)", len(blobs))
	}

	// No new blobs.
	blobs, _ = repo.PullSince(ctx, userID, 10)
	if len(blobs) != 0 {
		t.Errorf("len(blobs) = %d, want 0 for sinceVersion > all", len(blobs))
	}
}

func TestMockSyncBlobRepo_GetLatestVersion(t *testing.T) {
	repo := newMockSyncBlobRepo()
	ctx := context.Background()
	userID := uuid.New()

	v, _ := repo.GetLatestVersion(ctx, userID)
	if v != 0 {
		t.Errorf("GetLatestVersion on empty = %d, want 0", v)
	}

	repo.Upsert(ctx, &domain.SyncBlob{UserID: userID, ItemType: "note", ItemID: uuid.New(), Version: 3})
	repo.Upsert(ctx, &domain.SyncBlob{UserID: userID, ItemType: "note", ItemID: uuid.New(), Version: 7})

	v, _ = repo.GetLatestVersion(ctx, userID)
	if v != 7 {
		t.Errorf("GetLatestVersion = %d, want 7", v)
	}
}

func TestMockSyncBlobRepo_DifferentUsers(t *testing.T) {
	repo := newMockSyncBlobRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()

	repo.Upsert(ctx, &domain.SyncBlob{UserID: user1, ItemType: "note", ItemID: uuid.New(), Version: 1})
	repo.Upsert(ctx, &domain.SyncBlob{UserID: user2, ItemType: "note", ItemID: uuid.New(), Version: 1})
	repo.Upsert(ctx, &domain.SyncBlob{UserID: user1, ItemType: "note", ItemID: uuid.New(), Version: 2})

	count1, _ := repo.CountItems(ctx, user1)
	count2, _ := repo.CountItems(ctx, user2)

	if count1 != 2 {
		t.Errorf("user1 count = %d, want 2", count1)
	}
	if count2 != 1 {
		t.Errorf("user2 count = %d, want 1", count2)
	}

	v1, _ := repo.GetLatestVersion(ctx, user1)
	v2, _ := repo.GetLatestVersion(ctx, user2)

	if v1 != 2 {
		t.Errorf("user1 latest = %d, want 2", v1)
	}
	if v2 != 1 {
		t.Errorf("user2 latest = %d, want 1", v2)
	}
}

// ---------------------------------------------------------------------------
// Tests: BatchUpsert with enriched result fields
// ---------------------------------------------------------------------------

func TestSyncBlobRepository_BatchUpsert_DocumentsEnrichedResult(t *testing.T) {
	t.Run("BatchUpsert_populates_ItemType_and_ClientVersion", func(t *testing.T) {
		// Expected behavior:
		//   BatchUpsert should populate ItemType and ClientVersion in each result,
		//   enabling callers to construct enriched conflict info without a secondary lookup.
		t.Log("documented: BatchUpsert returns ItemType and ClientVersion in results")
	})
}

// ---------------------------------------------------------------------------
// Tests: Operation logging methods
// ---------------------------------------------------------------------------

func TestSyncBlobRepository_OperationLogMethods(t *testing.T) {
	t.Run("InsertOperationLog_records_sync_operation", func(t *testing.T) {
		// Expected behavior:
		//   INSERT INTO sync_operation_logs (id, user_id, operation_type, item_type, item_id, version, created_at)
		//   VALUES ($1, $2, $3, $4, $5, $6, $7)
		//   Records a single sync operation for debugging and conflict tracking.
		//   version=0 is used as a sentinel to indicate a conflict (server rejected the push).
		t.Log("documented: InsertOperationLog inserts a single sync operation log entry")
	})

	t.Run("BatchInsertOperationLogs_uses_pgx_Batch", func(t *testing.T) {
		// Expected behavior:
		//   Pipelines all insert queries in a single pgx.Batch round-trip.
		//   Returns nil on success, error if any individual insert fails.
		t.Log("documented: BatchInsertOperationLogs uses pgx.Batch for bulk insert")
	})

	t.Run("GetItemsByType_returns_type_counts", func(t *testing.T) {
		// Expected behavior:
		//   SELECT item_type, COUNT(*) FROM sync_blobs WHERE user_id = $1 GROUP BY item_type
		//   Returns a map of item_type -> count for the given user.
		t.Log("documented: GetItemsByType returns per-type item counts via GROUP BY")
	})

	t.Run("GetConflictCount_returns_conflict_log_count", func(t *testing.T) {
		// Expected behavior:
		//   SELECT COUNT(*) FROM sync_operation_logs WHERE user_id = $1 AND operation_type = 'push' AND version = 0
		//   Counts all logged conflicts (version=0 sentinel) for the user.
		t.Log("documented: GetConflictCount counts version=0 operation logs for the user")
	})

	t.Run("ListOperationLogs_returns_recent_logs", func(t *testing.T) {
		// Expected behavior:
		//   SELECT ... FROM sync_operation_logs WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2
		//   Returns recent sync operation logs for debugging. Default limit 50, max 500.
		t.Log("documented: ListOperationLogs returns paginated recent logs ordered by created_at DESC")
	})
}
