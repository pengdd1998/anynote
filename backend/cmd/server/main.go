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

	"github.com/anynote/backend/internal/appsetup"
	"github.com/anynote/backend/internal/fcmadapter"
	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/handler"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/repository"
	"github.com/anynote/backend/internal/service"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
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

	// Log warnings for non-critical configuration issues
	cfg.Warn()

	// Initialize structured logger
	initLogger(cfg.LogLevel(), cfg.LogFormat())
	slog.Info("configuration loaded", "log_level", cfg.LogLevel(), "log_format", cfg.LogFormat())

	// Connect to PostgreSQL
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

	if err := pool.Ping(context.Background()); err != nil {
		slog.Error("failed to ping database", "error", err)
		os.Exit(1)
	}
	slog.Info("connected to PostgreSQL")

	// Initialize LLM Gateway
	gateway := llm.NewGateway()

	// Initialize Redis client early so it can be used for rate limiting.
	// If Redis URL is not configured, rate limiting falls back to in-memory.
	var redisClient *redisv9.Client
	if cfg.Redis.URL != "" {
		redisClient = redisv9.NewClient(&redisv9.Options{
			Addr: cfg.Redis.URL,
		})
		defer redisClient.Close()
	}

	// Initialize rate limiter (50 req/day for free users).
	// Prefer Redis-backed limiter for distributed deployments; fall back to
	// in-memory when Redis is unavailable.
	var rateLimiter service.RateLimitProvider
	if redisClient != nil {
		redisRL, rlErr := service.NewRedisRateLimiter(cfg.Redis.URL, 50, 24*time.Hour)
		if rlErr != nil {
			slog.Warn("Redis rate limiter unavailable, falling back to in-memory", "error", rlErr)
			rateLimiter = service.NewRateLimiter(50, 24*time.Hour)
		} else {
			defer redisRL.Close()
			rateLimiter = redisRL
			slog.Info("Redis rate limiter initialized")
		}
	} else {
		rateLimiter = service.NewRateLimiter(50, 24*time.Hour)
		slog.Info("in-memory rate limiter initialized (no Redis configured)")
	}

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
	refreshTokenRepo := repository.NewRefreshTokenRepository(pool)
	planRepo := repository.NewPlanRepository(pool)
	profileRepo := repository.NewProfileRepository(pool)
	noteLinkRepo := repository.NewNoteLinkRepository(pool)
	deviceRepo := repository.NewDeviceRepository(pool)
	collabRepo := repository.NewCollabRepository(pool)
	collabOpsRepo := repository.NewCollabOperationsRepository(pool)
	paymentRepo := repository.NewPaymentRepository(pool)
	notificationRepo := repository.NewNotificationRepository(pool)

	// Start background goroutine to periodically clean up expired shared notes.
	cleanupCtx, cancelCleanup := context.WithCancel(context.Background())
	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()

		var consecutiveErrors int

		// Run once immediately at startup.
		if n, err := sharedNoteRepo.DeleteExpired(cleanupCtx); err != nil {
			slog.Error("shared note cleanup failed", "error", err)
			consecutiveErrors++
		} else {
			consecutiveErrors = 0
			if n > 0 {
				slog.Info("cleaned up expired shared notes", "deleted", n)
			}
		}

		for {
			select {
			case <-ticker.C:
				if consecutiveErrors > 0 {
					backoff := time.Duration(min(consecutiveErrors*consecutiveErrors, 30)) * time.Minute
					slog.Warn("shared note cleanup backing off", "errors", consecutiveErrors, "backoff", backoff)
					time.Sleep(backoff)
					if cleanupCtx.Err() != nil {
						return
					}
				}
				if n, err := sharedNoteRepo.DeleteExpired(cleanupCtx); err != nil {
					slog.Error("shared note cleanup failed", "error", err)
					consecutiveErrors++
				} else {
					consecutiveErrors = 0
					if n > 0 {
						slog.Info("cleaned up expired shared notes", "deleted", n)
					}
				}
			case <-cleanupCtx.Done():
				slog.Info("shared note cleanup goroutine stopped")
				return
			}
		}
	}()

	// Initialize services
	authSvc := service.NewAuthServiceWithDeviceTokens(userRepo, deviceTokenRepo, refreshTokenRepo, cfg.Auth.JWTSecret, cfg.Auth.TokenExpiry, cfg.Auth.RefreshExpiry)
	quotaSvc := service.NewQuotaService(quotaRepo)

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

	syncSvc := service.NewSyncService(syncBlobRepo, service.WithPushService(pushSvc))

	defaultLLMCfg := llm.LoadDefaultConfig(cfg)

	masterKey, err := cfg.Auth.MasterKeyBytes()
	if err != nil {
		slog.Error("invalid master encryption key", "error", err)
		os.Exit(1)
	}

	// Use the fallback constructor when a fallback LLM provider is configured.
	// This enables automatic failover in shared mode when the default provider
	// is unavailable.
	var aiProxySvc service.AIProxyService
	if cfg.LLM.Fallback.Provider != "" && cfg.LLM.Fallback.APIKey != "" {
		fallbackLLMCfg := llm.LoadFallbackConfig(cfg)
		aiProxySvc = service.NewAIProxyServiceWithFallback(gateway, llmConfigRepo, quotaSvc, rateLimiter, defaultLLMCfg, fallbackLLMCfg, masterKey)
		slog.Info("AI proxy configured with fallback LLM", "default", cfg.LLM.Default.Provider, "fallback", cfg.LLM.Fallback.Provider)
	} else {
		aiProxySvc = service.NewAIProxyService(gateway, llmConfigRepo, quotaSvc, rateLimiter, defaultLLMCfg, masterKey)
		slog.Info("AI proxy configured without fallback LLM", "default", cfg.LLM.Default.Provider)
	}
	llmConfigSvc := service.NewLLMConfigService(llmConfigRepo, gateway, masterKey)
	publishSvc := service.NewPublishService(publishLogRepo, nil, service.WithPublishPushService(pushSvc))

	// Initialize platform adapters and registry
	platformRegistry := platform.NewRegistry()
	appsetup.RegisterDefaultAdapters(platformRegistry, cfg.Chrome.WSURL)
	slog.Info("registered platform adapters", "platforms", platformRegistry.List())

	platformSvc := service.NewPlatformService(platformConnRepo, platformRegistry)
	shareSvc := service.NewShareService(sharedNoteRepo)
	commentSvc := service.NewCommentService(commentRepo,
		service.WithCommentPushService(pushSvc),
		service.WithCommentShareRepo(sharedNoteRepo),
	)
	planSvc := service.NewPlanService(planRepo, quotaRepo)
	profileSvc := service.NewProfileService(profileRepo)
	noteLinkSvc := service.NewNoteLinkService(noteLinkRepo)
	aiAgentSvc := service.NewAIAgentService(aiProxySvc)
	collabSvc := service.NewCollabService(collabRepo)

	// Payment service: operates in test mode when Stripe is not configured.
	var stripeClient service.StripeClient // nil = test mode
	paymentSvc := service.NewPaymentService(paymentRepo, planRepo, stripeClient, cfg.Stripe.WebhookSecret)

	// Notification service.
	notificationSvc := service.NewNotificationService(notificationRepo)

	// Initialize presence service (nil-safe: if Redis is not configured,
	// callers must check readiness before using WebSocket endpoints).
	var presenceSvc service.PresenceService
	if redisClient != nil {
		presenceSvc = service.NewPresenceService(redisClient)
	}

	// Initialize MinIO client for health checks.
	// If MinIO endpoint is not configured, the health handler gracefully reports
	// minio as "not_configured" rather than failing.
	var minioChecker handler.BucketChecker
	if cfg.MinIO.Endpoint != "" {
		minioClient, err := minio.New(cfg.MinIO.Endpoint, &minio.Options{
			Creds:  credentials.NewStaticV4(cfg.MinIO.AccessKey, cfg.MinIO.SecretKey, ""),
			Secure: cfg.MinIO.UseSSL,
		})
		if err != nil {
			slog.Warn("MinIO client initialization failed, skipping MinIO health check", "error", err)
		} else {
			minioChecker = &minioBucketChecker{
				client: minioClient,
				bucket: cfg.MinIO.BucketName(),
			}
			slog.Info("MinIO client initialized", "endpoint", cfg.MinIO.Endpoint, "bucket", cfg.MinIO.BucketName())
		}
	}

	// Setup router
	services := &handler.Services{
		Auth:         authSvc,
		Sync:         syncSvc,
		AIProxy:      aiProxySvc,
		Quota:        quotaSvc,
		LLMConfig:    llmConfigSvc,
		Publish:      publishSvc,
		Platform:     platformSvc,
		Share:        shareSvc,
		Push:         pushSvc,
		Comment:      commentSvc,
		Presence:     presenceSvc,
		Plan:         planSvc,
		Profile:      profileSvc,
		NoteLink:     noteLinkSvc,
		AIAgent:      aiAgentSvc,
		Collab:       collabSvc,
		Payment:      paymentSvc,
		Notification: notificationSvc,
		DeviceRepo:    deviceRepo,
		CollabRepo:    collabRepo,
		CollabOpsRepo: collabOpsRepo,
	}

	// Health handler: pgxpool.Pool implements the Pinger interface used by
	// HealthHandler for the readiness check.
	healthH := handler.NewHealthHandler(pool, redisClient, minioChecker)

	router := handler.Router(cfg, services, healthH)

	// Start server
	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	srv := &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// Graceful shutdown: listen for SIGINT/SIGTERM, then drain HTTP requests
	// with a 10-second timeout, stop background goroutines, and close the
	// database pool.
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		sig := <-sigCh

		slog.Info("shutting down server", "signal", sig)
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := srv.Shutdown(ctx); err != nil {
			slog.Error("server shutdown error", "error", err)
		}

		// Stop background goroutines.
		platformSvc.Stop()
		cancelCleanup()

		slog.Info("closing database pool")
		pool.Close()

		slog.Info("server stopped")
	}()

	slog.Info("server starting", "addr", addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		slog.Error("server error", "error", err)
		os.Exit(1)
	}
}

// initLogger configures the global slog logger with the given level and format.
// format "text" produces human-readable output; any other value (including the
// default "json") produces structured JSON logs suitable for production.
func initLogger(levelStr, format string) {
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

	var handler slog.Handler
	if format == "text" {
		handler = slog.NewTextHandler(os.Stdout, opts)
	} else {
		handler = slog.NewJSONHandler(os.Stdout, opts)
	}
	slog.SetDefault(slog.New(handler))
}

// minioBucketChecker adapts the minio.Client to the handler.BucketChecker interface.
// It verifies MinIO connectivity by checking that the configured bucket exists.
type minioBucketChecker struct {
	client *minio.Client
	bucket string
}

// HealthCheck verifies the MinIO bucket is accessible.
func (m *minioBucketChecker) HealthCheck(ctx context.Context) error {
	exists, err := m.client.BucketExists(ctx, m.bucket)
	if err != nil {
		return fmt.Errorf("minio bucket check: %w", err)
	}
	if !exists {
		return fmt.Errorf("minio bucket %q does not exist", m.bucket)
	}
	return nil
}
