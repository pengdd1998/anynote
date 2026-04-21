package service

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/platform"
)

// ---------------------------------------------------------------------------
// Mock PlatformConnectionRepository
// ---------------------------------------------------------------------------

type mockPlatformConnRepo struct {
	conns    map[string]*domain.PlatformConnection // keyed by "userID:platform"
	byID     map[uuid.UUID]*domain.PlatformConnection
	createFn func(conn *domain.PlatformConnection) error
	updateFn func(conn *domain.PlatformConnection) error
	deleteFn func(id uuid.UUID) error
}

func newMockPlatformConnRepo() *mockPlatformConnRepo {
	return &mockPlatformConnRepo{
		conns: make(map[string]*domain.PlatformConnection),
		byID:  make(map[uuid.UUID]*domain.PlatformConnection),
	}
}

func (m *mockPlatformConnRepo) key(userID uuid.UUID, platformName string) string {
	return userID.String() + ":" + platformName
}

func (m *mockPlatformConnRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error) {
	var result []domain.PlatformConnection
	for _, c := range m.conns {
		if c.UserID == userID {
			result = append(result, *c)
		}
	}
	return result, nil
}

func (m *mockPlatformConnRepo) GetByPlatform(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
	c, ok := m.conns[m.key(userID, platformName)]
	if !ok {
		return nil, errors.New("not found")
	}
	return c, nil
}

func (m *mockPlatformConnRepo) Create(ctx context.Context, conn *domain.PlatformConnection) error {
	if m.createFn != nil {
		if err := m.createFn(conn); err != nil {
			return err
		}
	}
	m.conns[m.key(conn.UserID, conn.Platform)] = conn
	m.byID[conn.ID] = conn
	return nil
}

func (m *mockPlatformConnRepo) Delete(ctx context.Context, id uuid.UUID) error {
	if m.deleteFn != nil {
		if err := m.deleteFn(id); err != nil {
			return err
		}
	}
	if c, ok := m.byID[id]; ok {
		delete(m.conns, m.key(c.UserID, c.Platform))
		delete(m.byID, id)
	}
	return nil
}

func (m *mockPlatformConnRepo) Update(ctx context.Context, conn *domain.PlatformConnection) error {
	if m.updateFn != nil {
		if err := m.updateFn(conn); err != nil {
			return err
		}
	}
	m.conns[m.key(conn.UserID, conn.Platform)] = conn
	m.byID[conn.ID] = conn
	return nil
}

// ---------------------------------------------------------------------------
// Mock Adapter (satisfies platform.Adapter)
// ---------------------------------------------------------------------------

type mockPlatformAdapter struct {
	startAuthFn   func(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error)
	pollAuthFn    func(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error)
	publishFn     func(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error)
	checkStatusFn func(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error)
	revokeAuthFn  func(ctx context.Context, encryptedAuth []byte, masterKey []byte) error
}

func (m *mockPlatformAdapter) Name() string { return "mockplatform" }

func (m *mockPlatformAdapter) StartAuth(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
	if m.startAuthFn != nil {
		return m.startAuthFn(ctx, masterKey)
	}
	return &platform.AuthSession{AuthRef: "test-auth-ref"}, []byte("fake-qr-png"), nil
}

func (m *mockPlatformAdapter) PollAuth(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
	if m.pollAuthFn != nil {
		return m.pollAuthFn(ctx, session, masterKey)
	}
	return nil, nil
}

func (m *mockPlatformAdapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
	if m.publishFn != nil {
		return m.publishFn(ctx, encryptedAuth, masterKey, params)
	}
	return &platform.PublishResult{PlatformURL: "https://mock.platform/post/123", PlatformID: "123"}, nil
}

func (m *mockPlatformAdapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	if m.checkStatusFn != nil {
		return m.checkStatusFn(ctx, encryptedAuth, masterKey, platformID)
	}
	return "live", nil
}

