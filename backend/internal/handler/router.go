package handler

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/service"
)

// Router creates and configures the main HTTP router.
func Router(cfg *config.Config, services *Services) http.Handler {
	r := chi.NewRouter()

	// Middleware
	r.Use(chiMiddleware.RequestID)
	r.Use(chiMiddleware.RealIP)
	r.Use(chiMiddleware.Recoverer)
	r.Use(chiMiddleware.Timeout(120 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.Server.AllowOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health check
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	})

	// Handlers
	authH := &AuthHandler{authService: services.Auth}
	syncH := &SyncHandler{syncService: services.Sync}
	aiH := &AIHandler{aiService: services.AIProxy, quotaSvc: services.Quota}
	llmH := &LLMConfigHandler{llmService: services.LLMConfig}
	publishH := &PublishHandler{publishService: services.Publish}
	platformH := &PlatformHandler{platformService: services.Platform}

	r.Route("/api/v1", func(r chi.Router) {
		// Public auth routes
		r.Route("/auth", func(r chi.Router) {
			r.Post("/register", authH.Register)
			r.Post("/login", authH.Login)
			r.Post("/refresh", authH.RefreshToken)
		})

		// Authenticated routes
		r.Group(func(r chi.Router) {
			r.Use(AuthMiddleware(cfg.Auth.JWTSecret))

			// Auth
			r.Get("/auth/me", authH.Me)

			// Sync
			r.Get("/sync/pull", syncH.Pull)
			r.Post("/sync/push", syncH.Push)
			r.Get("/sync/status", syncH.Status)

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

			// Publish
			r.Post("/publish", publishH.Publish)
			r.Get("/publish/history", publishH.History)
			r.Get("/publish/{id}", publishH.GetByID)

			// Platform connections
			r.Get("/platforms", platformH.List)
			r.Post("/platforms/{platform}/connect", platformH.Connect)
			r.Delete("/platforms/{platform}/connect", platformH.Disconnect)
			r.Post("/platforms/{platform}/verify", platformH.Verify)
		})
	})

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
}
