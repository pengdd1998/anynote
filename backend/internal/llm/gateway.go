package llm

import (
	"context"
	"fmt"

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

	compat := &OpenAICompatProvider{}
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

	return provider.Chat(ctx, cfg.APIKey, cfg.BaseURL, req)
}

// GatewayConfig holds LLM provider configuration.
type GatewayConfig struct {
	Provider    string
	BaseURL     string
	APIKey      string
	Model       string
	MaxTokens   int
	Temperature float32
	Timeout     int64 // nanoseconds
}

// ChatRequest is the request payload for LLM chat.
type ChatRequest struct {
	Model       string               `json:"model"`
	Messages    []domain.ChatMessage `json:"messages"`
	Temperature *float32             `json:"temperature,omitempty"`
	MaxTokens   *int                 `json:"max_tokens,omitempty"`
	Stream      bool                 `json:"stream"`
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
