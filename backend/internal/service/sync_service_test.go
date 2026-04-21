package service

import (
	"context"
	"errors"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock SyncBlobRepository
// ---------------------------------------------------------------------------

type mockSyncBlobRepo struct {
	blobs             []domain.SyncBlob
	latestVersion     int
	totalItems        int
	lastUpdated       time.Time
	pullErr           error
	upsertErr         error
	upsertResult      bool // accepted or conflict
	versionErr        error
	countErr          error
	lastUpdatedErr    error
	statusSummaryErr  error
	listTagsByTypeErr error
	batchDeleteErr    error
	opCountsErr       error
	opCountsPush      int64
	opCountsPull      int64
	conflictCountVal  int64
	conflictCountErr  error
}

func (m *mockSyncBlobRepo) PullSince(ctx context.Context, userID uuid.UUID, sinceVersion int) ([]domain.SyncBlob, error) {
	if m.pullErr != nil {
		return nil, m.pullErr
	}
	// Return blobs that are newer than sinceVersion.
	var result []domain.SyncBlob
	for _, b := range m.blobs {
		if b.Version > sinceVersion {
			result = append(result, b)
		}
	}
	return result, nil
}

func (m *mockSyncBlobRepo) PullSincePaginated(ctx context.Context, userID uuid.UUID, sinceVersion int, limit int) ([]domain.SyncBlob, error) {
	if m.pullErr != nil {
		return nil, m.pullErr
	}
	// Return blobs that are newer than sinceVersion, up to limit.
	var result []domain.SyncBlob
	for _, b := range m.blobs {
		if b.Version > sinceVersion {
			result = append(result, b)
			if len(result) >= limit {
				break
			}
		}
	}
	return result, nil
}

func (m *mockSyncBlobRepo) HasMoreSince(ctx context.Context, userID uuid.UUID, sinceVersion int) (bool, error) {
	for _, b := range m.blobs {
		if b.Version > sinceVersion {
			return true, nil
		}
	}
	return false, nil
}

func (m *mockSyncBlobRepo) Upsert(ctx context.Context, blob *domain.SyncBlob) (bool, error) {
	if m.upsertErr != nil {
		return false, m.upsertErr
	}
	return m.upsertResult, nil
}

func (m *mockSyncBlobRepo) BatchUpsert(ctx context.Context, blobs []*domain.SyncBlob) []domain.BatchUpsertResult {
	results := make([]domain.BatchUpsertResult, len(blobs))
	for i, blob := range blobs {
		results[i].ItemID = blob.ItemID
		results[i].ItemType = blob.ItemType
		results[i].ClientVersion = blob.Version
		if m.upsertErr != nil {
			results[i].Error = m.upsertErr
			continue
		}
		if m.upsertResult {
			results[i].Accepted = true
		} else {
			results[i].ServerVersion = blob.Version
		}
	}
	return results
}

func (m *mockSyncBlobRepo) GetLatestVersion(ctx context.Context, userID uuid.UUID) (int, error) {
	if m.versionErr != nil {
		return 0, m.versionErr
	}
	return m.latestVersion, nil
}

func (m *mockSyncBlobRepo) CountItems(ctx context.Context, userID uuid.UUID) (int, error) {
	if m.countErr != nil {
		return 0, m.countErr
	}
	return m.totalItems, nil
}

func (m *mockSyncBlobRepo) GetLastUpdated(ctx context.Context, userID uuid.UUID) (time.Time, error) {
	if m.lastUpdatedErr != nil {
		return time.Time{}, m.lastUpdatedErr
	}
	return m.lastUpdated, nil
}

func (m *mockSyncBlobRepo) GetStatusSummary(ctx context.Context, userID uuid.UUID) (domain.SyncStatusSummary, error) {
	if m.statusSummaryErr != nil {
		return domain.SyncStatusSummary{}, m.statusSummaryErr
	}
	return domain.SyncStatusSummary{
		LatestVersion: m.latestVersion,
		TotalItems:    m.totalItems,
		LastUpdated:   m.lastUpdated,
	}, nil
}

func (m *mockSyncBlobRepo) GetItemsByType(ctx context.Context, userID uuid.UUID) (map[string]int, error) {
	result := make(map[string]int)
	for _, b := range m.blobs {
		result[b.ItemType]++
	}
	return result, nil
}

func (m *mockSyncBlobRepo) GetConflictCount(ctx context.Context, userID uuid.UUID) (int64, error) {
	if m.conflictCountErr != nil {
		return 0, m.conflictCountErr
	}
	return m.conflictCountVal, nil
}

func (m *mockSyncBlobRepo) InsertOperationLog(ctx context.Context, log *domain.SyncOperationLog) error {
	return nil
}

func (m *mockSyncBlobRepo) BatchInsertOperationLogs(ctx context.Context, logs []domain.SyncOperationLog) error {
	return nil
}

func (m *mockSyncBlobRepo) ListTagsByType(ctx context.Context, userID uuid.UUID, itemType string) ([]domain.TagListItem, error) {
	if m.listTagsByTypeErr != nil {
		return nil, m.listTagsByTypeErr
	}
	var tags []domain.TagListItem
	for _, b := range m.blobs {
		if b.ItemType == itemType {
			tags = append(tags, domain.TagListItem{
				ItemID:    b.ItemID,
				Version:   b.Version,
				BlobSize:  b.BlobSize,
				UpdatedAt: b.UpdatedAt,
			})
		}
	}
	return tags, nil
}

func (m *mockSyncBlobRepo) BatchDelete(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (int, error) {
	if m.batchDeleteErr != nil {
		return 0, m.batchDeleteErr
	}
	deleted := 0
	for _, id := range itemIDs {
		for i, b := range m.blobs {
			if b.ItemID == id {
				m.blobs = append(m.blobs[:i], m.blobs[i+1:]...)
				deleted++
				break
			}
		}
	}
	return deleted, nil
}

func (m *mockSyncBlobRepo) GetOperationCounts(ctx context.Context, userID uuid.UUID) (int64, int64, error) {
	if m.opCountsErr != nil {
		return 0, 0, m.opCountsErr
	}
	return m.opCountsPush, m.opCountsPull, nil
}

// ---------------------------------------------------------------------------
// Tests: Pull
// ---------------------------------------------------------------------------

func TestSyncService_Pull_Success(t *testing.T) {
	userID := uuid.New()
	now := time.Now()

	repo := &mockSyncBlobRepo{
		blobs: []domain.SyncBlob{
			{ID: uuid.New(), UserID: userID, Version: 3, UpdatedAt: now},
			{ID: uuid.New(), UserID: userID, Version: 4, UpdatedAt: now},
			{ID: uuid.New(), UserID: userID, Version: 5, UpdatedAt: now},
		},
		latestVersion: 5,
	}

	svc := NewSyncService(repo)
	resp, err := svc.Pull(context.Background(), userID, 2, 100, 0)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	if len(resp.Blobs) != 3 {
		t.Errorf("len(Blobs) = %d, want 3", len(resp.Blobs))
	}
	if resp.LatestVersion != 5 {
		t.Errorf("LatestVersion = %d, want 5", resp.LatestVersion)
	}
}

func TestSyncService_Pull_NoNewBlobs(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		blobs:         []domain.SyncBlob{},
		latestVersion: 10,
	}

	svc := NewSyncService(repo)
	resp, err := svc.Pull(context.Background(), userID, 10, 100, 0)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	if len(resp.Blobs) != 0 {
		t.Errorf("len(Blobs) = %d, want 0", len(resp.Blobs))
	}
	if resp.LatestVersion != 10 {
		t.Errorf("LatestVersion = %d, want 10", resp.LatestVersion)
	}
	if resp.HasMore {
		t.Error("HasMore = true, want false when no blobs returned")
	}
}

func TestSyncService_Pull_RepoError(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		pullErr: errors.New("database unavailable"),
	}

	svc := NewSyncService(repo)
	_, err := svc.Pull(context.Background(), userID, 0, 100, 0)
	if err == nil {
		t.Error("expected error when repo.PullSince fails")
	}
}