func (m *mockPlatformAdapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	if m.revokeAuthFn != nil {
		return m.revokeAuthFn(ctx, encryptedAuth, masterKey)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestPlatformService_List(t *testing.T) {
	repo := newMockPlatformConnRepo()
	userID := uuid.New()
	repo.conns[repo.key(userID, "xiaohongshu")] = &domain.PlatformConnection{
		ID:       uuid.New(),
		UserID:   userID,
		Platform: "xiaohongshu",
		Status:   "active",
	}

	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	conns, err := svc.List(context.Background(), userID)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(conns) != 1 {
		t.Errorf("len(conns) = %d, want 1", len(conns))
	}
	if conns[0].Platform != "xiaohongshu" {
		t.Errorf("Platform = %q, want %q", conns[0].Platform, "xiaohongshu")
	}
}

func TestPlatformService_Connect_Success(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	userID := uuid.New()
	conn, err := svc.Connect(context.Background(), userID, "xiaohongshu")
	if err != nil {
		t.Fatalf("Connect: %v", err)
	}
	if conn.Platform != "xiaohongshu" {
		t.Errorf("Platform = %q, want %q", conn.Platform, "xiaohongshu")
	}
	if conn.Status != "pending" {
		t.Errorf("Status = %q, want %q", conn.Status, "pending")
	}
	if conn.ID == uuid.Nil {
		t.Error("ID should be set")
	}
}

func TestPlatformService_Connect_AlreadyConnected(t *testing.T) {
	repo := newMockPlatformConnRepo()
	userID := uuid.New()
	repo.conns[repo.key(userID, "xiaohongshu")] = &domain.PlatformConnection{
		ID:       uuid.New(),
		UserID:   userID,
		Platform: "xiaohongshu",
		Status:   "active",
	}

	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	_, err := svc.Connect(context.Background(), userID, "xiaohongshu")
	if err == nil {
		t.Error("expected error when platform already connected")
	}
}

func TestPlatformService_Disconnect_Success(t *testing.T) {
	repo := newMockPlatformConnRepo()
	userID := uuid.New()
	connID := uuid.New()
	repo.conns[repo.key(userID, "xiaohongshu")] = &domain.PlatformConnection{
		ID:            connID,
		UserID:        userID,
		Platform:      "xiaohongshu",
		EncryptedAuth: []byte("encrypted-auth-data"),
		Status:        "active",
	}
	repo.byID[connID] = repo.conns[repo.key(userID, "xiaohongshu")]

	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)

	err := svc.Disconnect(context.Background(), userID, "xiaohongshu")
	if err != nil {
		t.Fatalf("Disconnect: %v", err)
	}
	if _, exists := repo.conns[repo.key(userID, "xiaohongshu")]; exists {
		t.Error("connection should be removed")
	}
}

func TestPlatformService_Disconnect_NotConnected(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	err := svc.Disconnect(context.Background(), uuid.New(), "xiaohongshu")
	if err == nil {
		t.Error("expected error when platform not connected")
	}
}

func TestPlatformService_Verify_Success(t *testing.T) {
	repo := newMockPlatformConnRepo()
	userID := uuid.New()
	connID := uuid.New()
	repo.conns[repo.key(userID, "xiaohongshu")] = &domain.PlatformConnection{
		ID:       connID,
		UserID:   userID,
		Platform: "xiaohongshu",
		Status:   "pending",
	}
	repo.byID[connID] = repo.conns[repo.key(userID, "xiaohongshu")]

	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	conn, err := svc.Verify(context.Background(), userID, "xiaohongshu")
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if conn.Status != "active" {
		t.Errorf("Status = %q, want %q", conn.Status, "active")
	}
}

func TestPlatformService_Verify_NotConnected(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	_, err := svc.Verify(context.Background(), uuid.New(), "xiaohongshu")
	if err == nil {
		t.Error("expected error when platform not connected")
	}
}

func TestPlatformService_StartAuth_Success(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{
		startAuthFn: func(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
			return &platform.AuthSession{AuthRef: "qr-session-123"}, []byte("qr-png-bytes"), nil
		},
	}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)
	userID := uuid.New()

	authRef, qrPNG, err := svc.StartAuth(context.Background(), userID, "xiaohongshu", []byte("master-key"))
	if err != nil {
		t.Fatalf("StartAuth: %v", err)
	}
	if authRef != "qr-session-123" {
		t.Errorf("authRef = %q, want %q", authRef, "qr-session-123")
	}
	if string(qrPNG) != "qr-png-bytes" {
		t.Errorf("qrPNG = %q, want %q", string(qrPNG), "qr-png-bytes")
	}
}

