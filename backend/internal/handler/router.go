package handler

import (
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/service"
)

// Router creates and configures the main HTTP router.
func Router(cfg *config.Config, services *Services, healthH *HealthHandler) http.Handler {
	r := chi.NewRouter()

	// Middleware
	r.Use(SecurityHeaders)
	r.Use(MaxBodySize(DefaultMaxBodyBytes))
	r.Use(chiMiddleware.RequestID)
	r.Use(chiMiddleware.RealIP)
	r.Use(chiMiddleware.Recoverer)
	r.Use(MetricsMiddleware)
	r.Use(RequestLogger)
	r.Use(chiMiddleware.Timeout(120 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.Server.AllowOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health check routes (outside auth middleware, public access).
	r.Get("/health", healthH.HealthCheck)
	r.Get("/ready", healthH.ReadinessCheck)

	// Prometheus metrics endpoint (no auth required).
	r.Handle("/metrics", MetricsHandler())

	// Handlers
	authH := &AuthHandler{authService: services.Auth}
	syncH := &SyncHandler{syncService: services.Sync}
	aiH := &AIHandler{aiService: services.AIProxy, quotaSvc: services.Quota}
	llmH := &LLMConfigHandler{llmService: services.LLMConfig}
	publishH := &PublishHandler{publishService: services.Publish}
	platformH := NewPlatformHandler(services.Platform, []byte(cfg.Auth.MasterEncryptionKey))
	shareH := &ShareHandler{shareService: services.Share}
	pushH := &PushHandler{pushService: services.Push}
	commentH := &CommentHandler{commentService: services.Comment}
	wsH := NewWSHandler(services.Presence, cfg.Auth.JWTSecret, cfg.Server.AllowOrigins)

	// Rate limiters
	authRateLimiter := service.NewRateLimiter(20, time.Minute)    // 20 req/min per IP
	syncRateLimiter := service.NewRateLimiter(30, time.Minute)    // 30 req/min per user
	publishRateLimiter := service.NewRateLimiter(10, time.Minute) // 10 req/min per user

	r.Route("/api/v1", func(r chi.Router) {
		// Public auth routes (rate limited by IP)
		r.Route("/auth", func(r chi.Router) {
			r.With(RateLimitMiddleware(authRateLimiter, IPKeyFunc, time.Minute)).Post("/register", authH.Register)
			r.With(RateLimitMiddleware(authRateLimiter, IPKeyFunc, time.Minute)).Post("/login", authH.Login)
			r.With(RateLimitMiddleware(authRateLimiter, IPKeyFunc, time.Minute)).Post("/refresh", authH.RefreshToken)
		})

		// Public share retrieval (no auth required)
		r.Get("/share/{id}", shareH.GetShare)

		// Public discovery feed (no auth required)
		r.Get("/share/discover", shareH.DiscoverFeed)

		// WebSocket (auth handled inside handler via query-param token)
		r.Get("/ws", wsH.HandleConnection)

		// Authenticated routes
		r.Group(func(r chi.Router) {
			r.Use(AuthMiddleware(cfg.Auth.JWTSecret))

			// Auth
			r.Get("/auth/me", authH.Me)
			r.Delete("/auth/account", authH.DeleteAccount)

			// Sync (rate limited by user)
			r.With(RateLimitMiddleware(syncRateLimiter, UserIDKeyFunc, time.Minute)).Get("/sync/pull", syncH.Pull)
			r.With(
				MaxBodySize(SyncPushMaxBodyBytes),
				RateLimitMiddleware(syncRateLimiter, UserIDKeyFunc, time.Minute),
			).Post("/sync/push", syncH.Push)
			r.With(RateLimitMiddleware(syncRateLimiter, UserIDKeyFunc, time.Minute)).Get("/sync/status", syncH.Status)
			r.With(RateLimitMiddleware(syncRateLimiter, UserIDKeyFunc, time.Minute)).Get("/sync/stats", syncH.Stats)

			// AI Proxy
			r.Post("/ai/proxy", aiH.Proxy)
			r.Get("/ai/quota", aiH.GetQuota)

			// LLM Config
			r.Get("/llm/configs", llmH.List)
			r.Post("/llm/configs", llmH.Create)
			r.Put("/llm/configs/{id}", llmH.Update)
			r.Delete("/llm/configs/{id}", llmH.Delete)
			r.Post("/llm/configs/{id}/test", llmH.TestConnection)
			r.Get("/llm/providers", llmH.ListProviders)

			// Publish (rate limited by user)
			r.With(RateLimitMiddleware(publishRateLimiter, UserIDKeyFunc, time.Minute)).Post("/publish", publishH.Publish)
			r.Get("/publish/history", publishH.History)
			r.Get("/publish/{id}", publishH.GetByID)

			// Platform connections
			r.Get("/platforms", platformH.List)
			r.Post("/platforms/{platform}/connect", platformH.Connect)
			r.Delete("/platforms/{platform}/connect", platformH.Disconnect)
			r.Post("/platforms/{platform}/verify", platformH.Verify)

			// Share
			r.Post("/share", shareH.CreateShare)
			r.Post("/share/{id}/react", shareH.ToggleReaction)

			// Device registration (push notifications)
			r.Post("/devices/register", pushH.RegisterDeviceToken)
			r.Post("/devices/unregister", pushH.UnregisterDeviceToken)

			// Comments
			r.Get("/share/{id}/comments", commentH.ListComments)
			r.Post("/share/{id}/comments", commentH.CreateComment)
			r.Delete("/comments/{id}", commentH.DeleteComment)
		})
	})

	// Optional pprof endpoints (only when PPROF_ENABLED or DEBUG is set).
	registerPprofRoutes(r)

	return r
}

// Services holds all service instances.
type Services struct {
	Auth      service.AuthService
	Sync      service.SyncService
	AIProxy   service.AIProxyService
	Quota     service.QuotaService
	LLMConfig service.LLMConfigService
	Publish   service.PublishService
	Platform  service.PlatformService
	Share     service.ShareService
	Push      service.PushService
	Comment   service.CommentService
	Presence  service.PresenceService
}

// registerPprofRoutes mounts /debug/pprof/* endpoints when the PPROF_ENABLED
// or DEBUG environment variable is set to a truthy value ("1", "true", "yes").
// In production without these variables the routes are not registered.
func registerPprofRoutes(r chi.Router) {
	enabled := os.Getenv("PPROF_ENABLED") != "" || os.Getenv("DEBUG") != ""
	if !enabled {
		return
	}

	r.Route("/debug", func(r chi.Router) {
		r.HandleFunc("/pprof/", http.DefaultServeMux.ServeHTTP)
		r.HandleFunc("/pprof/cmdline", http.DefaultServeMux.ServeHTTP)
		r.HandleFunc("/pprof/profile", http.DefaultServeMux.ServeHTTP)
		r.HandleFunc("/pprof/symbol", http.DefaultServeMux.ServeHTTP)
		r.HandleFunc("/pprof/trace", http.DefaultServeMux.ServeHTTP)
	})
}
