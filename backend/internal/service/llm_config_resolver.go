package service

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/llm"
)

// UserLLMConfig resolves the user's active LLM configuration.
// If the user has an active config with a valid (decryptable) API key, it returns
// a dedicated GatewayConfig. Otherwise it returns nil, indicating shared mode should
// be used with the provided defaultCfg.
func UserLLMConfig(
	ctx context.Context,
	userID uuid.UUID,
	llmRepo LLMConfigRepository,
	encryptionKey []byte,
) (*llm.GatewayConfig, error) {
	userCfg, err := llmRepo.GetDefaultByUser(ctx, userID)
	if err != nil || userCfg == nil {
		return nil, nil // No user config: fall back to shared mode.
	}

	decryptedKey, decErr := llm.DecryptAPIKey(userCfg.EncryptedKey, encryptionKey)
	if decErr != nil {
		slog.Warn("failed to decrypt user llm key, falling back to shared mode", "user_id", userID, "error", decErr)
		return nil, nil
	}

	cfg := &llm.GatewayConfig{
		Provider:    userCfg.Provider,
		BaseURL:     userCfg.BaseURL,
		APIKey:      decryptedKey,
		Model:       userCfg.Model,
		MaxTokens:   userCfg.MaxTokens,
		Temperature: userCfg.Temperature,
		Timeout:     120 * 1e9, // 120s in nanoseconds
	}

	return cfg, nil
}

// ResolveChatModel returns the model to use for the chat request, falling back
// to the gateway config's default model when the request does not specify one.
func ResolveChatModel(reqModel string, cfg llm.GatewayConfig) string {
	if reqModel != "" {
		return reqModel
	}
	return cfg.Model
}

// CheckSharedModeQuota enforces rate limiting and quota tracking for shared-mode
// LLM usage. Returns an error if the user has exceeded their quota.
func CheckSharedModeQuota(
	ctx context.Context,
	userID uuid.UUID,
	userIDStr string,
	rateLimiter RateLimitProvider,
	quotaSvc QuotaService,
) error {
	if !rateLimiter.Allow(userIDStr) {
		return fmt.Errorf("quota exceeded")
	}

	if err := quotaSvc.IncrementUsage(ctx, userID); err != nil {
		slog.Error("failed to increment AI usage", "user_id", userIDStr, "error", err)
	}

	return nil
}
