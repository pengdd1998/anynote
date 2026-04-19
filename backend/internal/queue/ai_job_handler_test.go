package queue

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/google/uuid"
	"github.com/hibiken/asynq"
	"github.com/redis/go-redis/v9"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Tests: AIJobHandler HandleTask — payload validation
// ---------------------------------------------------------------------------

func TestAIJobHandler_HandleTask_InvalidPayload(t *testing.T) {
	h := &AIJobHandler{}

	task := asynq.NewTask(TaskTypeAIProxy, []byte("not-json"))
	err := h.HandleTask(context.Background(), task)
	// Invalid payload should cause an error (returned to asynq for retry).
	if err == nil {
		t.Error("expected error for invalid JSON payload")
	}
}

func TestAIJobHandler_HandleTask_InvalidUserID_Panics(t *testing.T) {
	// With nil redis, storeError will panic because redis.Set is called on nil.
	// This test verifies the panic is caught and the code path works when redis is available.
	defer func() {
		r := recover()
		if r == nil {
			t.Error("expected panic with nil redis, but HandleTask returned normally")
		}
	}()

	h := &AIJobHandler{}

	payload := AIJobPayload{
		UserID: "not-a-uuid",
		JobID:  "job-1",
		Request: domain.AIProxyRequest{
			Messages: []domain.ChatMessage{
				{Role: "user", Content: "hello"},
			},
		},
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypeAIProxy, data)
	_ = h.HandleTask(context.Background(), task)
}

// ---------------------------------------------------------------------------
// Tests: AIJobPayload structure
// ---------------------------------------------------------------------------

func TestAIJobPayload_FullSerialization(t *testing.T) {
	req := domain.AIProxyRequest{
		Model: "deepseek-chat",
		Messages: []domain.ChatMessage{
			{Role: "system", Content: "You are helpful."},
			{Role: "user", Content: "Hello!"},
		},
		Stream: true,
	}

	payload := AIJobPayload{
		UserID:  "550e8400-e29b-41d4-a716-446655440000",
		JobID:   "job-abc-123",
		Request: req,
		Stream:  true,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded AIJobPayload
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.UserID != payload.UserID {
		t.Errorf("UserID = %q, want %q", decoded.UserID, payload.UserID)
	}
	if decoded.JobID != payload.JobID {
		t.Errorf("JobID = %q, want %q", decoded.JobID, payload.JobID)
	}
	if decoded.Stream != payload.Stream {
		t.Errorf("Stream = %v, want %v", decoded.Stream, payload.Stream)
	}
	if decoded.Request.Model != req.Model {
		t.Errorf("Model = %q, want %q", decoded.Request.Model, req.Model)
	}
	if len(decoded.Request.Messages) != 2 {
		t.Fatalf("Messages len = %d, want 2", len(decoded.Request.Messages))
	}
	if decoded.Request.Messages[0].Role != "system" {
		t.Errorf("Messages[0].Role = %q, want %q", decoded.Request.Messages[0].Role, "system")
	}
	if decoded.Request.Messages[1].Content != "Hello!" {
		t.Errorf("Messages[1].Content = %q, want %q", decoded.Request.Messages[1].Content, "Hello!")
	}
}

// ---------------------------------------------------------------------------
// Tests: PublishJobHandler HandleTask — payload validation
// ---------------------------------------------------------------------------

func TestPublishJobHandler_HandleTask_InvalidPayload(t *testing.T) {
	h := &PublishJobHandler{}

	task := asynq.NewTask(TaskTypePublish, []byte("not-json"))
	err := h.HandleTask(context.Background(), task)
	if err == nil {
		t.Error("expected error for invalid JSON payload")
	}
}

func TestPublishJobHandler_HandleTask_InvalidPublishLogID(t *testing.T) {
	h := &PublishJobHandler{}

	payload := PublishJobPayload{
		UserID:       "550e8400-e29b-41d4-a716-446655440000",
		Platform:     "xiaohongshu",
		PublishLogID: "not-a-uuid",
		Title:        "Test",
		Content:      "Content",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePublish, data)

	// Invalid publish log ID should return nil (non-retriable).
	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Errorf("HandleTask with invalid publishLogID returned error: %v (should be nil)", err)
	}
}

