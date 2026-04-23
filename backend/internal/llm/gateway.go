package llm

import (
	"context"
	"fmt"
	"time"

	"github.com/anynote/backend/internal/domain"
)

// Gateway routes chat requests to the appropriate LLM provider.
// Each provider has its own CircuitBreaker that tracks failures and trips
// open when the failure threshold is exceeded, preventing cascading failures.
type Gateway struct {
	providers       map[string]Provider
	circuitBreakers map[string]*CircuitBreaker
}

// gatewayCircuitBreakerOpts are the default options applied to every
// per-provider circuit breaker created by the gateway. These can be
// overridden per-provider via SetCircuitBreaker.
var gatewayCircuitBreakerOpts = []CircuitBreakerOption{
	WithFailureThreshold(5),
	WithSuccessThreshold(3),
	WithOpenTimeout(30 * time.Second),
	WithHalfOpenMaxRequests(1),
}

func NewGateway() *Gateway {
	// Register OpenAI-compatible provider (covers 90%+ of providers)
	gw := &Gateway{
		providers:       make(map[string]Provider),
		circuitBreakers: make(map[string]*CircuitBreaker),
	}

	compat := NewOpenAICompatProvider(nil)
	for _, name := range []string{"openai", "deepseek", "qwen", "anthropic", "custom"} {
		gw.Register(name, compat)
	}

	return gw
}

func (g *Gateway) Register(name string, p Provider) {
	g.providers[name] = p

	// Create a circuit breaker for this provider with the default options.
	providerName := name // capture for closure
	opts := append(
		gatewayCircuitBreakerOpts[:len(gatewayCircuitBreakerOpts):len(gatewayCircuitBreakerOpts)],
		WithOnStateChange(func(from, to State) {
			setCircuitBreakerMetric(providerName, to)
		}),
	)
	g.circuitBreakers[name] = NewCircuitBreaker(opts...)
}

// SetCircuitBreaker replaces the circuit breaker for a specific provider.
// This is primarily useful for tests that need custom thresholds or timeouts.
func (g *Gateway) SetCircuitBreaker(provider string, cb *CircuitBreaker) {
	g.circuitBreakers[provider] = cb
}

// CircuitBreakerState returns the current circuit breaker state for a provider.
// Returns StateClosed if the provider has no circuit breaker.
func (g *Gateway) CircuitBreakerState(provider string) State {
	if cb, ok := g.circuitBreakers[provider]; ok {
		return cb.State()
	}
	return StateClosed
}

// ChatStream sends a streaming chat request to the configured provider.
// The per-provider circuit breaker is checked before dispatching; if the
// circuit is open, the request is rejected immediately with ErrCircuitOpen.
func (g *Gateway) ChatStream(ctx context.Context, cfg GatewayConfig, req ChatRequest) (<-chan domain.StreamChunk, error) {
	provider, ok := g.providers[cfg.Provider]
	if !ok {
		return nil, fmt.Errorf("unsupported provider: %s", cfg.Provider)
	}

	// Check circuit breaker before dispatching.
	if cb, ok := g.circuitBreakers[cfg.Provider]; ok {
		if err := cb.Allow(); err != nil {
			return nil, fmt.Errorf("provider %s: %w", cfg.Provider, err)
		}
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

	ch, err := provider.ChatStream(ctx, cfg.APIKey, cfg.BaseURL, req)
	if err != nil {
		g.recordFailure(cfg.Provider)
	}
	// Note: streaming success is not recorded here because the stream may
	// still fail during reading. Only non-streaming Chat records success.
	return ch, err
}

// Chat sends a non-streaming chat request.
// The per-provider circuit breaker is checked before dispatching; if the
// circuit is open, the request is rejected immediately with ErrCircuitOpen.
func (g *Gateway) Chat(ctx context.Context, cfg GatewayConfig, req ChatRequest) (*ChatResponse, error) {
	provider, ok := g.providers[cfg.Provider]
	if !ok {
		return nil, fmt.Errorf("unsupported provider: %s", cfg.Provider)
	}

	// Check circuit breaker before dispatching.
	if cb, ok := g.circuitBreakers[cfg.Provider]; ok {
		if err := cb.Allow(); err != nil {
			return nil, fmt.Errorf("provider %s: %w", cfg.Provider, err)
		}
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

	resp, err := provider.Chat(ctx, cfg.APIKey, cfg.BaseURL, req)
	if err != nil {
		g.recordFailure(cfg.Provider)
	} else {
		g.recordSuccess(cfg.Provider)
	}
	return resp, err
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

// recordSuccess notifies the circuit breaker for the given provider of a
// successful request.
func (g *Gateway) recordSuccess(provider string) {
	if cb, ok := g.circuitBreakers[provider]; ok {
		cb.RecordSuccess()
	}
}

// recordFailure notifies the circuit breaker for the given provider of a
// failed request.
func (g *Gateway) recordFailure(provider string) {
	if cb, ok := g.circuitBreakers[provider]; ok {
		cb.RecordFailure()
	}
}
