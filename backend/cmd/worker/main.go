package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/hibiken/asynq"
	"github.com/redis/go-redis/v9"

	"github.com/anynote/backend/internal/appsetup"
	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/fcmadapter"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/queue"
	"github.com/anynote/backend/internal/repository"
	"github.com/anynote/backend/internal/service"
)

func main() {
	cfgPath := "config.yaml"
	if p := os.Getenv("CONFIG_PATH"); p != "" {
		cfgPath = p
	}

	cfg, err := config.Load(cfgPath)
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// Validate critical configuration values.
	if err := cfg.Validate(); err != nil {
		slog.Error("invalid configuration", "error", err)
		os.Exit(1)
	}

	// Initialize structured logger
	initWorkerLogger(cfg.LogLevel())

	// Connect to PostgreSQL with pool configuration.
	poolConfig, err := pgxpool.ParseConfig(cfg.Database.URL)
	if err != nil {
		slog.Error("failed to parse database config", "error", err)
		os.Exit(1)
	}
	if cfg.Database.MaxOpenConns > 0 {
		poolConfig.MaxConns = int32(cfg.Database.MaxOpenConns)
	}
	if cfg.Database.MaxIdleConns > 0 {
		poolConfig.MinConns = int32(cfg.Database.MaxIdleConns)
	}
	if cfg.Database.ConnMaxLifetime > 0 {
		poolConfig.MaxConnLifetime = cfg.Database.ConnMaxLifetime
	}
	pool, err := pgxpool.NewWithConfig(context.Background(), poolConfig)
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

	// Connect to Redis (for AI result storage)
	rdb := redis.NewClient(&redis.Options{
		Addr: cfg.Redis.URL,
	})
	defer rdb.Close()

	if err := rdb.Ping(context.Background()).Err(); err != nil {
		slog.Error("failed to connect to redis", "error", err)
		os.Exit(1)
	}
	slog.Info("connected to Redis")

	// Initialize LLM Gateway
	gateway := llm.NewGateway()

	// Initialize rate limiter (must match server configuration)
	rateLimiter := service.NewRateLimiter(50, 24*time.Hour)

	// Initialize repositories
	llmConfigRepo := repository.NewLLMConfigRepository(pool)
	quotaRepo := repository.NewQuotaRepository(pool)
	publishLogRepo := repository.NewPublishLogRepository(pool)
	platformConnRepo := repository.NewPlatformConnectionRepository(pool)
	deviceTokenRepo := repository.NewDeviceTokenRepository(pool)
	syncBlobRepo := repository.NewSyncBlobRepository(pool)
	sharedNoteRepo := repository.NewSharedNoteRepository(pool)

	// Initialize services
	quotaSvc := service.NewQuotaService(quotaRepo)
	defaultLLMCfg := llm.LoadDefaultConfig(cfg)
	masterKey, err := cfg.Auth.MasterKeyBytes()
	if err != nil {
		slog.Error("invalid master encryption key", "error", err)
		os.Exit(1)
	}

	// Initialize push notification service.
	// When Firebase credentials are configured, push notifications are delivered
	// via FCM. Otherwise the service operates in log-only mode.
	var fcmClient service.FCMClient
	fcmClient, err = fcmadapter.InitFCMClient(context.Background(), cfg.Firebase.CredentialsFile)
	if err != nil {
		slog.Warn("FCM client initialization failed, falling back to log-only push", "error", err)
		fcmClient = nil
	} else if fcmClient != nil {
		slog.Info("FCM client initialized, push notifications enabled")
	}
	pushSvc := service.NewPushService(deviceTokenRepo, fcmClient)

	// Initialize platform adapters and registry
	registry := platform.NewRegistry()
	appsetup.RegisterDefaultAdapters(registry, cfg.Chrome.WSURL)
	slog.Info("registered platform adapters", "platforms", registry.List())

	// Initialize queue service
	qSvc := queue.New(cfg.Redis.URL)
	defer qSvc.Shutdown()

	// Create handler instances with full dependency injection
	aiHandler := queue.NewAIJobHandler(
		gateway,
		llmConfigRepo,
		quotaSvc,
		rateLimiter,
		rdb,
		defaultLLMCfg,
		masterKey,
	)

	publishHandler := queue.NewPublishJobHandler(
		registry,
		publishLogRepo,
		platformConnRepo,
		masterKey,
		pushSvc,
	)

	// Register real handlers (replaces stubs)
	pushHandler := queue.NewPushJobHandler(pushSvc)
	qSvc.RegisterHandlers(aiHandler, publishHandler, pushHandler)

	// Register cleanup handler for expired shared notes.
	cleanupHandler := queue.NewCleanupHandler(sharedNoteRepo)
	qSvc.HandleFunc(queue.TaskCleanupExpiredShares, cleanupHandler.HandleCleanupExpiredShares)

	// Start the asynq worker server. Start runs in the background, so we
	// block on the signal channel below.
	slog.Info("worker starting", "queues", []string{"ai", "publish", "push"})
	if err := qSvc.Start(cfg.Redis.URL); err != nil {
		slog.Error("worker start error", "error", err)
		os.Exit(1)
	}

	// Start periodic cleanup of old sync operation logs (default 30-day retention).
	cleanupCtx, cancelCleanup := context.WithCancel(context.Background())
	go func() {
		ticker := time.NewTicker(24 * time.Hour)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				n, err := syncBlobRepo.CleanOldOperationLogs(cleanupCtx, 30)
				if err != nil {
					slog.Error("operation log cleanup failed", "error", err)
				} else if n > 0 {
					slog.Info("cleaned up old operation logs", "deleted", n)
				}
			case <-cleanupCtx.Done():
				return
			}
		}
	}()

	// Schedule periodic expired shared notes cleanup via asynq (hourly).
	go func() {
		scheduler := asynq.NewScheduler(
			asynq.RedisClientOpt{Addr: cfg.Redis.URL},
			&asynq.SchedulerOpts{},
		)
		_, schedErr := scheduler.Register("@hourly", asynq.NewTask(queue.TaskCleanupExpiredShares, nil))
		if schedErr != nil {
			slog.Error("failed to register expired shares cleanup schedule", "error", schedErr)
		}
		if schedErr := scheduler.Run(); schedErr != nil {
			slog.Error("shared notes cleanup scheduler stopped", "error", schedErr)
		}
	}()

	// Graceful shutdown: listen for SIGINT/SIGTERM, then stop the worker server
	// and close external connections.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigCh

	slog.Info("shutting down worker", "signal", sig)

	// Stop background cleanup goroutine.
	cancelCleanup()

	// Give in-progress tasks up to 5 seconds to complete.
	done := make(chan struct{})
	go func() {
		qSvc.Stop()
		close(done)
	}()

	select {
	case <-done:
		slog.Info("worker server stopped gracefully")
	case <-time.After(5 * time.Second):
		slog.Warn("worker shutdown timed out, forcing stop")
		qSvc.Stop()
	}

	slog.Info("closing Redis client")
	rdb.Close()

	slog.Info("closing database pool")
	pool.Close()

	slog.Info("closing queue client")
	qSvc.Shutdown()

	slog.Info("worker stopped")
}

// initWorkerLogger configures the global slog logger with the given level.
func initWorkerLogger(levelStr string) {
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