func TestPublishJobHandler_HandleTask_InvalidUserID(t *testing.T) {
	h := &PublishJobHandler{}

	payload := PublishJobPayload{
		UserID:       "not-a-uuid",
		Platform:     "xiaohongshu",
		PublishLogID: "550e8400-e29b-41d4-a716-446655440000",
		Title:        "Test",
		Content:      "Content",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePublish, data)

	// Invalid user ID should return nil (non-retriable).
	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Errorf("HandleTask with invalid userID returned error: %v (should be nil)", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: NewAIJobHandler
// ---------------------------------------------------------------------------

func TestNewAIJobHandler_NilDependencies(t *testing.T) {
	h := NewAIJobHandler(nil, nil, nil, nil, nil, llm.GatewayConfig{}, nil)
	if h == nil {
		t.Fatal("NewAIJobHandler returned nil")
	}
	if h.resultTTL == 0 {
		t.Error("resultTTL should have a default value")
	}
}

// ---------------------------------------------------------------------------
// Tests: NewPublishJobHandler
// ---------------------------------------------------------------------------

func TestNewPublishJobHandler_NilDependencies(t *testing.T) {
	h := NewPublishJobHandler(nil, nil, nil, nil)
	if h == nil {
		t.Fatal("NewPublishJobHandler returned nil")
	}
}

// ---------------------------------------------------------------------------
// Mocks for AI job handler tests
// ---------------------------------------------------------------------------

type mockLLMConfigRepo struct {
	getDefaultFn func(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error)
}

func (m *mockLLMConfigRepo) GetDefaultByUser(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error) {
	if m.getDefaultFn != nil {
		return m.getDefaultFn(ctx, userID)
	}
	return nil, errors.New("not found")
}

type mockQuotaSvc struct {
	incrementFn func(ctx context.Context, userID uuid.UUID) error
}

func (m *mockQuotaSvc) GetQuota(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
	return nil, nil
}

func (m *mockQuotaSvc) IncrementUsage(ctx context.Context, userID uuid.UUID) error {
	if m.incrementFn != nil {
		return m.incrementFn(ctx, userID)
	}
	return nil
}

// setupAIJobTest creates a miniredis instance and returns the handler + cleanup function.
func setupAIJobTest(t *testing.T) (*AIJobHandler, *miniredis.Miniredis) {
	t.Helper()
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { rdb.Close() })

	gw := llm.NewGateway()
	rateLimiter := service.NewRateLimiter(100, 24*time.Hour)
	defaultCfg := llm.GatewayConfig{
		Provider:    "deepseek",
		BaseURL:     "https://api.deepseek.com",
		APIKey:      "test-server-key",
		Model:       "deepseek-chat",
		MaxTokens:   4096,
		Temperature: 0.7,
	}
	encryptionKey := []byte("0123456789abcdef0123456789abcdef")

	h := NewAIJobHandler(gw, nil, nil, rateLimiter, rdb, defaultCfg, encryptionKey)
	return h, mr
}

// ---------------------------------------------------------------------------
// Tests: HandleTask with resolveConfig — user has custom config
// ---------------------------------------------------------------------------

func TestAIJobHandler_HandleTask_UserCustomConfig(t *testing.T) {
	h, _ := setupAIJobTest(t)
	userID := uuid.New()
	encKey, _ := llm.EncryptAPIKey("sk-user-key", h.encryptionKey)

	// Register a mock provider under "deepseek" to override the real one.
	var capturedModel string
	mockProvider := &testMockProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error) {
			capturedModel = req.Model
			return &llm.ChatResponse{Content: "response", Model: req.Model}, nil
		},
	}
	h.gateway.Register("deepseek", mockProvider)

	// User has a custom config pointing to the "deepseek" provider.
	h.llmRepo = &mockLLMConfigRepo{
		getDefaultFn: func(ctx context.Context, uid uuid.UUID) (*domain.LLMConfig, error) {
			return &domain.LLMConfig{
				ID:           uuid.New(),
				UserID:       uid,
				Provider:     "deepseek",
				BaseURL:      "https://api.deepseek.com",
				EncryptedKey: encKey,
				Model:        "deepseek-chat",
				MaxTokens:    4096,
				Temperature:  0.7,
			}, nil
		},
	}

	payload := AIJobPayload{
		UserID: userID.String(),
		JobID:  "job-custom-cfg",
		Request: domain.AIProxyRequest{
			Messages: []domain.ChatMessage{
				{Role: "user", Content: "hello"},
			},
		},
		Stream: false,
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypeAIProxy, data)

	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Fatalf("HandleTask: %v", err)
	}
	if capturedModel != "deepseek-chat" {
		t.Errorf("Model = %q, want %q", capturedModel, "deepseek-chat")
	}
}

