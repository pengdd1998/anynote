package service

import (
	"context"
	"errors"
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
	blobs          []domain.SyncBlob
	latestVersion  int
	totalItems     int
	lastUpdated    time.Time
	pullErr        error
	upsertErr      error
	upsertResult   bool // accepted or conflict
	versionErr     error
	countErr       error
	lastUpdatedErr error
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

func (m *mockSyncBlobRepo) Upsert(ctx context.Context, blob *domain.SyncBlob) (bool, error) {
	if m.upsertErr != nil {
		return false, m.upsertErr
	}
	return m.upsertResult, nil
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

// ---------------------------------------------------------------------------
// Tests
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
	resp, err := svc.Pull(context.Background(), userID, 2)
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
	resp, err := svc.Pull(context.Background(), userID, 10)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	if len(resp.Blobs) != 0 {
		t.Errorf("len(Blobs) = %d, want 0", len(resp.Blobs))
	}
	if resp.LatestVersion != 10 {
		t.Errorf("LatestVersion = %d, want 10", resp.LatestVersion)
	}
}

func TestSyncService_Pull_RepoError(t *testing.T) {
	userID := uuid.New()

	repo := &mockSyncBlobRepo{
		pullErr: errors.New("database unavailable"),
	}

	svc := NewSyncService(repo)
	_, err := svc.Pull(context.Background(), userID, 0)
	if err == nil {
		t.Error("expected error when repo.PullSince fails")
	}
}

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
		upsertFn: func(blob *domain.SyncBlob) (bool, error) {
			callCount++
			if callCount == 1 {
				return true, nil // accepted
			}
			return false, nil // conflict
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

	// GetStatus tolerates individual repo errors (uses zero values).
	repo := &mockSyncBlobRepo{
		versionErr:     errors.New("version query failed"),
		countErr:       errors.New("count query failed"),
		lastUpdatedErr: errors.New("last updated query failed"),
	}

	svc := NewSyncService(repo)
	status, err := svc.GetStatus(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetStatus should not return error: %v", err)
	}
	if status.LatestVersion != 0 {
		t.Errorf("LatestVersion = %d, want 0 (default on error)", status.LatestVersion)
	}
	if status.TotalItems != 0 {
		t.Errorf("TotalItems = %d, want 0 (default on error)", status.TotalItems)
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
	upsertFn       func(blob *domain.SyncBlob) (bool, error)
}

func (m *customUpsertRepo) PullSince(ctx context.Context, userID uuid.UUID, sinceVersion int) ([]domain.SyncBlob, error) {
	return m.blobs, nil
}

func (m *customUpsertRepo) Upsert(ctx context.Context, blob *domain.SyncBlob) (bool, error) {
	return m.upsertFn(blob)
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