func TestSyncService_Pull_PaginationWithLimit(t *testing.T) {
	userID := uuid.New()
	now := time.Now()

	repo := &mockSyncBlobRepo{
		blobs: []domain.SyncBlob{
			{ID: uuid.New(), UserID: userID, Version: 3, UpdatedAt: now},
			{ID: uuid.New(), UserID: userID, Version: 4, UpdatedAt: now},
			{ID: uuid.New(), UserID: userID, Version: 5, UpdatedAt: now},
		},
		latestVersion: 5,
	}

	svc := NewSyncService(repo)

	// Request first page with limit 2.
	resp, err := svc.Pull(context.Background(), userID, 0, 2, 0)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	if len(resp.Blobs) != 2 {
		t.Errorf("len(Blobs) = %d, want 2", len(resp.Blobs))
	}
	if !resp.HasMore {
		t.Error("HasMore = false, want true when there are more pages")
	}
	if resp.NextCursor != 4 {
		t.Errorf("NextCursor = %d, want 4 (last version in page)", resp.NextCursor)
	}

	// Request second page using cursor from first page.
	resp2, err := svc.Pull(context.Background(), userID, 0, 2, resp.NextCursor)
	if err != nil {
		t.Fatalf("Pull page 2: %v", err)
	}
	if len(resp2.Blobs) != 1 {
		t.Errorf("len(Blobs) page 2 = %d, want 1", len(resp2.Blobs))
	}
	if resp2.HasMore {
		t.Error("HasMore page 2 = true, want false (no more pages)")
	}
}

