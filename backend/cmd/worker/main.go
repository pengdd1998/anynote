package main

import (
	"context"
	"log/slog"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/platform/medium"
	"github.com/anynote/backend/internal/platform/webhook"
	"github.com/anynote/backend/internal/platform/wechat"
	"github.com/anynote/backend/internal/platform/wordpress"
	"github.com/anynote/backend/internal/platform/xiaohongshu"
	"github.com/anynote/backend/internal/platform/zhihu"
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

	// Initialize structured logger
	initWorkerLogger(cfg.LogLevel())

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

	// Initialize services
	quotaSvc := service.NewQuotaService(quotaRepo)
	defaultLLMCfg := llm.LoadDefaultConfig(cfg)
	masterKey := []byte(cfg.Auth.MasterEncryptionKey)

	// Initialize platform adapters and registry
	registry := platform.NewRegistry()
	xhsAdapter := xiaohongshu.NewAdapter(cfg.Chrome.WSURL)
	registry.Register(xhsAdapter.Name(), xhsAdapter)
	wcAdapter := wechat.NewAdapter(cfg.Chrome.WSURL)
	registry.Register(wcAdapter.Name(), wcAdapter)
	zhihuAdapter := zhihu.NewAdapter(cfg.Chrome.WSURL)
	registry.Register(zhihuAdapter.Name(), zhihuAdapter)
	mediumAdapter := medium.NewAdapter(
		os.Getenv("MEDIUM_CLIENT_ID"),
		os.Getenv("MEDIUM_CLIENT_SECRET"),
		os.Getenv("MEDIUM_REDIRECT_URI"),
	)
	registry.Register(mediumAdapter.Name(), mediumAdapter)
	wpAdapter := wordpress.NewAdapter()
	registry.Register(wpAdapter.Name(), wpAdapter)
	webhookAdapter := webhook.NewAdapter()
	registry.Register(webhookAdapter.Name(), webhookAdapter)
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
	)

	// Register real handlers (replaces stubs)
	qSvc.RegisterHandlers(aiHandler, publishHandler)

	slog.Info("worker starting", "queues", []string{"ai", "publish"})
	if err := qSvc.Run(cfg.Redis.URL); err != nil {
		slog.Error("worker error", "error", err)
		os.Exit(1)
	}
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
