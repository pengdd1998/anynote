package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/anynote/backend/internal/appsetup"
	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/queue"
	"github.com/anynote/backend/internal/repository"
	"github.com/anynote/backend/internal/service"
	"google.golang.org/api/option"
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
	deviceTokenRepo := repository.NewDeviceTokenRepository(pool)

	// Initialize services
	quotaSvc := service.NewQuotaService(quotaRepo)
	defaultLLMCfg := llm.LoadDefaultConfig(cfg)
	masterKey := []byte(cfg.Auth.MasterEncryptionKey)

	// Initialize push notification service.
	// When Firebase credentials are configured, push notifications are delivered
	// via FCM. Otherwise the service operates in log-only mode.
	var fcmClient service.FCMClient
	fcmClient, err = initWorkerFCMClient(context.Background(), cfg.Firebase.CredentialsFile)
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
	qSvc.RegisterHandlers(aiHandler, publishHandler)

	// Start the asynq worker server. Start runs in the background, so we
	// block on the signal channel below.
	slog.Info("worker starting", "queues", []string{"ai", "publish"})
	if err := qSvc.Start(cfg.Redis.URL); err != nil {
		slog.Error("worker start error", "error", err)
		os.Exit(1)
	}

	// Graceful shutdown: listen for SIGINT/SIGTERM, then stop the worker server
	// and close external connections.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigCh

	slog.Info("shutting down worker", "signal", sig)

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

// initWorkerFCMClient initializes the Firebase Cloud Messaging client for the worker.
// Returns nil (no error) when credentialsFile is empty, meaning log-only mode.
func initWorkerFCMClient(ctx context.Context, credentialsFile string) (service.FCMClient, error) {
	if credentialsFile == "" {
		return nil, nil
	}

	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credentialsFile))
	if err != nil {
		return nil, fmt.Errorf("firebase app init: %w", err)
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase messaging client: %w", err)
	}

	return &workerFCMClient{client: client}, nil
}

// workerFCMClient adapts the Firebase messaging.Client to the service.FCMClient interface.
type workerFCMClient struct {
	client *messaging.Client
}

// Send converts the domain FCMMessage to a Firebase messaging.Message and delivers it.
func (f *workerFCMClient) Send(ctx context.Context, msg *service.FCMMessage) (string, error) {
	fbMsg := &messaging.Message{
		Token: msg.Token,
		Notification: &messaging.Notification{
			Title: msg.Title,
			Body:  msg.Body,
		},
		Android: &messaging.AndroidConfig{
			Priority: msg.Priority,
		},
	}

	if len(msg.Data) > 0 {
		fbMsg.Data = msg.Data
	}

	return f.client.Send(ctx, fbMsg)
}
