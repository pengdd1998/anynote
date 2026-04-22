package llm

import (
	"testing"
	"time"

	"github.com/anynote/backend/internal/config"
)

// ---------------------------------------------------------------------------
// Tests: LoadDefaultConfig
// ---------------------------------------------------------------------------

func TestLoadDefaultConfig(t *testing.T) {
	cfg := &config.Config{
		LLM: config.LLMConfig{
			Default: config.LLMProviderConfig{
				Provider: "deepseek",
				BaseURL:  "https://api.deepseek.com",
				APIKey:   "sk-test-key",
				Model:    "deepseek-chat",
				Timeout:  30 * time.Second,
			},
		},
	}

	gwCfg := LoadDefaultConfig(cfg)
	if gwCfg.Provider != "deepseek" {
		t.Errorf("Provider = %q, want %q", gwCfg.Provider, "deepseek")
	}
	if gwCfg.BaseURL != "https://api.deepseek.com" {
		t.Errorf("BaseURL = %q, want %q", gwCfg.BaseURL, "https://api.deepseek.com")
	}
	if gwCfg.APIKey != "sk-test-key" {
		t.Errorf("APIKey = %q, want %q", gwCfg.APIKey, "sk-test-key")
	}
	if gwCfg.Model != "deepseek-chat" {
		t.Errorf("Model = %q, want %q", gwCfg.Model, "deepseek-chat")
	}
	if gwCfg.MaxTokens != 4096 {
		t.Errorf("MaxTokens = %d, want 4096", gwCfg.MaxTokens)
	}
	if gwCfg.Temperature != 0.7 {
		t.Errorf("Temperature = %f, want 0.7", gwCfg.Temperature)
	}
	if gwCfg.MaxRetries != 3 {
		t.Errorf("MaxRetries = %d, want 3", gwCfg.MaxRetries)
	}
	if gwCfg.RetryBaseDelay != 1*time.Second {
		t.Errorf("RetryBaseDelay = %v, want 1s", gwCfg.RetryBaseDelay)
	}
}

func TestLoadDefaultConfig_EmptyValues(t *testing.T) {
	cfg := &config.Config{}

	gwCfg := LoadDefaultConfig(cfg)
	if gwCfg.Provider != "" {
		t.Errorf("Provider = %q, want empty", gwCfg.Provider)
	}
	if gwCfg.MaxTokens != 4096 {
		t.Errorf("MaxTokens = %d, want 4096 (hardcoded default)", gwCfg.MaxTokens)
	}
}

// ---------------------------------------------------------------------------
// Tests: LoadFallbackConfig
// ---------------------------------------------------------------------------

func TestLoadFallbackConfig(t *testing.T) {
	cfg := &config.Config{
		LLM: config.LLMConfig{
			Fallback: config.LLMProviderConfig{
				Provider: "qwen",
				BaseURL:  "https://dashscope.aliyuncs.com",
				APIKey:   "fb-key",
				Model:    "qwen-plus",
				Timeout:  60 * time.Second,
			},
		},
	}

	gwCfg := LoadFallbackConfig(cfg)
	if gwCfg.Provider != "qwen" {
		t.Errorf("Provider = %q, want %q", gwCfg.Provider, "qwen")
	}
	if gwCfg.BaseURL != "https://dashscope.aliyuncs.com" {
		t.Errorf("BaseURL = %q, want %q", gwCfg.BaseURL, "https://dashscope.aliyuncs.com")
	}
	if gwCfg.APIKey != "fb-key" {
		t.Errorf("APIKey = %q, want %q", gwCfg.APIKey, "fb-key")
	}
	if gwCfg.Model != "qwen-plus" {
		t.Errorf("Model = %q, want %q", gwCfg.Model, "qwen-plus")
	}
	if gwCfg.MaxTokens != 4096 {
		t.Errorf("MaxTokens = %d, want 4096", gwCfg.MaxTokens)
	}
}

func TestLoadFallbackConfig_EmptyValues(t *testing.T) {
	cfg := &config.Config{}

	gwCfg := LoadFallbackConfig(cfg)
	if gwCfg.Provider != "" {
		t.Errorf("Provider = %q, want empty", gwCfg.Provider)
	}
}

// ---------------------------------------------------------------------------
// Tests: OpenAICompatProvider.Name
// ---------------------------------------------------------------------------

func TestOpenAICompatProvider_Name(t *testing.T) {
	p := NewOpenAICompatProvider(nil)
	if p.Name() != "openai_compat" {
		t.Errorf("Name() = %q, want %q", p.Name(), "openai_compat")
	}
}
