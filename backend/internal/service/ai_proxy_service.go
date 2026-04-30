package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/llm"
)

var ErrQuotaExceeded = errors.New("quota exceeded")

type AIProxyService interface {
	Proxy(ctx context.Context, userID string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error)
}

type LLMConfigRepository interface {
	GetDefaultByUser(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error)
}

type aiProxyService struct {
	gateway       *llm.Gateway
	llmRepo       LLMConfigRepository
	quotaSvc      QuotaService
	rateLimiter   RateLimitProvider
	defaultCfg    llm.GatewayConfig
	fallbackCfg   *llm.GatewayConfig // nil means no fallback configured
	encryptionKey []byte
}

func NewAIProxyService(
	gateway *llm.Gateway,
	llmRepo LLMConfigRepository,
	quotaSvc QuotaService,
	rateLimiter RateLimitProvider,
	defaultCfg llm.GatewayConfig,
	encryptionKey []byte,
) AIProxyService {
	return &aiProxyService{
		gateway:       gateway,
		llmRepo:       llmRepo,
		quotaSvc:      quotaSvc,
		rateLimiter:   rateLimiter,
		defaultCfg:    defaultCfg,
		encryptionKey: encryptionKey,
	}
}

// NewAIProxyServiceWithFallback creates an AIProxyService with a fallback LLM
// config. The fallback is only used in shared mode (no user-owned config) when
// the default gateway returns an error.
func NewAIProxyServiceWithFallback(
	gateway *llm.Gateway,
	llmRepo LLMConfigRepository,
	quotaSvc QuotaService,
	rateLimiter RateLimitProvider,
	defaultCfg llm.GatewayConfig,
	fallbackCfg llm.GatewayConfig,
	encryptionKey []byte,
) AIProxyService {
	return &aiProxyService{
		gateway:       gateway,
		llmRepo:       llmRepo,
		quotaSvc:      quotaSvc,
		rateLimiter:   rateLimiter,
		defaultCfg:    defaultCfg,
		fallbackCfg:   &fallbackCfg,
		encryptionKey: encryptionKey,
	}
}

func (s *aiProxyService) Proxy(ctx context.Context, userID string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
	uid, _ := uuid.Parse(userID)

	// 1. Check if user has custom LLM configuration.
	dedicatedCfg, err := UserLLMConfig(ctx, uid, s.llmRepo, s.encryptionKey)
	if err != nil {
		return nil, fmt.Errorf("resolve user llm config: %w", err)
	}
	if dedicatedCfg != nil {
		// Dedicated mode: use user's own API key.
		chatReq := s.toChatRequest(req, *dedicatedCfg)
		return s.gateway.ChatStream(ctx, *dedicatedCfg, chatReq)
	}

	// 2. Shared mode: check rate limit and quota.
	if err := CheckSharedModeQuota(ctx, uid, userID, s.rateLimiter, s.quotaSvc); err != nil {
		return nil, err
	}

	// In shared mode, strip user-provided system messages to prevent
	// system prompt override attacks. The server controls the system prompt.
	req.Messages = stripSystemMessages(req.Messages)

	// 3. Use server default LLM
	chatReq := s.toChatRequest(req, s.defaultCfg)
	ch, err := s.gateway.ChatStream(ctx, s.defaultCfg, chatReq)
	if err != nil {
		// If the error is a circuit breaker trip, log it distinctly.
		if errors.Is(err, llm.ErrCircuitOpen) {
			slog.Warn("default LLM circuit breaker is open", "provider", s.defaultCfg.Provider)
		}

		// Try fallback provider if configured.
		if s.fallbackCfg != nil {
			slog.Warn("default LLM failed, attempting fallback", "error", err)
			fallbackReq := s.toChatRequest(req, *s.fallbackCfg)
			fallbackCh, fallbackErr := s.gateway.ChatStream(ctx, *s.fallbackCfg, fallbackReq)
			if fallbackErr != nil {
				return nil, fmt.Errorf("default LLM failed: %w; fallback also failed: %w", err, fallbackErr)
			}
			return fallbackCh, nil
		}

		// No fallback configured.
		if errors.Is(err, llm.ErrCircuitOpen) {
			return nil, fmt.Errorf("LLM provider temporarily unavailable: %w", err)
		}
	}
	return ch, err
}

func (s *aiProxyService) toChatRequest(req domain.AIProxyRequest, cfg llm.GatewayConfig) llm.ChatRequest {
	model := req.Model
	if model == "" {
		model = cfg.Model
	}

	return llm.ChatRequest{
		Model:       model,
		Messages:    req.Messages,
		Temperature: req.Temperature,
		MaxTokens:   req.MaxTokens,
		Stream:      req.Stream,
	}
}

// stripSystemMessages removes all messages with role "system" from the slice.
// Used in shared mode to prevent users from injecting or overriding the system
// prompt, which could be used to bypass safety guardrails or extract the prompt.
func stripSystemMessages(msgs []domain.ChatMessage) []domain.ChatMessage {
	filtered := make([]domain.ChatMessage, 0, len(msgs))
	for _, m := range msgs {
		if m.Role != "system" {
			filtered = append(filtered, m)
		}
	}
	return filtered
}
