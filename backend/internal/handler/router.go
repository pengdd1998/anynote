package handler

import (
	"crypto/subtle"
	"net/http"
	"os"
	"strconv"
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
	masterKey, err := cfg.Auth.MasterKeyBytes()
	if err != nil {
		// MasterKeyBytes should never fail after config.Validate(), but handle
		// it defensively to avoid silently using a nil key.
		panic("router: invalid master encryption key: " + err.Error())
	}
	platformH := NewPlatformHandler(services.Platform, masterKey)
	shareH := &ShareHandler{shareService: services.Share}
	pushH := &PushHandler{pushService: services.Push}
	commentH := &CommentHandler{commentService: services.Comment}
	wsH := NewWSHandler(services.Presence, cfg.Auth.JWTSecret, cfg.Server.AllowOrigins)

	// Rate limiters
	authRateLimiter := service.NewRateLimiter(20, time.Minute)    // 20 req/min per IP
	syncRateLimiter := service.NewRateLimiter(30, time.Minute)    // 30 req/min per user
	publishRateLimiter := service.NewRateLimiter(10, time.Minute) // 10 req/min per user
	discoverRateLimiter := service.NewRateLimiter(60, time.Minute) // 60 req/min per IP
	aiRateLimiter := service.NewRateLimiter(20, time.Minute)      // 20 req/min per user
	llmRateLimiter := service.NewRateLimiter(10, time.Minute)     // 10 req/min per user

	r.Route("/api/v1", func(r chi.Router) {
		// Public auth routes (rate limited by IP)
		r.Route("/auth", func(r chi.Router) {
			r.With(RateLimitMiddleware(authRateLimiter, IPKeyFunc, time.Minute)).Post("/register", authH.Register)
			r.With(RateLimitMiddleware(authRateLimiter, IPKeyFunc, time.Minute)).Post("/login", authH.Login)
			r.With(RateLimitMiddleware(authRateLimiter, IPKeyFunc, time.Minute)).Post("/refresh", authH.RefreshToken)
			r.With(RateLimitMiddleware(authRateLimiter, IPKeyFunc, time.Minute)).Get("/recovery-salt", authH.GetRecoverySalt)
		})

		// Public share retrieval (no auth required)
		r.Get("/share/{id}", shareH.GetShare)

		// Public discovery feed (no auth required, rate limited by IP)
		r.With(RateLimitMiddleware(discoverRateLimiter, IPKeyFunc, time.Minute)).Get("/share/discover", shareH.DiscoverFeed)

		// WebSocket (auth handled inside handler via query-param token)
		r.Get("/ws", wsH.HandleConnection)

		// Authenticated routes
		r.Group(func(r chi.Router) {
			r.Use(AuthMiddleware(cfg.Auth.JWTSecret))

			// WebSocket token generation (requires access token)
			r.Post("/ws/token", wsH.GenerateWSToken)

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
			r.With(RateLimitMiddleware(syncRateLimiter, UserIDKeyFunc, time.Minute)).Get("/sync/progress", syncH.Progress)
			r.With(
				MaxBodySize(SyncPushMaxBodyBytes),
				RateLimitMiddleware(syncRateLimiter, UserIDKeyFunc, time.Minute),
			).Post("/sync/batch-delete", syncH.BatchDelete)

			// Tags
			r.With(RateLimitMiddleware(syncRateLimiter, UserIDKeyFunc, time.Minute)).Get("/tags", syncH.ListTags)

			// AI Proxy (rate limited by user)
			r.With(RateLimitMiddleware(aiRateLimiter, UserIDKeyFunc, time.Minute)).Post("/ai/proxy", aiH.Proxy)
			r.With(RateLimitMiddleware(aiRateLimiter, UserIDKeyFunc, time.Minute)).Get("/ai/quota", aiH.GetQuota)

			// LLM Config (rate limited by user)
			r.With(RateLimitMiddleware(llmRateLimiter, UserIDKeyFunc, time.Minute)).Get("/llm/configs", llmH.List)
			r.With(RateLimitMiddleware(llmRateLimiter, UserIDKeyFunc, time.Minute)).Post("/llm/configs", llmH.Create)
			r.With(RateLimitMiddleware(llmRateLimiter, UserIDKeyFunc, time.Minute)).Put("/llm/configs/{id}", llmH.Update)
			r.With(RateLimitMiddleware(llmRateLimiter, UserIDKeyFunc, time.Minute)).Delete("/llm/configs/{id}", llmH.Delete)
			r.With(RateLimitMiddleware(llmRateLimiter, UserIDKeyFunc, time.Minute)).Post("/llm/configs/{id}/test", llmH.TestConnection)
			r.With(RateLimitMiddleware(llmRateLimiter, UserIDKeyFunc, time.Minute)).Get("/llm/providers", llmH.ListProviders)

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
//
// When PPROF_PASSWORD is set, endpoints are protected by HTTP Basic Auth
// (username "admin", password from the env var). When PPROF_PASSWORD is not
// set, the endpoints are accessible without authentication -- in this case
// ensure the server is behind a firewall or only bound to localhost.
func registerPprofRoutes(r chi.Router) {
	if !isTruthyEnv("PPROF_ENABLED") && !isTruthyEnv("DEBUG") {
		return
	}

	pprofPassword := os.Getenv("PPROF_PASSWORD")

	r.Route("/debug", func(r chi.Router) {
		if pprofPassword != "" {
			r.Use(pprofBasicAuth(pprofPassword))
		}
		r.HandleFunc("/pprof/", http.DefaultServeMux.ServeHTTP)
		r.HandleFunc("/pprof/cmdline", http.DefaultServeMux.ServeHTTP)
		r.HandleFunc("/pprof/profile", http.DefaultServeMux.ServeHTTP)
		r.HandleFunc("/pprof/symbol", http.DefaultServeMux.ServeHTTP)
		r.HandleFunc("/pprof/trace", http.DefaultServeMux.ServeHTTP)
	})
}

// pprofBasicAuth returns middleware that validates HTTP Basic Auth credentials
// for pprof endpoints. The username is fixed as "admin" and the password must
// match the provided string. Timing-safe comparison is used to prevent
// side-channel attacks.
func pprofBasicAuth(password string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			user, pass, ok := r.BasicAuth()
			if !ok ||
				subtle.ConstantTimeCompare([]byte(user), []byte("admin")) != 1 ||
				subtle.ConstantTimeCompare([]byte(pass), []byte(password)) != 1 {
				w.Header().Set("WWW-Authenticate", `Basic realm="pprof"`)
				http.Error(w, "Unauthorized", http.StatusUnauthorized)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// isTruthyEnv returns true if the environment variable is set to a truthy value
// ("1", "true", "yes"). Empty string or any other value returns false.
func isTruthyEnv(key string) bool {
	v := os.Getenv(key)
	if v == "" {
		return false
	}
	b, _ := strconv.ParseBool(v)
	return b
}
