package service

import (
	"context"
	"errors"
	"fmt"

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
	gateway     *llm.Gateway
	llmRepo     LLMConfigRepository
	quotaSvc    QuotaService
	rateLimiter *RateLimiter
	defaultCfg  llm.GatewayConfig
}

func NewAIProxyService(
	gateway *llm.Gateway,
	llmRepo LLMConfigRepository,
	quotaSvc QuotaService,
	rateLimiter *RateLimiter,
	defaultCfg llm.GatewayConfig,
) AIProxyService {
	return &aiProxyService{
		gateway:     gateway,
		llmRepo:     llmRepo,
		quotaSvc:    quotaSvc,
		rateLimiter: rateLimiter,
		defaultCfg:  defaultCfg,
	}
}

func (s *aiProxyService) Proxy(ctx context.Context, userID string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
	uid, _ := uuid.Parse(userID)

	// 1. Check if user has custom LLM configuration
	userCfg, err := s.llmRepo.GetDefaultByUser(ctx, uid)
	if err == nil && userCfg != nil {
		// Dedicated mode: use user's own API key
		dedicatedCfg := llm.GatewayConfig{
			Provider:    userCfg.Provider,
			BaseURL:     userCfg.BaseURL,
			APIKey:      userCfg.DecryptedKey,
			Model:       userCfg.Model,
			MaxTokens:   userCfg.MaxTokens,
			Temperature: userCfg.Temperature,
			Timeout:     120 * 1e9, // 120s in nanoseconds
		}

		chatReq := s.toChatRequest(req, dedicatedCfg)
		return s.gateway.ChatStream(ctx, dedicatedCfg, chatReq)
	}

	// 2. Shared mode: check rate limit and quota
	if !s.rateLimiter.Allow(userID) {
		return nil, ErrQuotaExceeded
	}

	// Increment usage
	_ = s.quotaSvc.IncrementUsage(ctx, uid)

	// 3. Use server default LLM
	chatReq := s.toChatRequest(req, s.defaultCfg)
	return s.gateway.ChatStream(ctx, s.defaultCfg, chatReq)
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
