package handler

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock PlatformService
// ---------------------------------------------------------------------------

type mockPlatformService struct {
	listFn        func(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error)
	connectFn     func(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error)
	disconnectFn  func(ctx context.Context, userID uuid.UUID, platformName string) error
	verifyFn      func(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error)
	startAuthFn   func(ctx context.Context, userID uuid.UUID, platformName string, masterKey []byte) (string, []byte, error)
	pollAuthFn    func(ctx context.Context, userID uuid.UUID, platformName string, authRef string, masterKey []byte) ([]byte, error)
	cancelAuthFn  func(userID uuid.UUID, platformName string, authRef string)
	publishFn     func(ctx context.Context, userID uuid.UUID, platformName string, req service.PlatformPublishRequest, masterKey []byte) (*domain.PublishLog, error)
	checkStatusFn func(ctx context.Context, userID uuid.UUID, platformName string, platformID string, masterKey []byte) (string, error)
}

func (m *mockPlatformService) List(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error) {
	if m.listFn != nil {
		return m.listFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockPlatformService) Connect(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
	if m.connectFn != nil {
		return m.connectFn(ctx, userID, platformName)
	}
	return nil, errors.New("not implemented")
}

func (m *mockPlatformService) Disconnect(ctx context.Context, userID uuid.UUID, platformName string) error {
	if m.disconnectFn != nil {
		return m.disconnectFn(ctx, userID, platformName)
	}
	return errors.New("not implemented")
}

func (m *mockPlatformService) Verify(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
	if m.verifyFn != nil {
		return m.verifyFn(ctx, userID, platformName)
	}
	return nil, errors.New("not implemented")
}

func (m *mockPlatformService) StartAuth(ctx context.Context, userID uuid.UUID, platformName string, masterKey []byte) (string, []byte, error) {
	if m.startAuthFn != nil {
		return m.startAuthFn(ctx, userID, platformName, masterKey)
	}
	return "", nil, errors.New("not implemented")
}

func (m *mockPlatformService) PollAuth(ctx context.Context, userID uuid.UUID, platformName string, authRef string, masterKey []byte) ([]byte, error) {
	if m.pollAuthFn != nil {
		return m.pollAuthFn(ctx, userID, platformName, authRef, masterKey)
	}
	return nil, errors.New("not implemented")
}

func (m *mockPlatformService) Publish(ctx context.Context, userID uuid.UUID, platformName string, req service.PlatformPublishRequest, masterKey []byte) (*domain.PublishLog, error) {
	if m.publishFn != nil {
		return m.publishFn(ctx, userID, platformName, req, masterKey)
	}
	return nil, errors.New("not implemented")
}

func (m *mockPlatformService) CheckStatus(ctx context.Context, userID uuid.UUID, platformName string, platformID string, masterKey []byte) (string, error) {
	if m.checkStatusFn != nil {
		return m.checkStatusFn(ctx, userID, platformName, platformID, masterKey)
	}
	return "", errors.New("not implemented")
}

func (m *mockPlatformService) Stop() {}

func (m *mockPlatformService) CancelAuth(userID uuid.UUID, platformName string, authRef string) {
	if m.cancelAuthFn != nil {
		m.cancelAuthFn(userID, platformName, authRef)
	}
}

// ---------------------------------------------------------------------------
// Router setup helper
// ---------------------------------------------------------------------------

func setupPlatformRouter(svc *mockPlatformService) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestLogger)

	h := NewPlatformHandler(svc, []byte("test-master-key-16"))

	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		r.Get("/api/v1/platforms", h.List)
		r.Post("/api/v1/platforms/{platform}/connect", h.Connect)
		r.Post("/api/v1/platforms/{platform}/disconnect", h.Disconnect)
		r.Post("/api/v1/platforms/{platform}/verify", h.Verify)
	})

	return r
}

// ---------------------------------------------------------------------------
// Tests: List
// ---------------------------------------------------------------------------

func TestPlatformHandler_List_Success(t *testing.T) {
	userID := uuid.New()
	connID := uuid.New()

	svc := &mockPlatformService{
		listFn: func(ctx context.Context, uid uuid.UUID) ([]domain.PlatformConnection, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			return []domain.PlatformConnection{
				{
					ID:          connID,
					UserID:      userID,
					Platform:    "xiaohongshu",
					Status:      "active",
					DisplayName: "xhs_user",
				},
			}, nil
		},
	}

	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/platforms", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var conns []domain.PlatformConnection
	if err := json.NewDecoder(rec.Body).Decode(&conns); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(conns) != 1 {
		t.Fatalf("conns count = %d, want 1", len(conns))
	}
	if conns[0].Platform != "xiaohongshu" {
		t.Errorf("Platform = %q, want %q", conns[0].Platform, "xiaohongshu")
	}
}

func TestPlatformHandler_List_Empty(t *testing.T) {
	userID := uuid.New()

	svc := &mockPlatformService{
		listFn: func(ctx context.Context, uid uuid.UUID) ([]domain.PlatformConnection, error) {
			return []domain.PlatformConnection{}, nil
		},
	}

	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/platforms", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}
}

