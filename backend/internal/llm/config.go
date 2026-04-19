package llm

import (
	"time"

	"github.com/anynote/backend/internal/config"
)

// LoadDefaultConfig creates a GatewayConfig from the server's default LLM configuration.
func LoadDefaultConfig(cfg *config.Config) GatewayConfig {
	return GatewayConfig{
		Provider:       cfg.LLM.Default.Provider,
		BaseURL:        cfg.LLM.Default.BaseURL,
		APIKey:         cfg.LLM.Default.APIKey,
		Model:          cfg.LLM.Default.Model,
		MaxTokens:      4096,
		Temperature:    0.7,
		Timeout:        int64(cfg.LLM.Default.Timeout),
		MaxRetries:     3,
		RetryBaseDelay: 1 * time.Second,
	}
}

// LoadFallbackConfig creates a GatewayConfig from the server's fallback LLM configuration.
func LoadFallbackConfig(cfg *config.Config) GatewayConfig {
	return GatewayConfig{
		Provider:       cfg.LLM.Fallback.Provider,
		BaseURL:        cfg.LLM.Fallback.BaseURL,
		APIKey:         cfg.LLM.Fallback.APIKey,
		Model:          cfg.LLM.Fallback.Model,
		MaxTokens:      4096,
		Temperature:    0.7,
		Timeout:        int64(cfg.LLM.Fallback.Timeout),
		MaxRetries:     3,
		RetryBaseDelay: 1 * time.Second,
	}
}
