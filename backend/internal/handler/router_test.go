package handler

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Stubs for all service interfaces (for Router wiring test)
// ---------------------------------------------------------------------------

// routerStubAuthService implements service.AuthService.
type routerStubAuthService struct{}

func (s *routerStubAuthService) Register(ctx context.Context, req domain.RegisterRequest) (*domain.AuthResponse, error) {
	return nil, nil
}
func (s *routerStubAuthService) Login(ctx context.Context, req domain.LoginRequest) (*domain.AuthResponse, error) {
	return nil, nil
}
func (s *routerStubAuthService) RefreshToken(ctx context.Context, refreshToken string) (*domain.AuthResponse, error) {
	return nil, nil
}
func (s *routerStubAuthService) GetCurrentUser(ctx context.Context, userID uuid.UUID) (*domain.User, error) {
	return nil, nil
}

// routerStubSyncService implements service.SyncService.
type routerStubSyncService struct{}

func (s *routerStubSyncService) Pull(ctx context.Context, userID uuid.UUID, sinceVersion int) (*domain.SyncPullResponse, error) {
	return nil, nil
}
func (s *routerStubSyncService) Push(ctx context.Context, userID uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
	return nil, nil
}
func (s *routerStubSyncService) GetStatus(ctx context.Context, userID uuid.UUID) (*domain.SyncStatusResponse, error) {
	return nil, nil
}

// routerStubAIProxyService implements service.AIProxyService.
type routerStubAIProxyService struct{}

func (s *routerStubAIProxyService) Proxy(ctx context.Context, userID string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
	return nil, nil
}

// routerStubQuotaService implements service.QuotaService.
type routerStubQuotaService struct{}

func (s *routerStubQuotaService) GetQuota(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
	return nil, nil
}
func (s *routerStubQuotaService) IncrementUsage(ctx context.Context, userID uuid.UUID) error {
	return nil
}

// routerStubLLMConfigService implements service.LLMConfigService.
type routerStubLLMConfigService struct{}