func TestPlatformHandler_List_Unauthorized(t *testing.T) {
	svc := &mockPlatformService{}
	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/platforms", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestPlatformHandler_List_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockPlatformService{
		listFn: func(ctx context.Context, uid uuid.UUID) ([]domain.PlatformConnection, error) {
			return nil, errors.New("db error")
		},
	}

	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/platforms", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: Disconnect
// ---------------------------------------------------------------------------

func TestPlatformHandler_Disconnect_Success(t *testing.T) {
	userID := uuid.New()
	disconnected := false

	svc := &mockPlatformService{
		disconnectFn: func(ctx context.Context, uid uuid.UUID, platformName string) error {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if platformName != "xiaohongshu" {
				t.Errorf("platformName = %q, want %q", platformName, "xiaohongshu")
			}
			disconnected = true
			return nil
		},
	}

	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/disconnect", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusNoContent, rec.Body.String())
	}
	if !disconnected {
		t.Error("expected disconnect to be called")
	}
}

func TestPlatformHandler_Disconnect_Unauthorized(t *testing.T) {
	svc := &mockPlatformService{}
	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/disconnect", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestPlatformHandler_Disconnect_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockPlatformService{
		disconnectFn: func(ctx context.Context, uid uuid.UUID, platformName string) error {
			return errors.New("platform not connected")
		},
	}

	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/disconnect", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: Verify
// ---------------------------------------------------------------------------

func TestPlatformHandler_Verify_Success(t *testing.T) {
	userID := uuid.New()
	connID := uuid.New()

	svc := &mockPlatformService{
		verifyFn: func(ctx context.Context, uid uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if platformName != "xiaohongshu" {
				t.Errorf("platformName = %q, want %q", platformName, "xiaohongshu")
			}
			return &domain.PlatformConnection{
				ID:       connID,
				UserID:   userID,
				Platform: "xiaohongshu",
				Status:   "active",
			}, nil
		},
	}

	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/verify", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var conn domain.PlatformConnection
	if err := json.NewDecoder(rec.Body).Decode(&conn); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if conn.Status != "active" {
		t.Errorf("Status = %q, want %q", conn.Status, "active")
	}
}

func TestPlatformHandler_Verify_Unauthorized(t *testing.T) {
	svc := &mockPlatformService{}
	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/verify", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestPlatformHandler_Verify_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockPlatformService{
		verifyFn: func(ctx context.Context, uid uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
			return nil, errors.New("platform not connected")
		},
	}

	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/verify", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: Connect (SSE streaming - test the StartAuth failure path)
// ---------------------------------------------------------------------------

func TestPlatformHandler_Connect_Unauthorized(t *testing.T) {
	svc := &mockPlatformService{}
	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/connect", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestPlatformHandler_Connect_EmptyPlatform(t *testing.T) {
	userID := uuid.New()
	svc := &mockPlatformService{}

	// Use a route with an empty platform parameter. Since chi.URLParam returns
	// "" for a missing or empty URL param, we hit the endpoint without the
	// platform segment in the path by using a direct handler call.
	h := NewPlatformHandler(svc, []byte("test-master-key-16"))
	r := chi.NewRouter()
	r.With(AuthMiddleware(testJWTSecret)).Post("/api/v1/platforms/{platform}/connect", h.Connect)

	// Request with a blank platform parameter in the URL.
	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms//connect", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnprocessableEntity, rec.Body.String())
	}
}

func TestPlatformHandler_Connect_SSESetup(t *testing.T) {
	userID := uuid.New()
	qrPNG := []byte("fake-qr-png-data")

	svc := &mockPlatformService{
		startAuthFn: func(ctx context.Context, uid uuid.UUID, platformName string, masterKey []byte) (string, []byte, error) {
			return "auth-ref-123", qrPNG, nil
		},
		// PollAuth returns nil (still pending) on first call, then context will be canceled.
		pollAuthFn: func(ctx context.Context, uid uuid.UUID, platformName string, authRef string, masterKey []byte) ([]byte, error) {
			return nil, nil
		},
	}

	h := NewPlatformHandler(svc, []byte("test-master-key-16"))
	r := chi.NewRouter()
	r.With(AuthMiddleware(testJWTSecret)).Post("/api/v1/platforms/{platform}/connect", h.Connect)

	// Use a cancellable context to stop the polling loop after the first event.
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/connect", nil).
		WithContext(ctx)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	// Cancel context shortly after to stop the infinite polling loop.
	go func() {
		time.Sleep(100 * time.Millisecond)
		cancel()
	}()

	r.ServeHTTP(rec, req)

	// Verify SSE headers were set.
	ct := rec.Header().Get("Content-Type")
	if ct != "text/event-stream" {
		t.Errorf("Content-Type = %q, want %q", ct, "text/event-stream")
	}
	cc := rec.Header().Get("Cache-Control")
	if cc != "no-cache" {
		t.Errorf("Cache-Control = %q, want %q", cc, "no-cache")
	}
	conn := rec.Header().Get("Connection")
	if conn != "keep-alive" {
		t.Errorf("Connection = %q, want %q", conn, "keep-alive")
	}

	// Verify QR code event was written.
	body := rec.Body.String()
	if !strings.Contains(body, "event: qr_code") {
		t.Errorf("expected SSE event qr_code in body, got: %s", body)
	}
	if !strings.Contains(body, "auth-ref-123") {
		t.Error("expected auth_ref value in SSE data")
	}
	// The QR PNG should be base64-encoded.
	expectedB64 := base64.StdEncoding.EncodeToString(qrPNG)
	if !strings.Contains(body, expectedB64) {
		t.Error("expected base64-encoded QR PNG in SSE data")
	}
}