func TestPlatformService_StartAuth_UnsupportedPlatform(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	_, _, err := svc.StartAuth(context.Background(), uuid.New(), "nonexistent", []byte("key"))
	if err == nil {
		t.Error("expected error for unsupported platform")
	}
}

func TestPlatformService_PollAuth_Pending(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{
		pollAuthFn: func(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
			return nil, nil // still pending
		},
	}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)
	userID := uuid.New()

	// First, start an auth session so it is stored in memory.
	authRef, _, err := svc.StartAuth(context.Background(), userID, "xiaohongshu", []byte("master-key"))
	if err != nil {
		t.Fatalf("StartAuth: %v", err)
	}

	encryptedAuth, err := svc.PollAuth(context.Background(), userID, "xiaohongshu", authRef, []byte("master-key"))
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if encryptedAuth != nil {
		t.Error("expected nil while auth is still pending")
	}
}

func TestPlatformService_PollAuth_Success(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{
		startAuthFn: func(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
			return &platform.AuthSession{AuthRef: "session-abc"}, []byte("qr"), nil
		},
		pollAuthFn: func(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
			return []byte("encrypted-auth-data"), nil
		},
	}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)
	userID := uuid.New()

	authRef, _, err := svc.StartAuth(context.Background(), userID, "xiaohongshu", []byte("master-key"))
	if err != nil {
		t.Fatalf("StartAuth: %v", err)
	}

	encryptedAuth, err := svc.PollAuth(context.Background(), userID, "xiaohongshu", authRef, []byte("master-key"))
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if string(encryptedAuth) != "encrypted-auth-data" {
		t.Errorf("encryptedAuth = %q, want %q", string(encryptedAuth), "encrypted-auth-data")
	}

	// Verify the connection was persisted.
	conn, connErr := repo.GetByPlatform(context.Background(), userID, "xiaohongshu")
	if connErr != nil {
		t.Fatalf("GetByPlatform: %v", connErr)
	}
	if conn.Status != "active" {
		t.Errorf("Status = %q, want %q", conn.Status, "active")
	}
}

func TestPlatformService_PollAuth_SessionNotFound(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	_, err := svc.PollAuth(context.Background(), uuid.New(), "xiaohongshu", "nonexistent-ref", []byte("key"))
	if err == nil {
		t.Error("expected error for nonexistent auth session")
	}
}

func TestPlatformService_Publish_Success(t *testing.T) {
	repo := newMockPlatformConnRepo()
	userID := uuid.New()
	repo.conns[repo.key(userID, "xiaohongshu")] = &domain.PlatformConnection{
		ID:            uuid.New(),
		UserID:        userID,
		Platform:      "xiaohongshu",
		EncryptedAuth: []byte("encrypted-auth"),
		Status:        "active",
	}

	registry := platform.NewRegistry()
	var capturedParams platform.PublishParams
	adapter := &mockPlatformAdapter{
		publishFn: func(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
			capturedParams = params
			return &platform.PublishResult{
				PlatformURL: "https://www.xiaohongshu.com/explore/abc123",
				PlatformID:  "abc123",
			}, nil
		},
	}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)

	publishLog, err := svc.Publish(context.Background(), userID, "xiaohongshu", PlatformPublishRequest{
		Title:   "Test Post",
		Content: "Hello World",
		Tags:    []string{"test"},
		Images: []PlatformPublishImage{
			{URL: "https://example.com/image.jpg"},
		},
	}, []byte("master-key"))
	if err != nil {
		t.Fatalf("Publish: %v", err)
	}
	if publishLog.Status != "published" {
		t.Errorf("Status = %q, want %q", publishLog.Status, "published")
	}
	if publishLog.PlatformURL != "https://www.xiaohongshu.com/explore/abc123" {
		t.Errorf("PlatformURL = %q, want correct URL", publishLog.PlatformURL)
	}
	if capturedParams.Title != "Test Post" {
		t.Errorf("Title = %q, want %q", capturedParams.Title, "Test Post")
	}
	if len(capturedParams.Images) != 1 {
		t.Errorf("len(Images) = %d, want 1", len(capturedParams.Images))
	}
}

