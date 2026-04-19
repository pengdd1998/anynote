package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/handler"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/platform/medium"
	"github.com/anynote/backend/internal/platform/webhook"
	"github.com/anynote/backend/internal/platform/wechat"
	"github.com/anynote/backend/internal/platform/wordpress"
	"github.com/anynote/backend/internal/platform/xiaohongshu"
	"github.com/anynote/backend/internal/platform/zhihu"
	"github.com/anynote/backend/internal/repository"
	"github.com/anynote/backend/internal/service"

	redisv9 "github.com/redis/go-redis/v9"
)

func main() {
	// Load config
	cfgPath := "config.yaml"
	if p := os.Getenv("CONFIG_PATH"); p != "" {
		cfgPath = p
	}

	cfg, err := config.Load(cfgPath)
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// Validate critical configuration values
	if err := cfg.Validate(); err != nil {
		slog.Error("invalid configuration", "error", err)
		os.Exit(1)
	}

	// Initialize structured logger
	initLogger(cfg.LogLevel())
	slog.Info("configuration loaded", "log_level", cfg.LogLevel())

	// Connect to PostgreSQL
	pool, err := pgxpool.New(context.Background(), cfg.Database.URL)
	if err != nil {
		slog.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := pool.Ping(context.Background()); err != nil {
		slog.Error("failed to ping database", "error", err)
		os.Exit(1)
	}
	slog.Info("connected to PostgreSQL")

	// Initialize LLM Gateway
	gateway := llm.NewGateway()

	// Initialize rate limiter (50 req/day for free users)
	rateLimiter := service.NewRateLimiter(50, 24*time.Hour)

	// Initialize repositories
	userRepo := repository.NewUserRepository(pool)
	syncBlobRepo := repository.NewSyncBlobRepository(pool)
	quotaRepo := repository.NewQuotaRepository(pool)
	llmConfigRepo := repository.NewLLMConfigRepository(pool)
	platformConnRepo := repository.NewPlatformConnectionRepository(pool)
	publishLogRepo := repository.NewPublishLogRepository(pool)
	sharedNoteRepo := repository.NewSharedNoteRepository(pool)
	deviceTokenRepo := repository.NewDeviceTokenRepository(pool)
	commentRepo := repository.NewCommentRepository(pool)

	// Initialize services
	authSvc := service.NewAuthService(userRepo, cfg.Auth.JWTSecret, cfg.Auth.TokenExpiry, cfg.Auth.RefreshExpiry)
	quotaSvc := service.NewQuotaService(quotaRepo)

	// Initialize push notification service
	pushSvc := service.NewPushService(deviceTokenRepo)

	syncSvc := service.NewSyncService(syncBlobRepo, service.WithPushService(pushSvc))

	defaultLLMCfg := llm.LoadDefaultConfig(cfg)

	masterKey := []byte(cfg.Auth.MasterEncryptionKey)

	aiProxySvc := service.NewAIProxyService(gateway, llmConfigRepo, quotaSvc, rateLimiter, defaultLLMCfg, masterKey)
	llmConfigSvc := service.NewLLMConfigService(llmConfigRepo, gateway, masterKey)
	publishSvc := service.NewPublishService(publishLogRepo, nil, service.WithPublishPushService(pushSvc))

	// Initialize platform adapters and registry
	platformRegistry := platform.NewRegistry()
	xhsAdapter := xiaohongshu.NewAdapter(cfg.Chrome.WSURL)
	platformRegistry.Register(xhsAdapter.Name(), xhsAdapter)
	wcAdapter := wechat.NewAdapter(cfg.Chrome.WSURL)
	platformRegistry.Register(wcAdapter.Name(), wcAdapter)
	zhihuAdapter := zhihu.NewAdapter(cfg.Chrome.WSURL)
	platformRegistry.Register(zhihuAdapter.Name(), zhihuAdapter)
	mediumAdapter := medium.NewAdapter(
		os.Getenv("MEDIUM_CLIENT_ID"),
		os.Getenv("MEDIUM_CLIENT_SECRET"),
		os.Getenv("MEDIUM_REDIRECT_URI"),
	)
	platformRegistry.Register(mediumAdapter.Name(), mediumAdapter)
	wpAdapter := wordpress.NewAdapter()
	platformRegistry.Register(wpAdapter.Name(), wpAdapter)
	webhookAdapter := webhook.NewAdapter()
	platformRegistry.Register(webhookAdapter.Name(), webhookAdapter)
	slog.Info("registered platform adapters", "platforms", platformRegistry.List())

	platformSvc := service.NewPlatformService(platformConnRepo, platformRegistry)
	shareSvc := service.NewShareService(sharedNoteRepo)
	commentSvc := service.NewCommentService(commentRepo)

	// Initialize Redis client for health checks and presence service.
	// If Redis URL is not configured, the health handler gracefully reports
	// redis as "not_configured" rather than failing.
	var redisClient *redisv9.Client
	if cfg.Redis.URL != "" {
		redisClient = redisv9.NewClient(&redisv9.Options{
			Addr: cfg.Redis.URL,
		})
		defer redisClient.Close()
	}

	// Initialize presence service (nil-safe: if Redis is not configured,
	// callers must check readiness before using WebSocket endpoints).
	var presenceSvc service.PresenceService
	if redisClient != nil {
		presenceSvc = service.NewPresenceService(redisClient)
	}

	// Setup router
	services := &handler.Services{
		Auth:      authSvc,
		Sync:      syncSvc,
		AIProxy:   aiProxySvc,
		Quota:     quotaSvc,
		LLMConfig: llmConfigSvc,
		Publish:   publishSvc,
		Platform:  platformSvc,
		Share:     shareSvc,
		Push:      pushSvc,
		Comment:   commentSvc,
		Presence:  presenceSvc,
	}

	// Health handler: pgxpool.Pool implements the Pinger interface used by
	// HealthHandler for the readiness check.
	healthH := handler.NewHealthHandler(pool, redisClient)

	router := handler.Router(cfg, services, healthH)

	// Start server
	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	srv := &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh

		slog.Info("shutting down server")
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := srv.Shutdown(ctx); err != nil {
			slog.Error("server shutdown error", "error", err)
		}
	}()

	slog.Info("server starting", "addr", addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		slog.Error("server error", "error", err)
		os.Exit(1)
	}
	slog.Info("server stopped")
}

// initLogger configures the global slog logger with the given level.
func initLogger(levelStr string) {
	var level slog.Level
	switch levelStr {
	case "debug":
		level = slog.LevelDebug
	case "info":
		level = slog.LevelInfo
	case "warn":
		level = slog.LevelWarn
	case "error":
		level = slog.LevelError
	default:
		level = slog.LevelInfo
	}

	opts := &slog.HandlerOptions{Level: level}
	handler := slog.NewJSONHandler(os.Stdout, opts)
	slog.SetDefault(slog.New(handler))
}
