package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/hibiken/asynq"
	"github.com/redis/go-redis/v9"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/service"
)

// AIJobPayload is the structured payload for AI proxy jobs.
type AIJobPayload struct {
	UserID    string             `json:"user_id"`
	Request   domain.AIProxyRequest `json:"request"`
	JobID     string             `json:"job_id"`
	Stream    bool               `json:"stream"`
}

// AIJobHandler processes AI proxy jobs from the shared LLM queue.
// It resolves the user's LLM configuration, calls the LLM gateway,
// and stores the result in Redis for client retrieval.
type AIJobHandler struct {
	gateway       *llm.Gateway
	llmRepo       service.LLMConfigRepository
	quotaSvc      service.QuotaService
	rateLimiter   service.RateLimitProvider
	redis         *redis.Client
	defaultCfg    llm.GatewayConfig
	encryptionKey []byte
	resultTTL     time.Duration
}

// NewAIJobHandler creates a new AI job handler with the required dependencies.
func NewAIJobHandler(
	gateway *llm.Gateway,
	llmRepo service.LLMConfigRepository,
	quotaSvc service.QuotaService,
	rateLimiter service.RateLimitProvider,
	redisClient *redis.Client,
	defaultCfg llm.GatewayConfig,
	encryptionKey []byte,
) *AIJobHandler {
	return &AIJobHandler{
		gateway:       gateway,
		llmRepo:       llmRepo,
		quotaSvc:      quotaSvc,
		rateLimiter:   rateLimiter,
		redis:         redisClient,
		defaultCfg:    defaultCfg,
		encryptionKey: encryptionKey,
		resultTTL:     10 * time.Minute,
	}
}

// HandleTask is the asynq handler function for AI proxy tasks.
func (h *AIJobHandler) HandleTask(ctx context.Context, t *asynq.Task) error {
	var payload AIJobPayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		slog.Error("ai job: failed to unmarshal payload", "error", err)
		return fmt.Errorf("unmarshal payload: %w", err)
	}

	slog.Info("processing AI proxy job", "user_id", payload.UserID, "job_id", payload.JobID)

	uid, err := uuid.Parse(payload.UserID)
	if err != nil {
		h.storeError(ctx, payload.JobID, "invalid user ID")
		return nil // Non-retriable: do not return error to asynq
	}

	// Resolve LLM configuration
	cfg, chatReq, err := h.resolveConfig(ctx, uid, payload.Request)
	if err != nil {
		slog.Error("ai job: failed to resolve config", "user_id", payload.UserID, "error", err)
		h.storeError(ctx, payload.JobID, err.Error())
		return nil
	}

	// For streaming jobs, we store chunks as they arrive
	if payload.Stream {
		return h.handleStream(ctx, payload, cfg, chatReq)
	}

	// Non-streaming: call Chat and store the full result
	return h.handleChat(ctx, payload, cfg, chatReq)
}

// resolveConfig determines which LLM config to use for the request.
// If the user has a custom config, it decrypts the API key and uses it.
// Otherwise, it falls back to the server default with quota enforcement.
func (h *AIJobHandler) resolveConfig(ctx context.Context, uid uuid.UUID, req domain.AIProxyRequest) (llm.GatewayConfig, llm.ChatRequest, error) {
	chatReq := llm.ChatRequest{
		Model:       req.Model,
		Messages:    req.Messages,
		Temperature: req.Temperature,
		MaxTokens:   req.MaxTokens,
		Stream:      req.Stream,
	}

	// Check if user has custom LLM configuration.
	dedicatedCfg, err := service.UserLLMConfig(ctx, uid, h.llmRepo, h.encryptionKey)
	if err != nil {
		return llm.GatewayConfig{}, chatReq, fmt.Errorf("resolve user llm config: %w", err)
	}
	if dedicatedCfg != nil {
		chatReq.Model = service.ResolveChatModel(chatReq.Model, *dedicatedCfg)
		return *dedicatedCfg, chatReq, nil
	}

	// Shared mode: check rate limit and quota.
	userIDStr := uid.String()
	if err := service.CheckSharedModeQuota(ctx, uid, userIDStr, h.rateLimiter, h.quotaSvc); err != nil {
		return llm.GatewayConfig{}, chatReq, err
	}

	chatReq.Model = service.ResolveChatModel(chatReq.Model, h.defaultCfg)

	return h.defaultCfg, chatReq, nil
}

// handleChat processes a non-streaming request and stores the result in Redis.
func (h *AIJobHandler) handleChat(ctx context.Context, payload AIJobPayload, cfg llm.GatewayConfig, req llm.ChatRequest) error {
	resp, err := h.gateway.Chat(ctx, cfg, req)
	if err != nil {
		slog.Error("ai job: chat request failed", "job_id", payload.JobID, "error", err)
		h.storeError(ctx, payload.JobID, err.Error())
		return nil
	}

	result := map[string]interface{}{
		"status":  "completed",
		"content": resp.Content,
		"model":   resp.Model,
		"usage":   resp.Usage,
	}
	h.storeResult(ctx, payload.JobID, result)
	return nil
}

// handleStream processes a streaming request, collecting chunks and storing the full result.
// Note: the worker produces the result asynchronously; the client polls Redis for completion.
func (h *AIJobHandler) handleStream(ctx context.Context, payload AIJobPayload, cfg llm.GatewayConfig, req llm.ChatRequest) error {
	ch, err := h.gateway.ChatStream(ctx, cfg, req)
	if err != nil {
		slog.Error("ai job: stream request failed", "job_id", payload.JobID, "error", err)
		h.storeError(ctx, payload.JobID, err.Error())
		return nil
	}

	var fullContent string
	for chunk := range ch {
		if chunk.Error != "" {
			slog.Error("ai job: stream chunk error", "job_id", payload.JobID, "error", chunk.Error)
			h.storeError(ctx, payload.JobID, chunk.Error)
			return nil
		}
		fullContent += chunk.Content

		// Store intermediate state so the client can poll partial results
		partial := map[string]interface{}{
			"status":  "streaming",
			"content": fullContent,
			"done":    chunk.Done,
		}
		h.storeResult(ctx, payload.JobID, partial)
	}

	result := map[string]interface{}{
		"status":  "completed",
		"content": fullContent,
		"done":    true,
	}
	h.storeResult(ctx, payload.JobID, result)
	return nil
}

// storeResult stores a JSON-serializable result in Redis with a TTL.
func (h *AIJobHandler) storeResult(ctx context.Context, jobID string, result interface{}) {
	key := fmt.Sprintf("ai:result:%s", jobID)
	data, err := json.Marshal(result)
	if err != nil {
		slog.Error("ai job: failed to marshal result", "job_id", jobID, "error", err)
		return
	}
	if err := h.redis.Set(ctx, key, data, h.resultTTL).Err(); err != nil {
		slog.Error("ai job: failed to store result in redis", "job_id", jobID, "error", err)
	}
}

// storeError stores an error result in Redis.
func (h *AIJobHandler) storeError(ctx context.Context, jobID string, errMsg string) {
	result := map[string]interface{}{
		"status": "error",
		"error":  errMsg,
	}
	h.storeResult(ctx, jobID, result)
}