func TestSyncService_Pull_UsesCursorOverSince(t *testing.T) {
	userID := uuid.New()
	now := time.Now()

	repo := &mockSyncBlobRepo{
		blobs: []domain.SyncBlob{
			{ID: uuid.New(), UserID: userID, Version: 5, UpdatedAt: now},
			{ID: uuid.New(), UserID: userID, Version: 10, UpdatedAt: now},
		},
		latestVersion: 10,
	}

	svc := NewSyncService(repo)

	// Cursor=5 should override since=0: only versions > 5 returned.
	resp, err := svc.Pull(context.Background(), userID, 0, 100, 5)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	if len(resp.Blobs) != 1 {
		t.Errorf("len(Blobs) = %d, want 1 (only version 10)", len(resp.Blobs))
	}
	if resp.Blobs[0].Version != 10 {
		t.Errorf("Blob version = %d, want 10", resp.Blobs[0].Version)
	}
}

// ---------------------------------------------------------------------------
// Tests: Push
// ---------------------------------------------------------------------------

func TestSyncService_Push_AllAccepted(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		upsertResult: true, // all items accepted
	}

	svc := NewSyncService(repo)
	resp, err := svc.Push(context.Background(), userID, domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: uuid.New(), ItemType: "note", Version: 1, EncryptedData: []byte("enc1"), BlobSize: 100},
			{ItemID: uuid.New(), ItemType: "tag", Version: 1, EncryptedData: []byte("enc2"), BlobSize: 50},
		},
	})
	if err != nil {
		t.Fatalf("Push: %v", err)
	}
	if len(resp.Accepted) != 2 {
		t.Errorf("len(Accepted) = %d, want 2", len(resp.Accepted))
	}
	if len(resp.Conflicts) != 0 {
		t.Errorf("len(Conflicts) = %d, want 0", len(resp.Conflicts))
	}
}

func TestSyncService_Push_AllConflicts(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		upsertResult: false, // all items conflict (server has newer version)
	}

	svc := NewSyncService(repo)
	resp, err := svc.Push(context.Background(), userID, domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: uuid.New(), ItemType: "note", Version: 1, EncryptedData: []byte("enc1"), BlobSize: 100},
		},
	})
	if err != nil {
		t.Fatalf("Push: %v", err)
	}
	if len(resp.Accepted) != 0 {
		t.Errorf("len(Accepted) = %d, want 0", len(resp.Accepted))
	}
	if len(resp.Conflicts) != 1 {
		t.Errorf("len(Conflicts) = %d, want 1", len(resp.Conflicts))
	}
}