func TestPlatformService_Publish_NotConnected(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	registry.Register("xiaohongshu", &mockPlatformAdapter{})

	svc := NewPlatformService(repo, registry)

	_, err := svc.Publish(context.Background(), uuid.New(), "xiaohongshu", PlatformPublishRequest{
		Title: "Test",
	}, []byte("key"))
	if err == nil {
		t.Error("expected error when platform not connected")
	}
}

func TestPlatformService_Publish_ExpiredAuth(t *testing.T) {
	repo := newMockPlatformConnRepo()
	userID := uuid.New()
	repo.conns[repo.key(userID, "xiaohongshu")] = &domain.PlatformConnection{
		ID:            uuid.New(),
		UserID:        userID,
		Platform:      "xiaohongshu",
		EncryptedAuth: []byte{}, // empty auth
		Status:        "active",
	}

	registry := platform.NewRegistry()
	registry.Register("xiaohongshu", &mockPlatformAdapter{})

	svc := NewPlatformService(repo, registry)

	_, err := svc.Publish(context.Background(), userID, "xiaohongshu", PlatformPublishRequest{
		Title: "Test",
	}, []byte("key"))
	if err == nil {
		t.Error("expected error when auth data is empty")
	}
}

func TestPlatformService_Publish_UnsupportedPlatform(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	svc := NewPlatformService(repo, registry)

	_, err := svc.Publish(context.Background(), uuid.New(), "nonexistent", PlatformPublishRequest{}, []byte("key"))
	if err == nil {
		t.Error("expected error for unsupported platform")
	}
}

func TestPlatformService_CheckStatus_Success(t *testing.T) {
	repo := newMockPlatformConnRepo()
	userID := uuid.New()
	repo.conns[repo.key(userID, "xiaohongshu")] = &domain.PlatformConnection{
		ID:            uuid.New(),
		UserID:        userID,
		Platform:      "xiaohongshu",
		EncryptedAuth: []byte("encrypted-auth"),
		Status:        "active",
	}

	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{
		checkStatusFn: func(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
			if platformID != "note-123" {
				t.Errorf("platformID = %q, want %q", platformID, "note-123")
			}
			return "live", nil
		},
	}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)

	status, err := svc.CheckStatus(context.Background(), userID, "xiaohongshu", "note-123", []byte("key"))
	if err != nil {
		t.Fatalf("CheckStatus: %v", err)
	}
	if status != "live" {
		t.Errorf("status = %q, want %q", status, "live")
	}
}

func TestPlatformService_CheckStatus_NotConnected(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	registry.Register("xiaohongshu", &mockPlatformAdapter{})

	svc := NewPlatformService(repo, registry)

	status, err := svc.CheckStatus(context.Background(), uuid.New(), "xiaohongshu", "note-123", []byte("key"))
	if err == nil {
		t.Error("expected error when platform not connected")
	}
	if status != "unknown" {
		t.Errorf("status = %q, want %q", status, "unknown")
	}
}

