package llm

import (
	"context"
	"fmt"
	"time"

	"github.com/anynote/backend/internal/domain"
)

// Gateway routes chat requests to the appropriate LLM provider.
type Gateway struct {
	providers map[string]Provider
}

func NewGateway() *Gateway {
	// Register OpenAI-compatible provider (covers 90%+ of providers)
	gw := &Gateway{
		providers: make(map[string]Provider),
	}

	compat := NewOpenAICompatProvider(nil)
	for _, name := range []string{"openai", "deepseek", "qwen", "anthropic", "custom"} {
		gw.Register(name, compat)
	}

	return gw
}

func (g *Gateway) Register(name string, p Provider) {
	g.providers[name] = p
}

// ChatStream sends a streaming chat request to the configured provider.
func (g *Gateway) ChatStream(ctx context.Context, cfg GatewayConfig, req ChatRequest) (<-chan domain.StreamChunk, error) {
	provider, ok := g.providers[cfg.Provider]
	if !ok {
		return nil, fmt.Errorf("unsupported provider: %s", cfg.Provider)
	}

	// Apply config defaults to request
	if req.Model == "" {
		req.Model = cfg.Model
	}
	if req.Temperature == nil {
		req.Temperature = &cfg.Temperature
	}
	if req.MaxTokens == nil {
		req.MaxTokens = &cfg.MaxTokens
	}
	req.Stream = true

	return provider.ChatStream(ctx, cfg.APIKey, cfg.BaseURL, req)
}

// Chat sends a non-streaming chat request.
func (g *Gateway) Chat(ctx context.Context, cfg GatewayConfig, req ChatRequest) (*ChatResponse, error) {
	provider, ok := g.providers[cfg.Provider]
	if !ok {
		return nil, fmt.Errorf("unsupported provider: %s", cfg.Provider)
	}

	if req.Model == "" {
		req.Model = cfg.Model
	}
	req.Stream = false

	// Propagate retry configuration from gateway config to request so
	// the provider can use it.  Defaults are applied when either field is
	// zero-valued.
	if req.MaxRetries == 0 {
		req.MaxRetries = cfg.MaxRetries
	}
	if req.RetryBaseDelay == 0 {
		req.RetryBaseDelay = cfg.RetryBaseDelay
	}
	if req.MaxRetries == 0 {
		req.MaxRetries = 3
	}
	if req.RetryBaseDelay == 0 {
		req.RetryBaseDelay = 1 * time.Second
	}

	return provider.Chat(ctx, cfg.APIKey, cfg.BaseURL, req)
}

// GatewayConfig holds LLM provider configuration.
type GatewayConfig struct {
	Provider        string
	BaseURL         string
	APIKey          string
	Model           string
	MaxTokens       int
	Temperature     float32
	Timeout         int64 // nanoseconds
	MaxRetries      int           // maximum retry attempts (default 3)
	RetryBaseDelay  time.Duration // base delay for exponential backoff (default 1s)
}

// ChatRequest is the request payload for LLM chat.
type ChatRequest struct {
	Model       string               `json:"model"`
	Messages    []domain.ChatMessage `json:"messages"`
	Temperature *float32             `json:"temperature,omitempty"`
	MaxTokens   *int                 `json:"max_tokens,omitempty"`
	Stream      bool                 `json:"stream"`

	// Retry configuration (not sent to provider; used internally by retry logic)
	MaxRetries     int           `json:"-"`
	RetryBaseDelay time.Duration `json:"-"`
}

// ChatResponse is the non-streaming response from LLM.
type ChatResponse struct {
	Content string `json:"content"`
	Model   string `json:"model"`
	Usage   Usage  `json:"usage,omitempty"`
}

// Usage tracks token usage.
type Usage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}