func TestSyncService_Push_MixedResults(t *testing.T) {
	userID := uuid.New()
	itemID1 := uuid.New()
	itemID2 := uuid.New()

	// Use a custom repo that accepts the first item and conflicts on the second.
	callCount := 0
	repo := &customUpsertRepo{
		batchUpsertFn: func(blobs []*domain.SyncBlob) []domain.BatchUpsertResult {
			results := make([]domain.BatchUpsertResult, len(blobs))
			for i, blob := range blobs {
				results[i].ItemID = blob.ItemID
				callCount++
				if callCount == 1 {
					results[i].Accepted = true
				} else {
					results[i].ServerVersion = blob.Version
				}
			}
			return results
		},
	}

	svc := NewSyncService(repo)
	resp, err := svc.Push(context.Background(), userID, domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: itemID1, ItemType: "note", Version: 2, EncryptedData: []byte("enc1"), BlobSize: 100},
			{ItemID: itemID2, ItemType: "tag", Version: 1, EncryptedData: []byte("enc2"), BlobSize: 50},
		},
	})
	if err != nil {
		t.Fatalf("Push: %v", err)
	}
	if len(resp.Accepted) != 1 {
		t.Errorf("len(Accepted) = %d, want 1", len(resp.Accepted))
	}
	if resp.Accepted[0] != itemID1 {
		t.Errorf("Accepted[0] = %v, want %v", resp.Accepted[0], itemID1)
	}
	if len(resp.Conflicts) != 1 {
		t.Errorf("len(Conflicts) = %d, want 1", len(resp.Conflicts))
	}
	if resp.Conflicts[0].ItemID != itemID2 {
		t.Errorf("Conflicts[0].ItemID = %v, want %v", resp.Conflicts[0].ItemID, itemID2)
	}
}

func TestSyncService_Push_UpsertErrorSkipsItem(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		upsertErr: errors.New("write error"),
	}

	svc := NewSyncService(repo)
	resp, err := svc.Push(context.Background(), userID, domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: uuid.New(), ItemType: "note", Version: 1, EncryptedData: []byte("enc1"), BlobSize: 100},
		},
	})
	if err != nil {
		t.Fatalf("Push should not return error for individual item failures: %v", err)
	}
	// The errored item should be skipped (neither accepted nor conflict).
	if len(resp.Accepted) != 0 {
		t.Errorf("len(Accepted) = %d, want 0", len(resp.Accepted))
	}
	if len(resp.Conflicts) != 0 {
		t.Errorf("len(Conflicts) = %d, want 0", len(resp.Conflicts))
	}
}

func TestSyncService_Push_EmptyRequest(t *testing.T) {
	userID := uuid.New()
	repo := &mockSyncBlobRepo{}
	svc := NewSyncService(repo)

	resp, err := svc.Push(context.Background(), userID, domain.SyncPushRequest{})
	if err != nil {
		t.Fatalf("Push: %v", err)
	}
	if len(resp.Accepted) != 0 {
		t.Errorf("len(Accepted) = %d, want 0", len(resp.Accepted))
	}
	if len(resp.Conflicts) != 0 {
		t.Errorf("len(Conflicts) = %d, want 0", len(resp.Conflicts))
	}
}

// ---------------------------------------------------------------------------
// Tests: GetStatus
// ---------------------------------------------------------------------------

func TestSyncService_GetStatus_Success(t *testing.T) {
	userID := uuid.New()
	now := time.Now()

	repo := &mockSyncBlobRepo{
		latestVersion: 42,
		totalItems:    150,
		lastUpdated:   now,
	}

	svc := NewSyncService(repo)
	status, err := svc.GetStatus(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetStatus: %v", err)
	}
	if status.LatestVersion != 42 {
		t.Errorf("LatestVersion = %d, want 42", status.LatestVersion)
	}
	if status.TotalItems != 150 {
		t.Errorf("TotalItems = %d, want 150", status.TotalItems)
	}
	if !status.LastSyncedAt.Equal(now) {
		t.Errorf("LastSyncedAt = %v, want %v", status.LastSyncedAt, now)
	}
}

