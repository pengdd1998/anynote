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
		// Expected behavior:
		//   1. SELECT version FROM sync_blobs WHERE user_id=$1 AND item_type=$2 AND item_id=$3
		//   2. If no row exists -> INSERT new blob, return (true, nil)
		//   3. If server version >= client version -> conflict, return (false, nil)
		//   4. If server version < client version -> UPDATE, return (true, nil)
		t.Log("documented: Upsert inserts new or updates if client version > server version")
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