// ---------------------------------------------------------------------------
// Tests: HandleTask — shared mode with default config
// ---------------------------------------------------------------------------

func TestAIJobHandler_HandleTask_SharedMode(t *testing.T) {
	h, _ := setupAIJobTest(t)
	userID := uuid.New()

	h.llmRepo = &mockLLMConfigRepo{
		getDefaultFn: func(ctx context.Context, uid uuid.UUID) (*domain.LLMConfig, error) {
			return nil, errors.New("no config")
		},
	}
	h.quotaSvc = &mockQuotaSvc{}

	payload := AIJobPayload{
		UserID: userID.String(),
		JobID:  "job-shared",
		Request: domain.AIProxyRequest{
			Messages: []domain.ChatMessage{
				{Role: "user", Content: "hello"},
			},
		},
		Stream: false,
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypeAIProxy, data)

	// This will fail because the real gateway can't connect, but the important
	// thing is that resolveConfig returns the default config path.
	// The handler should store an error result, not crash.
	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Fatalf("HandleTask should not return error for chat failures: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: HandleTask — quota exceeded in shared mode
// ---------------------------------------------------------------------------

func TestAIJobHandler_HandleTask_QuotaExceeded(t *testing.T) {
	h, _ := setupAIJobTest(t)
	userID := uuid.New()

	h.llmRepo = &mockLLMConfigRepo{
		getDefaultFn: func(ctx context.Context, uid uuid.UUID) (*domain.LLMConfig, error) {
			return nil, errors.New("no config")
		},
	}
	// Set rate limiter to 0 to immediately exceed quota
	h.rateLimiter = service.NewRateLimiter(0, 24*time.Hour)
	h.quotaSvc = &mockQuotaSvc{}

	payload := AIJobPayload{
		UserID: userID.String(),
		JobID:  "job-quota",
		Request: domain.AIProxyRequest{
			Messages: []domain.ChatMessage{
				{Role: "user", Content: "hello"},
			},
		},
		Stream: false,
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypeAIProxy, data)

	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Fatalf("HandleTask should not return error: %v", err)
	}
	// The error should be stored in Redis, not returned to asynq.
}

// ---------------------------------------------------------------------------
// Tests: HandleTask — streaming mode
// ---------------------------------------------------------------------------

func TestAIJobHandler_HandleTask_StreamingMode(t *testing.T) {
	h, _ := setupAIJobTest(t)
	userID := uuid.New()

	encKey, _ := llm.EncryptAPIKey("test-key", h.encryptionKey)
	h.llmRepo = &mockLLMConfigRepo{
		getDefaultFn: func(ctx context.Context, uid uuid.UUID) (*domain.LLMConfig, error) {
			return &domain.LLMConfig{
				Provider:     "deepseek",
				BaseURL:      "https://api.deepseek.com",
				EncryptedKey: encKey,
				Model:        "deepseek-chat",
				MaxTokens:    4096,
				Temperature:  0.7,
			}, nil
		},
	}

	payload := AIJobPayload{
		UserID: userID.String(),
		JobID:  "job-stream",
		Request: domain.AIProxyRequest{
			Messages: []domain.ChatMessage{
				{Role: "user", Content: "hello"},
			},
		},
		Stream: true,
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypeAIProxy, data)

	// This will fail to connect to the real API, but handleStream should
	// store an error result without crashing.
	err := h.HandleTask(context.Background(), task)
	if err != nil {
		t.Fatalf("HandleTask should not return error for stream failures: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: storeResult / storeError
// ---------------------------------------------------------------------------

func TestAIJobHandler_StoreResult(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	h := &AIJobHandler{
		redis:     rdb,
		resultTTL: 10 * time.Minute,
	}

	result := map[string]interface{}{
		"status":  "completed",
		"content": "Hello!",
	}
	h.storeResult(context.Background(), "job-1", result)

	// Verify the result was stored in Redis
	mr.FastForward(0)
	data, err := rdb.Get(context.Background(), "ai:result:job-1").Result()
	if err != nil {
		t.Fatalf("Get result: %v", err)
	}

	var stored map[string]interface{}
	if err := json.Unmarshal([]byte(data), &stored); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if stored["status"] != "completed" {
		t.Errorf("status = %v, want completed", stored["status"])
	}
	if stored["content"] != "Hello!" {
		t.Errorf("content = %v, want Hello!", stored["content"])
	}
}

func TestAIJobHandler_StoreError(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	h := &AIJobHandler{
		redis:     rdb,
		resultTTL: 10 * time.Minute,
	}

	h.storeError(context.Background(), "job-err", "something went wrong")

	mr.FastForward(0)
	data, err := rdb.Get(context.Background(), "ai:result:job-err").Result()
	if err != nil {
		t.Fatalf("Get result: %v", err)
	}

	var stored map[string]interface{}
	if err := json.Unmarshal([]byte(data), &stored); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if stored["status"] != "error" {
		t.Errorf("status = %v, want error", stored["status"])
	}
	if stored["error"] != "something went wrong" {
		t.Errorf("error = %v, want 'something went wrong'", stored["error"])
	}
}

func TestAIJobHandler_StoreResult_NilRedis(t *testing.T) {
	h := &AIJobHandler{
		redis:     nil,
		resultTTL: 10 * time.Minute,
	}

	// storeResult with nil redis panics because it calls h.redis.Set().
	// Verify that the panic occurs (documenting current behavior).
	defer func() {
		r := recover()
		if r == nil {
			t.Error("expected panic with nil redis, but storeResult returned normally")
		}
	}()
	h.storeResult(context.Background(), "job-nil", map[string]interface{}{"status": "test"})
}

// ---------------------------------------------------------------------------
// Mock provider for gateway-level tests
// ---------------------------------------------------------------------------

type testMockProvider struct {
	chatFn       func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error)
	chatStreamFn func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error)
}

func (m *testMockProvider) Name() string { return "test_mock" }

func (m *testMockProvider) Chat(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error) {
	if m.chatFn != nil {
		return m.chatFn(ctx, apiKey, baseURL, req)
	}
	return &llm.ChatResponse{Content: "test", Model: "test"}, nil
}

func (m *testMockProvider) ChatStream(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
	if m.chatStreamFn != nil {
		return m.chatStreamFn(ctx, apiKey, baseURL, req)
	}
	ch := make(chan domain.StreamChunk, 1)
	ch <- domain.StreamChunk{Done: true}
	close(ch)
	return ch, nil
}

// ---------------------------------------------------------------------------
// Tests: handleStream — success path with mock provider
// ---------------------------------------------------------------------------

func TestAIJobHandler_HandleStream_Success(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	gw := llm.NewGateway()
	mockProvider := &testMockProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
			ch := make(chan domain.StreamChunk, 4)
			ch <- domain.StreamChunk{Content: "Hello "}
			ch <- domain.StreamChunk{Content: "world"}
			ch <- domain.StreamChunk{Content: "!", Done: true}
			close(ch)
			return ch, nil
		},
	}
	gw.Register("deepseek", mockProvider)

	h := &AIJobHandler{
		gateway:   gw,
		redis:     rdb,
		resultTTL: 10 * time.Minute,
	}

	cfg := llm.GatewayConfig{
		Provider: "deepseek",
		APIKey:   "test-key",
		Model:    "deepseek-chat",
	}
	req := llm.ChatRequest{
		Model:    "deepseek-chat",
		Messages: []domain.ChatMessage{{Role: "user", Content: "hi"}},
		Stream:   true,
	}

	payload := AIJobPayload{
		UserID: uuid.New().String(),
		JobID:  "job-stream-success",
		Stream: true,
	}

	err := h.handleStream(context.Background(), payload, cfg, req)
	if err != nil {
		t.Fatalf("handleStream: %v", err)
	}

	// Verify the final result stored in Redis contains the full content.
	mr.FastForward(0)
	data, err := rdb.Get(context.Background(), "ai:result:job-stream-success").Result()
	if err != nil {
		t.Fatalf("Get result: %v", err)
	}

	var stored map[string]interface{}
	if err := json.Unmarshal([]byte(data), &stored); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if stored["status"] != "completed" {
		t.Errorf("status = %v, want completed", stored["status"])
	}
	if stored["content"] != "Hello world!" {
		t.Errorf("content = %v, want 'Hello world!'", stored["content"])
	}
	done, _ := stored["done"].(bool)
	if !done {
		t.Error("done should be true")
	}
}