func TestSyncService_GetStatus_RepoErrors(t *testing.T) {
	userID := uuid.New()

	// GetStatus propagates summary query errors.
	repo := &mockSyncBlobRepo{
		statusSummaryErr: errors.New("summary query failed"),
	}

	svc := NewSyncService(repo)
	_, err := svc.GetStatus(context.Background(), userID)
	if err == nil {
		t.Fatal("GetStatus should return error when repo fails")
	}
	if !strings.Contains(err.Error(), "summary query failed") {
		t.Errorf("error should wrap repo error, got: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Custom mock for mixed upsert results
// ---------------------------------------------------------------------------

type customUpsertRepo struct {
	blobs          []domain.SyncBlob
	latestVersion  int
	totalItems     int
	lastUpdated    time.Time
	batchUpsertFn  func(blobs []*domain.SyncBlob) []domain.BatchUpsertResult
}

func (m *customUpsertRepo) PullSince(ctx context.Context, userID uuid.UUID, sinceVersion int) ([]domain.SyncBlob, error) {
	return m.blobs, nil
}

func (m *customUpsertRepo) PullSincePaginated(ctx context.Context, userID uuid.UUID, sinceVersion int, limit int) ([]domain.SyncBlob, error) {
	return m.blobs, nil
}

func (m *customUpsertRepo) HasMoreSince(ctx context.Context, userID uuid.UUID, sinceVersion int) (bool, error) {
	return false, nil
}

func (m *customUpsertRepo) Upsert(ctx context.Context, blob *domain.SyncBlob) (bool, error) {
	return false, nil
}

func (m *customUpsertRepo) BatchUpsert(ctx context.Context, blobs []*domain.SyncBlob) []domain.BatchUpsertResult {
	if m.batchUpsertFn != nil {
		return m.batchUpsertFn(blobs)
	}
	return make([]domain.BatchUpsertResult, len(blobs))
}

func (m *customUpsertRepo) GetLatestVersion(ctx context.Context, userID uuid.UUID) (int, error) {
	return m.latestVersion, nil
}

func (m *customUpsertRepo) CountItems(ctx context.Context, userID uuid.UUID) (int, error) {
	return m.totalItems, nil
}

func (m *customUpsertRepo) GetLastUpdated(ctx context.Context, userID uuid.UUID) (time.Time, error) {
	return m.lastUpdated, nil
}

func (m *customUpsertRepo) GetStatusSummary(ctx context.Context, userID uuid.UUID) (domain.SyncStatusSummary, error) {
	return domain.SyncStatusSummary{
		LatestVersion: m.latestVersion,
		TotalItems:    m.totalItems,
		LastUpdated:   m.lastUpdated,
	}, nil
}

func (m *customUpsertRepo) GetItemsByType(ctx context.Context, userID uuid.UUID) (map[string]int, error) {
	result := make(map[string]int)
	for _, b := range m.blobs {
		result[b.ItemType]++
	}
	return result, nil
}

func (m *customUpsertRepo) GetConflictCount(ctx context.Context, userID uuid.UUID) (int64, error) {
	return 0, nil
}

func (m *customUpsertRepo) InsertOperationLog(ctx context.Context, log *domain.SyncOperationLog) error {
	return nil
}

func (m *customUpsertRepo) BatchInsertOperationLogs(ctx context.Context, logs []domain.SyncOperationLog) error {
	return nil
}

func (m *customUpsertRepo) ListTagsByType(ctx context.Context, userID uuid.UUID, itemType string) ([]domain.TagListItem, error) {
	var tags []domain.TagListItem
	for _, b := range m.blobs {
		if b.ItemType == itemType {
			tags = append(tags, domain.TagListItem{
				ItemID:    b.ItemID,
				Version:   b.Version,
				BlobSize:  b.BlobSize,
				UpdatedAt: b.UpdatedAt,
			})
		}
	}
	return tags, nil
}

func (m *customUpsertRepo) BatchDelete(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (int, error) {
	return len(itemIDs), nil
}

func (m *customUpsertRepo) GetOperationCounts(ctx context.Context, userID uuid.UUID) (int64, int64, error) {
	return 5, 3, nil
}

// ---------------------------------------------------------------------------
// Tests: GetStats
// ---------------------------------------------------------------------------

func TestSyncService_GetStats_Success(t *testing.T) {
	userID := uuid.New()
	now := time.Now()

	repo := &mockSyncBlobRepo{
		blobs: []domain.SyncBlob{
			{UserID: userID, ItemType: "note", Version: 3},
			{UserID: userID, ItemType: "note", Version: 5},
			{UserID: userID, ItemType: "tag", Version: 4},
		},
		latestVersion: 5,
		totalItems:    3,
		lastUpdated:   now,
	}

	svc := NewSyncService(repo)
	stats, err := svc.GetStats(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetStats: %v", err)
	}

	if stats.TotalItems != 3 {
		t.Errorf("TotalItems = %d, want 3", stats.TotalItems)
	}
	if stats.ItemsByType["note"] != 2 {
		t.Errorf("ItemsByType[note] = %d, want 2", stats.ItemsByType["note"])
	}
	if stats.ItemsByType["tag"] != 1 {
		t.Errorf("ItemsByType[tag] = %d, want 1", stats.ItemsByType["tag"])
	}
	if !stats.LastSyncedAt.Equal(now) {
		t.Errorf("LastSyncedAt = %v, want %v", stats.LastSyncedAt, now)
	}
}

func TestSyncService_GetStats_StatusSummaryError(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		statusSummaryErr: errors.New("db unavailable"),
	}

	svc := NewSyncService(repo)
	_, err := svc.GetStats(context.Background(), userID)
	if err == nil {
		t.Error("GetStats should return error when GetStatusSummary fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: Push with enriched conflict info
// ---------------------------------------------------------------------------

func TestSyncService_Push_ConflictIncludesTypeAndVersion(t *testing.T) {
	userID := uuid.New()
	itemID := uuid.New()

	// Custom repo that rejects all items (conflict).
	repo := &customUpsertRepo{
		batchUpsertFn: func(blobs []*domain.SyncBlob) []domain.BatchUpsertResult {
			results := make([]domain.BatchUpsertResult, len(blobs))
			for i, blob := range blobs {
				results[i].ItemID = blob.ItemID
				results[i].ItemType = blob.ItemType
				results[i].ClientVersion = blob.Version
				results[i].ServerVersion = blob.Version + 5 // server has newer version
			}
			return results
		},
	}

	svc := NewSyncService(repo)
	resp, err := svc.Push(context.Background(), userID, domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: itemID, ItemType: "note", Version: 3, EncryptedData: []byte("enc"), BlobSize: 3},
		},
	})
	if err != nil {
		t.Fatalf("Push: %v", err)
	}

	if len(resp.Conflicts) != 1 {
		t.Fatalf("len(Conflicts) = %d, want 1", len(resp.Conflicts))
	}

	c := resp.Conflicts[0]
	if c.ItemID != itemID {
		t.Errorf("Conflict.ItemID = %v, want %v", c.ItemID, itemID)
	}
	if c.ItemType != "note" {
		t.Errorf("Conflict.ItemType = %q, want %q", c.ItemType, "note")
	}
	if c.ServerVersion != 8 {
		t.Errorf("Conflict.ServerVersion = %d, want 8", c.ServerVersion)
	}
	if c.ClientVersion != 3 {
		t.Errorf("Conflict.ClientVersion = %d, want 3", c.ClientVersion)
	}
}

// ---------------------------------------------------------------------------
// Tests: WithPushService option
// ---------------------------------------------------------------------------

func TestWithPushService(t *testing.T) {
	repo := &mockSyncBlobRepo{}
	pushSvc := &mockPushServiceForSync{}
	opt := WithPushService(pushSvc)

	svc := NewSyncService(repo)
	opt(svc.(*syncService))

	if svc.(*syncService).pushSvc == nil {
		t.Error("pushSvc should be set after WithPushService")
	}
}

func TestSyncService_Push_ConflictsTriggerPushNotification(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		upsertResult: false, // all items conflict
	}

	var pushCalled atomic.Bool
	pushSvc := &mockPushServiceForSync{
		sendPushFn: func(ctx context.Context, userIDStr string, payload PushPayload) error {
			pushCalled.Store(true)
			if userIDStr != userID.String() {
				t.Errorf("sendPush userID = %q, want %q", userIDStr, userID.String())
			}
			if payload.Title != "Sync Conflict Detected" {
				t.Errorf("payload.Title = %q, want %q", payload.Title, "Sync Conflict Detected")
			}
			return nil
		},
	}

	svc := NewSyncService(repo, WithPushService(pushSvc))
	resp, err := svc.Push(context.Background(), userID, domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: uuid.New(), ItemType: "note", Version: 1, EncryptedData: []byte("enc1"), BlobSize: 100},
		},
	})
	if err != nil {
		t.Fatalf("Push: %v", err)
	}
	if len(resp.Conflicts) != 1 {
		t.Fatalf("len(Conflicts) = %d, want 1", len(resp.Conflicts))
	}

	// Wait for the async push notification goroutine to complete.
	for i := 0; i < 50; i++ {
		if pushCalled.Load() {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if !pushCalled.Load() {
		t.Error("expected SendPush to be called when conflicts occur")
	}
}

func TestSyncService_Push_NoConflicts_NoPushNotification(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		upsertResult: true, // all accepted, no conflicts
	}

	pushSvc := &mockPushServiceForSync{
		sendPushFn: func(ctx context.Context, userIDStr string, payload PushPayload) error {
			t.Error("SendPush should not be called when there are no conflicts")
			return nil
		},
	}

	svc := NewSyncService(repo, WithPushService(pushSvc))
	_, err := svc.Push(context.Background(), userID, domain.SyncPushRequest{
		Blobs: []domain.SyncPushItem{
			{ItemID: uuid.New(), ItemType: "note", Version: 1, EncryptedData: []byte("enc1"), BlobSize: 100},
		},
	})
	if err != nil {
		t.Fatalf("Push: %v", err)
	}

	// Brief wait to ensure goroutine (if any) has time to fire.
	time.Sleep(50 * time.Millisecond)
}