func (s *routerStubLLMConfigService) List(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error) {
	return nil, nil
}
func (s *routerStubLLMConfigService) Create(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
	return nil, nil
}
func (s *routerStubLLMConfigService) Update(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
	return nil, nil
}
func (s *routerStubLLMConfigService) Delete(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error {
	return nil
}
func (s *routerStubLLMConfigService) TestConnection(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error {
	return nil
}
func (s *routerStubLLMConfigService) GetDefault(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error) {
	return nil, nil
}
func (s *routerStubLLMConfigService) ListProviders() []string {
	return nil
}

// routerStubPublishService implements service.PublishService.
type routerStubPublishService struct{}

func (s *routerStubPublishService) Publish(ctx context.Context, userID uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
	return nil, nil
}
func (s *routerStubPublishService) GetHistory(ctx context.Context, userID uuid.UUID) ([]domain.PublishLog, error) {
	return nil, nil
}
func (s *routerStubPublishService) GetByID(ctx context.Context, userID uuid.UUID, id uuid.UUID) (*domain.PublishLog, error) {
	return nil, nil
}

// routerStubPlatformService implements service.PlatformService.
type routerStubPlatformService struct{}

func (s *routerStubPlatformService) List(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error) {
	return nil, nil
}
func (s *routerStubPlatformService) Connect(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
	return nil, nil
}
func (s *routerStubPlatformService) Disconnect(ctx context.Context, userID uuid.UUID, platformName string) error {
	return nil
}
func (s *routerStubPlatformService) Verify(ctx context.Context, userID uuid.UUID, platformName string) (*domain.PlatformConnection, error) {
	return nil, nil
}
func (s *routerStubPlatformService) StartAuth(ctx context.Context, userID uuid.UUID, platformName string, masterKey []byte) (string, []byte, error) {
	return "", nil, nil
}
func (s *routerStubPlatformService) PollAuth(ctx context.Context, userID uuid.UUID, platformName string, authRef string, masterKey []byte) ([]byte, error) {
	return nil, nil
}
func (s *routerStubPlatformService) Publish(ctx context.Context, userID uuid.UUID, platformName string, req service.PlatformPublishRequest, masterKey []byte) (*domain.PublishLog, error) {
	return nil, nil
}
func (s *routerStubPlatformService) CheckStatus(ctx context.Context, userID uuid.UUID, platformName string, platformID string, masterKey []byte) (string, error) {
	return "", nil
}

// routerStubShareService implements service.ShareService.
type routerStubShareService struct{}

func (s *routerStubShareService) CreateShare(ctx context.Context, userID uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
	return nil, nil
}
func (s *routerStubShareService) GetShare(ctx context.Context, id string) (*domain.GetShareResponse, error) {
	return nil, nil
}
func (s *routerStubShareService) DiscoverFeed(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
	return nil, nil
}
func (s *routerStubShareService) ToggleReaction(ctx context.Context, userID uuid.UUID, shareID string, reactionType string) (*domain.ReactResponse, error) {
	return nil, nil
}

// routerStubPushService implements service.PushService.
type routerStubPushService struct{}

func (s *routerStubPushService) RegisterDevice(ctx context.Context, userID string, token string, platform string) error {
	return nil
}
func (s *routerStubPushService) UnregisterDevice(ctx context.Context, token string) error {
	return nil
}
func (s *routerStubPushService) SendPush(ctx context.Context, userID string, payload service.PushPayload) error {
	return nil
}

// routerStubCommentService implements service.CommentService.
type routerStubCommentService struct{}

func (s *routerStubCommentService) CreateComment(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
	return nil, nil
}
func (s *routerStubCommentService) ListComments(ctx context.Context, sharedNoteID string, limit, offset int) (*domain.ListCommentsResponse, error) {
	return nil, nil
}
func (s *routerStubCommentService) DeleteComment(ctx context.Context, commentID, userID uuid.UUID) error {
	return nil
}

// routerStubPresenceService implements service.PresenceService.
type routerStubPresenceService struct{}

func (s *routerStubPresenceService) Join(ctx context.Context, room, userID, username string) error { return nil }
func (s *routerStubPresenceService) Leave(ctx context.Context, room, userID string) error          { return nil }
func (s *routerStubPresenceService) GetRoomMembers(ctx context.Context, room string) ([]service.RoomMember, error) {
	return nil, nil
}
func (s *routerStubPresenceService) SetTyping(ctx context.Context, room, userID string, isTyping bool) error {
	return nil
}
func (s *routerStubPresenceService) GetTypingUsers(ctx context.Context, room string) ([]string, error) {
	return nil, nil
}
func (s *routerStubPresenceService) BroadcastToRoom(ctx context.Context, room string, msg service.WSMessage) error {
	return nil
}
func (s *routerStubPresenceService) SubscribeRoom(ctx context.Context, room string) <-chan service.WSMessage {
	ch := make(chan service.WSMessage)
	close(ch)
	return ch
}

// routerStubPinger implements Pinger for health handler.
type routerStubPinger struct{}

func (s *routerStubPinger) Ping(ctx context.Context) error { return nil }

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// newTestRouterServices creates the standard set of stub services and config for router tests.
func newTestRouterServices() (*config.Config, *Services, *HealthHandler) {
	cfg := &config.Config{
		Server: config.ServerConfig{AllowOrigins: []string{"*"}},
		Auth: config.AuthConfig{
			JWTSecret:           testJWTSecret,
			MasterEncryptionKey: "0123456789abcdef0123456789abcdef",
		},
	}
	services := &Services{
		Auth:      &routerStubAuthService{},
		Sync:      &routerStubSyncService{},
		AIProxy:   &routerStubAIProxyService{},
		Quota:     &routerStubQuotaService{},
		LLMConfig: &routerStubLLMConfigService{},
		Publish:   &routerStubPublishService{},
		Platform:  &routerStubPlatformService{},
		Share:     &routerStubShareService{},
		Push:      &routerStubPushService{},
		Comment:   &routerStubCommentService{},
		Presence:  &routerStubPresenceService{},
	}
	healthH := NewHealthHandler(&routerStubPinger{}, nil)
	return cfg, services, healthH
}

// ---------------------------------------------------------------------------
// Tests: Router
// ---------------------------------------------------------------------------

func TestRouter_CreatesRoutes(t *testing.T) {
	cfg, services, healthH := newTestRouterServices()
	cfg.Server.AllowOrigins = []string{"http://localhost:3000"}

	router := Router(cfg, services, healthH)
	if router == nil {
		t.Fatal("Router returned nil")
	}

	// Verify health check routes are accessible (no auth required).
	routes := []struct {
		method string
		path   string
	}{
		{"GET", "/health"},
		{"GET", "/ready"},
	}

	for _, route := range routes {
		t.Run(route.method+" "+route.path, func(t *testing.T) {
			req := httptest.NewRequest(route.method, route.path, nil)
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)
			if rec.Code == http.StatusNotFound {
				t.Errorf("route %s %s returned 404 (not registered)", route.method, route.path)
			}
		})
	}
}

func TestRouter_PublicShareRoutes(t *testing.T) {
	cfg, services, healthH := newTestRouterServices()
	router := Router(cfg, services, healthH)

	// Public share routes should not return 404.
	publicRoutes := []struct {
		method string
		path   string
	}{
		{"GET", "/api/v1/share/test-id"},
		{"GET", "/api/v1/share/discover"},
	}

	for _, route := range publicRoutes {
		t.Run(route.method+" "+route.path, func(t *testing.T) {
			req := httptest.NewRequest(route.method, route.path, nil)
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)
			if rec.Code == http.StatusNotFound {
				t.Errorf("route %s %s returned 404 (not registered)", route.method, route.path)
			}
		})
	}
}