func TestAIJobHandler_HandleStream_ChunkError(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	gw := llm.NewGateway()
	mockProvider := &testMockProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
			ch := make(chan domain.StreamChunk, 2)
			ch <- domain.StreamChunk{Content: "partial "}
			ch <- domain.StreamChunk{Error: "rate limit exceeded"}
			close(ch)
			return ch, nil
		},
	}
	gw.Register("deepseek", mockProvider)

	h := &AIJobHandler{
		gateway:   gw,
		redis:     rdb,
		resultTTL: 10 * time.Minute,
	}

	cfg := llm.GatewayConfig{
		Provider: "deepseek",
		APIKey:   "test-key",
	}
	req := llm.ChatRequest{Stream: true}

	payload := AIJobPayload{
		UserID: uuid.New().String(),
		JobID:  "job-stream-err",
		Stream: true,
	}

	err := h.handleStream(context.Background(), payload, cfg, req)
	if err != nil {
		t.Fatalf("handleStream should return nil (stores error in Redis): %v", err)
	}

	// Verify the error result was stored.
	mr.FastForward(0)
	data, err := rdb.Get(context.Background(), "ai:result:job-stream-err").Result()
	if err != nil {
		t.Fatalf("Get result: %v", err)
	}

	var stored map[string]interface{}
	if err := json.Unmarshal([]byte(data), &stored); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if stored["status"] != "error" {
		t.Errorf("status = %v, want error", stored["status"])
	}
}

func TestAIJobHandler_HandleStream_GatewayError(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	gw := llm.NewGateway()
	// No provider registered, so ChatStream will fail.

	h := &AIJobHandler{
		gateway:   gw,
		redis:     rdb,
		resultTTL: 10 * time.Minute,
	}

	cfg := llm.GatewayConfig{
		Provider: "nonexistent",
		APIKey:   "test-key",
	}
	req := llm.ChatRequest{Stream: true}

	payload := AIJobPayload{
		UserID: uuid.New().String(),
		JobID:  "job-stream-gw-err",
		Stream: true,
	}

	err := h.handleStream(context.Background(), payload, cfg, req)
	if err != nil {
		t.Fatalf("handleStream should return nil (stores error in Redis): %v", err)
	}

	// Verify error stored in Redis.
	mr.FastForward(0)
	data, err := rdb.Get(context.Background(), "ai:result:job-stream-gw-err").Result()
	if err != nil {
		t.Fatalf("Get result: %v", err)
	}

	var stored map[string]interface{}
	if err := json.Unmarshal([]byte(data), &stored); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if stored["status"] != "error" {
		t.Errorf("status = %v, want error", stored["status"])
	}
}
