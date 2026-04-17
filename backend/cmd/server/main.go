package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/handler"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/repository"
	"github.com/anynote/backend/internal/service"
)

func main() {
	// Load config
	cfgPath := "config.yaml"
	if p := os.Getenv("CONFIG_PATH"); p != "" {
		cfgPath = p
	}

	cfg, err := config.Load(cfgPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Connect to PostgreSQL
	pool, err := pgxpool.New(context.Background(), cfg.Database.URL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(context.Background()); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}
	log.Println("Connected to PostgreSQL")

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

	// Initialize services
	authSvc := service.NewAuthService(userRepo, cfg.Auth.JWTSecret, cfg.Auth.TokenExpiry, cfg.Auth.RefreshExpiry)
	syncSvc := service.NewSyncService(syncBlobRepo)
	quotaSvc := service.NewQuotaService(quotaRepo)

	defaultLLMCfg := llm.LoadDefaultConfig(cfg)
	aiProxySvc := service.NewAIProxyService(gateway, llmConfigRepo, quotaSvc, rateLimiter, defaultLLMCfg)

	masterKey := []byte(cfg.Auth.MasterEncryptionKey)
	llmConfigSvc := service.NewLLMConfigService(llmConfigRepo, gateway, masterKey)
	publishSvc := service.NewPublishService(publishLogRepo)
	platformSvc := service.NewPlatformService(platformConnRepo)

	// Setup router
	services := &handler.Services{
		Auth:      authSvc,
		Sync:      syncSvc,
		AIProxy:   aiProxySvc,
		Quota:     quotaSvc,
		LLMConfig: llmConfigSvc,
		Publish:   publishSvc,
		Platform:  platformSvc,
	}

	router := handler.Router(cfg, services)

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

		log.Println("Shutting down server...")
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("Server shutdown error: %v", err)
		}
	}()

	log.Printf("Server starting on %s", addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
	log.Println("Server stopped")
}
