//go:build integration

package handler

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/repository"
	"github.com/anynote/backend/internal/service"
	"github.com/anynote/backend/internal/testutil"
)

// ---------------------------------------------------------------------------
// Full-stack integration test server
// ---------------------------------------------------------------------------
// This file provides setupFullServer which wires all repositories, services,
// and handlers together using the production Router function. It reuses the
// shared testcontainers pool from e2e_sync_integration_test.go.
// ---------------------------------------------------------------------------

// fullTestServer holds all components needed for full-stack integration testing.
type fullTestServer struct {
	Pool   *pgxpool.Pool
	UserID uuid.UUID
	Token  string
	Router http.Handler
	Server *httptest.Server
}

// testMasterKeyHex is a 64-character hex string that decodes to exactly 32
// bytes, suitable for the AES-256 master encryption key in tests.
const testMasterKeyHex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

// setupFullServer creates a complete test server with all 13 repositories,
// 15 services, and the production Router wired together. It reuses the
// shared testcontainers PostgreSQL pool and cleans all tables before seeding
// a fresh test user.
func setupFullServer(t *testing.T) *fullTestServer {
	t.Helper()

	pool := ensureHandlerPool(t)

	// Clean all tables to ensure a fresh state.
	cleanAllTables(t, pool)

	// Build config for the router.
	cfg := &config.Config{
		Server: config.ServerConfig{
			Port:         8080,
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 120 * time.Second,
			AllowOrigins: []string{},
		},
		Database: config.DatabaseConfig{
			URL: "integration-test", // not used at runtime; pool is injected
		},
		Auth: config.AuthConfig{
			JWTSecret:           testJWTSecret,
			TokenExpiry:         1 * time.Hour,
			RefreshExpiry:       30 * 24 * time.Hour,
			MasterEncryptionKey: testMasterKeyHex,
		},
		LLM: config.LLMConfig{
			Default: config.LLMProviderConfig{
				MaxConcurrent: 50,
				Timeout:       120 * time.Second,
			},
			Fallback: config.LLMProviderConfig{
				MaxConcurrent: 25,
				Timeout:       120 * time.Second,
			},
		},
	}

	masterKey, err := cfg.Auth.MasterKeyBytes()
	if err != nil {
		t.Fatalf("failed to derive master key: %v", err)
	}

	// -- Repositories (all 13) --
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

	// -- Services (all 15) --

	gateway := llm.NewGateway()

	rateLimiter := service.NewRateLimiter(50, 24*time.Hour)

	authSvc := service.NewAuthServiceWithDeviceTokens(
		userRepo, deviceTokenRepo, refreshTokenRepo,
		cfg.Auth.JWTSecret, cfg.Auth.TokenExpiry, cfg.Auth.RefreshExpiry,
	)
	quotaSvc := service.NewQuotaService(quotaRepo)
	pushSvc := service.NewPushService(deviceTokenRepo, nil) // nil FCM = log-only
	syncSvc := service.NewSyncService(syncBlobRepo, service.WithPushService(pushSvc))

	defaultLLMCfg := llm.LoadDefaultConfig(cfg)
	aiProxySvc := service.NewAIProxyService(gateway, llmConfigRepo, quotaSvc, rateLimiter, defaultLLMCfg, masterKey)
	llmConfigSvc := service.NewLLMConfigService(llmConfigRepo, gateway, masterKey)
	publishSvc := service.NewPublishService(publishLogRepo, nil, service.WithPublishPushService(pushSvc))

	platformRegistry := platform.NewRegistry() // empty; no adapters needed for tests
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

	// PresenceService requires Redis; nil is safe (handlers check readiness).
	var presenceSvc service.PresenceService

	// -- Wire handler.Services --
	services := &Services{
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
		Plan:      planSvc,
		Profile:   profileSvc,
		NoteLink:  noteLinkSvc,
		AIAgent:   aiAgentSvc,
	}

	// -- Build the production Router --
	healthH := NewHealthHandler(pool, nil, nil)
	router := Router(cfg, services, healthH)

	// -- Seed test user --
	userID := seedTestUser(t, pool)

	// -- Generate JWT token for the seeded user --
	token := generateTestToken(userID.String())

	// -- Create httptest.Server --
	server := httptest.NewServer(router)

	return &fullTestServer{
		Pool:   pool,
		UserID: userID,
		Token:  token,
		Router: router,
		Server: server,
	}
}

// cleanAllTables truncates all application tables in correct dependency order.
// Child tables are truncated first to respect foreign key constraints, with
// the users table last.
func cleanAllTables(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	tables := []string{
		"note_comments",
		"note_reactions",
		"note_links",
		"shared_notes",
		"publish_logs",
		"platform_connections",
		"llm_configs",
		"device_tokens",
		"refresh_tokens",
		"sync_operation_logs",
		"sync_blobs",
		"user_quotas",
		"users",
	}
	testutil.CleanTable(t, pool, tables...)
}