func TestRouter_MetricsEndpoint(t *testing.T) {
	cfg, services, healthH := newTestRouterServices()
	router := Router(cfg, services, healthH)

	req := httptest.NewRequest("GET", "/metrics", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("GET /metrics: got %d, want %d", rec.Code, http.StatusOK)
	}
	// The response body should contain Prometheus exposition text.
	ct := rec.Header().Get("Content-Type")
	if ct == "" {
		t.Error("GET /metrics: Content-Type header is empty")
	}
}

func TestRouter_AuthenticatedRoutesRequireAuth(t *testing.T) {
	cfg, services, healthH := newTestRouterServices()
	router := Router(cfg, services, healthH)

	// Authenticated routes should return 401 without token.
	protectedRoutes := []struct {
		method string
		path   string
	}{
		{"GET", "/api/v1/auth/me"},
		{"GET", "/api/v1/sync/pull"},
		{"POST", "/api/v1/sync/push"},
		{"GET", "/api/v1/sync/status"},
		{"POST", "/api/v1/ai/proxy"},
		{"GET", "/api/v1/ai/quota"},
		{"GET", "/api/v1/llm/configs"},
		{"POST", "/api/v1/llm/configs"},
		{"GET", "/api/v1/llm/providers"},
		{"POST", "/api/v1/publish"},
		{"GET", "/api/v1/publish/history"},
		{"GET", "/api/v1/platforms"},
		{"POST", "/api/v1/share"},
		{"POST", "/api/v1/devices/register"},
		{"POST", "/api/v1/devices/unregister"},
	}

	for _, route := range protectedRoutes {
		t.Run(route.method+" "+route.path, func(t *testing.T) {
			req := httptest.NewRequest(route.method, route.path, nil)
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)
			if rec.Code != http.StatusUnauthorized {
				t.Errorf("route %s %s without token: got %d, want %d",
					route.method, route.path, rec.Code, http.StatusUnauthorized)
			}
		})
	}
}

func TestRouter_ChiRoutes(t *testing.T) {
	cfg, services, healthH := newTestRouterServices()
	handler := Router(cfg, services, healthH)

	// Cast to chi.Routes for Walk (Router returns *chi.Mux which implements chi.Routes).
	chiRouter, ok := handler.(chi.Routes)
	if !ok {
		t.Fatal("Router did not return a chi.Routes implementor")
	}

	// Verify chi routes are registered by walking the routes.
	walkRoutes := []string{}
	chi.Walk(chiRouter, func(method, route string, handler http.Handler, middlewares ...func(http.Handler) http.Handler) error {
		walkRoutes = append(walkRoutes, method+" "+route)
		return nil
	})

	// Check that key routes exist.
	expectedPatterns := []string{
		"GET /health",
		"GET /ready",
		"GET /metrics",
		"POST /api/v1/auth/register",
		"POST /api/v1/auth/login",
		"GET /api/v1/auth/me",
		"GET /api/v1/sync/pull",
		"POST /api/v1/sync/push",
		"GET /api/v1/sync/status",
		"POST /api/v1/ai/proxy",
		"GET /api/v1/ai/quota",
		"GET /api/v1/llm/configs",
		"POST /api/v1/share",
		"GET /api/v1/platforms",
	}

	for _, expected := range expectedPatterns {
		found := false
		for _, r := range walkRoutes {
			if r == expected {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("expected route %q not found in registered routes", expected)
		}
	}
}