func TestPlatformHandler_Disconnect_EmptyPlatform(t *testing.T) {
	userID := uuid.New()
	svc := &mockPlatformService{}

	h := NewPlatformHandler(svc, []byte("test-master-key-16"))
	r := chi.NewRouter()
	r.With(AuthMiddleware(testJWTSecret)).Post("/api/v1/platforms/{platform}/disconnect", h.Disconnect)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms//disconnect", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnprocessableEntity, rec.Body.String())
	}
}

func TestPlatformHandler_Verify_EmptyPlatform(t *testing.T) {
	userID := uuid.New()
	svc := &mockPlatformService{}

	h := NewPlatformHandler(svc, []byte("test-master-key-16"))
	r := chi.NewRouter()
	r.With(AuthMiddleware(testJWTSecret)).Post("/api/v1/platforms/{platform}/verify", h.Verify)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms//verify", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnprocessableEntity, rec.Body.String())
	}
}

func TestPlatformHandler_Connect_StartAuthError(t *testing.T) {
	userID := uuid.New()

	svc := &mockPlatformService{
		startAuthFn: func(ctx context.Context, uid uuid.UUID, platformName string, masterKey []byte) (string, []byte, error) {
			return "", nil, errors.New("adapter not found")
		},
	}

	router := setupPlatformRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/connect", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

func TestPlatformHandler_Connect_PollAuthSucceeds(t *testing.T) {
	userID := uuid.New()
	qrPNG := []byte("fake-qr-png-data")
	callCount := 0

	svc := &mockPlatformService{
		startAuthFn: func(ctx context.Context, uid uuid.UUID, platformName string, masterKey []byte) (string, []byte, error) {
			return "auth-ref-456", qrPNG, nil
		},
		pollAuthFn: func(ctx context.Context, uid uuid.UUID, platformName string, authRef string, masterKey []byte) ([]byte, error) {
			callCount++
			// First poll returns waiting (nil), second returns success.
			if callCount == 1 {
				return nil, nil
			}
			return []byte("encrypted-auth-data"), nil
		},
	}

	h := NewPlatformHandler(svc, []byte("test-master-key-16"))
	r := chi.NewRouter()
	r.With(AuthMiddleware(testJWTSecret)).Post("/api/v1/platforms/{platform}/connect", h.Connect)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/connect", nil).
		WithContext(ctx)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	body := rec.Body.String()

	// Should have QR code event, at least one waiting status, and a done status.
	if !strings.Contains(body, "event: qr_code") {
		t.Error("expected qr_code event")
	}
	if !strings.Contains(body, `"status":"waiting"`) {
		t.Error("expected waiting status event")
	}
	if !strings.Contains(body, `"status":"done"`) {
		t.Error("expected done status event")
	}
}

func TestPlatformHandler_Connect_PollAuthError(t *testing.T) {
	userID := uuid.New()
	qrPNG := []byte("fake-qr-png-data")

	svc := &mockPlatformService{
		startAuthFn: func(ctx context.Context, uid uuid.UUID, platformName string, masterKey []byte) (string, []byte, error) {
			return "auth-ref-789", qrPNG, nil
		},
		pollAuthFn: func(ctx context.Context, uid uuid.UUID, platformName string, authRef string, masterKey []byte) ([]byte, error) {
			return nil, errors.New("authentication rejected")
		},
	}

	h := NewPlatformHandler(svc, []byte("test-master-key-16"))
	r := chi.NewRouter()
	r.With(AuthMiddleware(testJWTSecret)).Post("/api/v1/platforms/{platform}/connect", h.Connect)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/connect", nil).
		WithContext(ctx)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	body := rec.Body.String()

	// Should have QR code event and then a failed status.
	if !strings.Contains(body, "event: qr_code") {
		t.Error("expected qr_code event")
	}
	if !strings.Contains(body, `"status":"failed"`) {
		t.Errorf("expected failed status event, got: %s", body)
	}
	if !strings.Contains(body, "authentication rejected") {
		t.Error("expected error message in failed event")
	}
}

// ---------------------------------------------------------------------------
// Tests: NewPlatformHandler constructor
// ---------------------------------------------------------------------------

func TestNewPlatformHandler(t *testing.T) {
	svc := &mockPlatformService{}
	key := []byte("master-key")
	h := NewPlatformHandler(svc, key)
	if h == nil {
		t.Fatal("NewPlatformHandler returned nil")
	}
	if h.platformService == nil {
		t.Error("platformService should not be nil")
	}
	if string(h.masterKey) != "master-key" {
		t.Errorf("masterKey = %q, want %q", string(h.masterKey), "master-key")
	}
}