// ---------------------------------------------------------------------------
// Mock PushService for sync tests
// ---------------------------------------------------------------------------

type mockPushServiceForSync struct {
	sendPushFn func(ctx context.Context, userID string, payload PushPayload) error
}

func (m *mockPushServiceForSync) RegisterDevice(ctx context.Context, userID string, token string, platform string) error {
	return nil
}

func (m *mockPushServiceForSync) UnregisterDevice(ctx context.Context, token string) error {
	return nil
}

func (m *mockPushServiceForSync) SendPush(ctx context.Context, userID string, payload PushPayload) error {
	if m.sendPushFn != nil {
		return m.sendPushFn(ctx, userID, payload)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Tests: ListTags
// ---------------------------------------------------------------------------

func TestSyncService_ListTags_Success(t *testing.T) {
	userID := uuid.New()
	tagID1 := uuid.New()
	tagID2 := uuid.New()
	now := time.Now()

	repo := &mockSyncBlobRepo{
		blobs: []domain.SyncBlob{
			{UserID: userID, ItemType: "tag", ItemID: tagID1, Version: 3, BlobSize: 64, UpdatedAt: now},
			{UserID: userID, ItemType: "tag", ItemID: tagID2, Version: 7, BlobSize: 128, UpdatedAt: now},
			{UserID: userID, ItemType: "note", ItemID: uuid.New(), Version: 5},
		},
	}

	svc := NewSyncService(repo)
	resp, err := svc.ListTags(context.Background(), userID)
	if err != nil {
		t.Fatalf("ListTags: %v", err)
	}

	if len(resp.Tags) != 2 {
		t.Fatalf("len(Tags) = %d, want 2", len(resp.Tags))
	}
	if resp.Tags[0].ItemID != tagID1 {
		t.Errorf("Tags[0].ItemID = %v, want %v", resp.Tags[0].ItemID, tagID1)
	}
	if resp.Tags[1].Version != 7 {
		t.Errorf("Tags[1].Version = %d, want 7", resp.Tags[1].Version)
	}
}

func TestSyncService_ListTags_Empty(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		blobs: []domain.SyncBlob{
			{UserID: userID, ItemType: "note", ItemID: uuid.New(), Version: 1},
		},
	}

	svc := NewSyncService(repo)
	resp, err := svc.ListTags(context.Background(), userID)
	if err != nil {
		t.Fatalf("ListTags: %v", err)
	}
	if len(resp.Tags) != 0 {
		t.Errorf("len(Tags) = %d, want 0", len(resp.Tags))
	}
}

func TestSyncService_ListTags_RepoError(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		listTagsByTypeErr: errors.New("database unavailable"),
	}

	svc := NewSyncService(repo)
	_, err := svc.ListTags(context.Background(), userID)
	if err == nil {
		t.Error("ListTags should return error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: BatchDelete
// ---------------------------------------------------------------------------

func TestSyncService_BatchDelete_Success(t *testing.T) {
	userID := uuid.New()
	id1 := uuid.New()
	id2 := uuid.New()

	repo := &mockSyncBlobRepo{
		blobs: []domain.SyncBlob{
			{UserID: userID, ItemType: "note", ItemID: id1, Version: 1},
			{UserID: userID, ItemType: "tag", ItemID: id2, Version: 2},
		},
	}

	svc := NewSyncService(repo)
	resp, err := svc.BatchDelete(context.Background(), userID, []uuid.UUID{id1, id2})
	if err != nil {
		t.Fatalf("BatchDelete: %v", err)
	}
	if resp.Deleted != 2 {
		t.Errorf("Deleted = %d, want 2", resp.Deleted)
	}
}

func TestSyncService_BatchDelete_EmptyList(t *testing.T) {
	userID := uuid.New()
	repo := &mockSyncBlobRepo{}

	svc := NewSyncService(repo)
	resp, err := svc.BatchDelete(context.Background(), userID, []uuid.UUID{})
	if err != nil {
		t.Fatalf("BatchDelete: %v", err)
	}
	if resp.Deleted != 0 {
		t.Errorf("Deleted = %d, want 0", resp.Deleted)
	}
}

func TestSyncService_BatchDelete_RepoError(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		batchDeleteErr: errors.New("database unavailable"),
	}

	svc := NewSyncService(repo)
	_, err := svc.BatchDelete(context.Background(), userID, []uuid.UUID{uuid.New()})
	if err == nil {
		t.Error("BatchDelete should return error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetProgress
// ---------------------------------------------------------------------------

func TestSyncService_GetProgress_Success(t *testing.T) {
	userID := uuid.New()
	now := time.Now()

	repo := &mockSyncBlobRepo{
		latestVersion:    42,
		totalItems:       100,
		lastUpdated:      now,
		conflictCountVal: 0,
		opCountsPush:     15,
		opCountsPull:     8,
	}

	svc := NewSyncService(repo)
	progress, err := svc.GetProgress(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetProgress: %v", err)
	}

	if progress.TotalItems != 100 {
		t.Errorf("TotalItems = %d, want 100", progress.TotalItems)
	}
	if progress.LatestVersion != 42 {
		t.Errorf("LatestVersion = %d, want 42", progress.LatestVersion)
	}
	if progress.ConflictCount != 0 {
		t.Errorf("ConflictCount = %d, want 0", progress.ConflictCount)
	}
	if progress.HealthStatus != "ok" {
		t.Errorf("HealthStatus = %q, want %q", progress.HealthStatus, "ok")
	}
	if progress.PushCount24h != 15 {
		t.Errorf("PushCount24h = %d, want 15", progress.PushCount24h)
	}
	if progress.PullCount24h != 8 {
		t.Errorf("PullCount24h = %d, want 8", progress.PullCount24h)
	}
}

func TestSyncService_GetProgress_HighConflictRatio_Warnings(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		conflictCountVal: 1,
		opCountsPush:     50,
		opCountsPull:     0,
	}

	svc := NewSyncService(repo)
	progress, err := svc.GetProgress(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetProgress: %v", err)
	}

	// conflict ratio = 1/50 = 0.02 > 0.01 but < 0.1, so "warnings"
	if progress.HealthStatus != "warnings" {
		t.Errorf("HealthStatus = %q, want %q", progress.HealthStatus, "warnings")
	}
}

func TestSyncService_GetProgress_VeryHighConflictRatio_Errors(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		conflictCountVal: 10,
		opCountsPush:     50,
		opCountsPull:     0,
	}

	svc := NewSyncService(repo)
	progress, err := svc.GetProgress(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetProgress: %v", err)
	}

	// conflict ratio = 10/50 = 0.2 > 0.1, so "errors"
	if progress.HealthStatus != "errors" {
		t.Errorf("HealthStatus = %q, want %q", progress.HealthStatus, "errors")
	}
}

func TestSyncService_GetProgress_ConflictCountError(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		conflictCountErr: errors.New("db error"),
	}

	svc := NewSyncService(repo)
	_, err := svc.GetProgress(context.Background(), userID)
	if err == nil {
		t.Error("GetProgress should return error when GetConflictCount fails")
	}
}

func TestSyncService_GetProgress_OperationCountsError(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		opCountsErr: errors.New("db error"),
	}

	svc := NewSyncService(repo)
	_, err := svc.GetProgress(context.Background(), userID)
	if err == nil {
		t.Error("GetProgress should return error when GetOperationCounts fails")
	}
}

func TestSyncService_GetProgress_ZeroOps_NoDivideByZero(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		conflictCountVal: 0,
		opCountsPush:     0,
		opCountsPull:     0,
	}

	svc := NewSyncService(repo)
	progress, err := svc.GetProgress(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetProgress: %v", err)
	}

	// With zero total operations, health should be "ok" (no division).
	if progress.HealthStatus != "ok" {
		t.Errorf("HealthStatus = %q, want %q", progress.HealthStatus, "ok")
	}
}