func TestPlatformService_PollAuth_CreatesNewConnection(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{
		startAuthFn: func(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
			return &platform.AuthSession{AuthRef: "new-conn-session"}, []byte("qr"), nil
		},
		pollAuthFn: func(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
			return []byte("new-encrypted-auth"), nil
		},
	}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)
	userID := uuid.New()

	authRef, _, err := svc.StartAuth(context.Background(), userID, "xiaohongshu", []byte("master-key"))
	if err != nil {
		t.Fatalf("StartAuth: %v", err)
	}

	encryptedAuth, err := svc.PollAuth(context.Background(), userID, "xiaohongshu", authRef, []byte("master-key"))
	if err != nil {
		t.Fatalf("PollAuth: %v", err)
	}
	if string(encryptedAuth) != "new-encrypted-auth" {
		t.Errorf("encryptedAuth = %q, want %q", string(encryptedAuth), "new-encrypted-auth")
	}

	// Verify a new connection was created (no existing connection existed).
	conn, connErr := repo.GetByPlatform(context.Background(), userID, "xiaohongshu")
	if connErr != nil {
		t.Fatalf("GetByPlatform: %v", connErr)
	}
	if conn.Status != "active" {
		t.Errorf("Status = %q, want %q", conn.Status, "active")
	}
	if string(conn.EncryptedAuth) != "new-encrypted-auth" {
		t.Errorf("EncryptedAuth = %q, want %q", string(conn.EncryptedAuth), "new-encrypted-auth")
	}
}

func TestPlatformService_PollAuth_CreateConnectionError(t *testing.T) {
	repo := newMockPlatformConnRepo()
	repo.createFn = func(conn *domain.PlatformConnection) error {
		return errors.New("db create failed")
	}

	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{
		startAuthFn: func(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
			return &platform.AuthSession{AuthRef: "create-err-session"}, []byte("qr"), nil
		},
		pollAuthFn: func(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
			return []byte("auth-data"), nil
		},
	}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)
	userID := uuid.New()

	authRef, _, err := svc.StartAuth(context.Background(), userID, "xiaohongshu", []byte("master-key"))
	if err != nil {
		t.Fatalf("StartAuth: %v", err)
	}

	_, err = svc.PollAuth(context.Background(), userID, "xiaohongshu", authRef, []byte("master-key"))
	if err == nil {
		t.Error("expected error when connection creation fails")
	}
}

func TestPlatformService_CheckStatus_UnsupportedPlatform(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()

	svc := NewPlatformService(repo, registry)

	status, err := svc.CheckStatus(context.Background(), uuid.New(), "nonexistent", "note-123", []byte("key"))
	if err == nil {
		t.Error("expected error for unsupported platform")
	}
	if status != "unknown" {
		t.Errorf("status = %q, want %q", status, "unknown")
	}
}

func TestPlatformService_CancelAuth(t *testing.T) {
	repo := newMockPlatformConnRepo()
	registry := platform.NewRegistry()
	adapter := &mockPlatformAdapter{
		startAuthFn: func(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
			return &platform.AuthSession{AuthRef: "cancel-test-ref"}, []byte("qr"), nil
		},
	}
	registry.Register("xiaohongshu", adapter)

	svc := NewPlatformService(repo, registry)
	userID := uuid.New()

	// Start an auth session so it exists in the authSessions map.
	authRef, _, err := svc.StartAuth(context.Background(), userID, "xiaohongshu", []byte("key"))
	if err != nil {
		t.Fatalf("StartAuth: %v", err)
	}

	// Verify the session exists by polling.
	_, err = svc.PollAuth(context.Background(), userID, "xiaohongshu", authRef, []byte("key"))
	if err != nil {
		t.Fatalf("PollAuth before cancel: %v", err)
	}

	// Cancel the auth session.
	svc.CancelAuth(userID, "xiaohongshu", authRef)

	// PollAuth should now fail since the session was removed.
	_, err = svc.PollAuth(context.Background(), userID, "xiaohongshu", authRef, []byte("key"))
	if err == nil {
		t.Error("expected error after CancelAuth, session should be removed")
	}
}
