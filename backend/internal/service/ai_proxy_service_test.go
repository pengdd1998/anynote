package service

import (
	"context"
	"crypto/rand"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/llm"
)

// ---------------------------------------------------------------------------
// Mock LLMConfigRepository (satisfies LLMConfigRepository from ai_proxy_service.go)
// ---------------------------------------------------------------------------

type mockLLMConfigRepo struct {
	config *domain.LLMConfig
	err    error
}

func (m *mockLLMConfigRepo) GetDefaultByUser(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error) {
	if m.err != nil {
		return nil, m.err
	}
	return m.config, nil
}

// ---------------------------------------------------------------------------
// Mock QuotaService
// ---------------------------------------------------------------------------

type mockQuotaService struct {
	incrementErr error
}

func (m *mockQuotaService) GetQuota(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
	return &domain.QuotaResponse{Plan: "free", DailyLimit: 50}, nil
}

func (m *mockQuotaService) IncrementUsage(ctx context.Context, userID uuid.UUID) error {
	return m.incrementErr
}

// ---------------------------------------------------------------------------
// Mock Provider for Gateway (satisfies llm.Provider)
// ---------------------------------------------------------------------------

type mockProvider struct {
	chatFn       func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error)
	chatStreamFn func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error)
}

func (m *mockProvider) Name() string { return "mock" }

func (m *mockProvider) Chat(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error) {
	if m.chatFn != nil {
		return m.chatFn(ctx, apiKey, baseURL, req)
	}
	return &llm.ChatResponse{Content: "mock response", Model: "mock-model"}, nil
}

func (m *mockProvider) ChatStream(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
	if m.chatStreamFn != nil {
		return m.chatStreamFn(ctx, apiKey, baseURL, req)
	}
	// Default: send one chunk and close.
	ch := make(chan domain.StreamChunk, 2)
	ch <- domain.StreamChunk{Content: "hello"}
	ch <- domain.StreamChunk{Done: true}
	close(ch)
	return ch, nil
}

// newTestGateway creates a Gateway with a mock provider registered.
func newTestGateway(provider llm.Provider) *llm.Gateway {
	gw := llm.NewGateway()
	gw.Register("mock", provider)
	gw.Register("openai", provider)
	gw.Register("deepseek", provider)
	gw.Register("custom", provider)
	return gw
}

// newTestEncryptionKey generates a random 32-byte key for AES-256-GCM.
func newTestEncryptionKey() []byte {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		panic(err)
	}
	return key
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestAIProxyService_UserLLMConfig(t *testing.T) {
	encKey := newTestEncryptionKey()

	// Encrypt a fake API key with the master key so DecryptAPIKey will succeed.
	encryptedKey, err := llm.EncryptAPIKey("sk-user-secret-key", encKey)
	if err != nil {
		t.Fatalf("encrypt key: %v", err)
	}

	userID := uuid.New()
	llmRepo := &mockLLMConfigRepo{
		config: &domain.LLMConfig{
			ID:           uuid.New(),
			UserID:       userID,
			Provider:     "mock",
			BaseURL:      "https://api.mock.llm",
			EncryptedKey: encryptedKey,
			Model:        "mock-model-v1",
			MaxTokens:    2048,
			Temperature:  0.7,
		},
	}

	var capturedAPIKey string
	provider := &mockProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
			capturedAPIKey = apiKey
			ch := make(chan domain.StreamChunk, 2)
			ch <- domain.StreamChunk{Content: "user-model-response"}
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}

	gw := newTestGateway(provider)
	rateLimiter := NewRateLimiter(100, time.Hour)
	quotaSvc := &mockQuotaService{}

	defaultCfg := llm.GatewayConfig{
		Provider:    "mock",
		BaseURL:     "https://shared.llm",
		APIKey:      "shared-key",
		Model:       "shared-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	svc := NewAIProxyService(gw, llmRepo, quotaSvc, rateLimiter, defaultCfg, encKey)

	ch, err := svc.Proxy(context.Background(), userID.String(), domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello"},
		},
		Stream: true,
	})
	if err != nil {
		t.Fatalf("Proxy: %v", err)
	}

	// Read the stream chunks.
	var content string
	for chunk := range ch {
		if chunk.Error != "" {
			t.Fatalf("stream error: %s", chunk.Error)
		}
		content += chunk.Content
	}

	if content != "user-model-response" {
		t.Errorf("content = %q, want %q", content, "user-model-response")
	}
	if capturedAPIKey != "sk-user-secret-key" {
		t.Errorf("API key sent to provider = %q, want decrypted user key", capturedAPIKey)
	}
}

func TestAIProxyService_SharedLLM(t *testing.T) {
	encKey := newTestEncryptionKey()

	// No user config -- falls back to shared LLM.
	llmRepo := &mockLLMConfigRepo{err: ErrUserNotFound}

	var capturedAPIKey string
	provider := &mockProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
			capturedAPIKey = apiKey
			ch := make(chan domain.StreamChunk, 2)
			ch <- domain.StreamChunk{Content: "shared-response"}
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}

	gw := newTestGateway(provider)
	rateLimiter := NewRateLimiter(100, time.Hour)
	quotaSvc := &mockQuotaService{}

	defaultCfg := llm.GatewayConfig{
		Provider:    "mock",
		BaseURL:     "https://shared.llm",
		APIKey:      "shared-key-123",
		Model:       "shared-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	svc := NewAIProxyService(gw, llmRepo, quotaSvc, rateLimiter, defaultCfg, encKey)

	userID := uuid.New()
	ch, err := svc.Proxy(context.Background(), userID.String(), domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello"},
		},
		Stream: true,
	})
	if err != nil {
		t.Fatalf("Proxy: %v", err)
	}

	var content string
	for chunk := range ch {
		if chunk.Error != "" {
			t.Fatalf("stream error: %s", chunk.Error)
		}
		content += chunk.Content
	}

	if content != "shared-response" {
		t.Errorf("content = %q, want %q", content, "shared-response")
	}
	if capturedAPIKey != "shared-key-123" {
		t.Errorf("API key = %q, want shared key", capturedAPIKey)
	}
}

func TestAIProxyService_QuotaExceeded(t *testing.T) {
	encKey := newTestEncryptionKey()
	llmRepo := &mockLLMConfigRepo{err: ErrUserNotFound} // no user config
	provider := &mockProvider{}

	gw := newTestGateway(provider)
	rateLimiter := NewRateLimiter(0, time.Hour) // zero limit means all requests are rejected
	quotaSvc := &mockQuotaService{}

	defaultCfg := llm.GatewayConfig{
		Provider:    "mock",
		BaseURL:     "https://shared.llm",
		APIKey:      "shared-key",
		Model:       "shared-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	svc := NewAIProxyService(gw, llmRepo, quotaSvc, rateLimiter, defaultCfg, encKey)

	userID := uuid.New()
	_, err := svc.Proxy(context.Background(), userID.String(), domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello"},
		},
		Stream: true,
	})
	if err == nil {
		t.Error("expected error when quota exceeded")
	}
}

func TestAIProxyService_DecryptKeyFailure(t *testing.T) {
	encKey := newTestEncryptionKey()

	// Store corrupted encrypted key -- decryption will fail.
	userID := uuid.New()
	llmRepo := &mockLLMConfigRepo{
		config: &domain.LLMConfig{
			ID:           uuid.New(),
			UserID:       userID,
			Provider:     "mock",
			BaseURL:      "https://api.mock.llm",
			EncryptedKey: []byte("corrupted-data-not-valid-aes-gcm"),
			Model:        "mock-model",
			MaxTokens:    2048,
			Temperature:  0.7,
		},
	}

	provider := &mockProvider{}
	gw := newTestGateway(provider)
	rateLimiter := NewRateLimiter(100, time.Hour)
	quotaSvc := &mockQuotaService{}

	defaultCfg := llm.GatewayConfig{
		Provider:    "mock",
		BaseURL:     "https://shared.llm",
		APIKey:      "shared-key",
		Model:       "shared-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	svc := NewAIProxyService(gw, llmRepo, quotaSvc, rateLimiter, defaultCfg, encKey)

	_, err := svc.Proxy(context.Background(), userID.String(), domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello"},
		},
		Stream: true,
	})
	if err == nil {
		t.Error("expected error when API key decryption fails")
	}
}

func TestAIProxyService_UserConfigOverridesModel(t *testing.T) {
	encKey := newTestEncryptionKey()

	encryptedKey, err := llm.EncryptAPIKey("sk-key", encKey)
	if err != nil {
		t.Fatalf("encrypt key: %v", err)
	}

	userID := uuid.New()
	llmRepo := &mockLLMConfigRepo{
		config: &domain.LLMConfig{
			ID:           uuid.New(),
			UserID:       userID,
			Provider:     "mock",
			BaseURL:      "https://api.mock.llm",
			EncryptedKey: encryptedKey,
			Model:        "user-custom-model",
			MaxTokens:    1024,
			Temperature:  0.5,
		},
	}

	var capturedModel string
	provider := &mockProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
			capturedModel = req.Model
			ch := make(chan domain.StreamChunk, 1)
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}

	gw := newTestGateway(provider)
	rateLimiter := NewRateLimiter(100, time.Hour)
	quotaSvc := &mockQuotaService{}

	defaultCfg := llm.GatewayConfig{
		Provider:    "mock",
		BaseURL:     "https://shared.llm",
		APIKey:      "shared-key",
		Model:       "shared-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	svc := NewAIProxyService(gw, llmRepo, quotaSvc, rateLimiter, defaultCfg, encKey)

	ch, _ := svc.Proxy(context.Background(), userID.String(), domain.AIProxyRequest{
		Model: "override-model",
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello"},
		},
		Stream: true,
	})
	// Drain the channel.
	for range ch {
	}

	if capturedModel != "override-model" {
		t.Errorf("Model = %q, want %q (request model should override config model)", capturedModel, "override-model")
	}
}

func TestAIProxyService_UserConfigFallbackModel(t *testing.T) {
	encKey := newTestEncryptionKey()

	encryptedKey, err := llm.EncryptAPIKey("sk-key", encKey)
	if err != nil {
		t.Fatalf("encrypt key: %v", err)
	}

	userID := uuid.New()
	llmRepo := &mockLLMConfigRepo{
		config: &domain.LLMConfig{
			ID:           uuid.New(),
			UserID:       userID,
			Provider:     "mock",
			BaseURL:      "https://api.mock.llm",
			EncryptedKey: encryptedKey,
			Model:        "user-config-model",
			MaxTokens:    2048,
			Temperature:  0.7,
		},
	}

	var capturedModel string
	provider := &mockProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
			capturedModel = req.Model
			ch := make(chan domain.StreamChunk, 1)
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}

	gw := newTestGateway(provider)
	rateLimiter := NewRateLimiter(100, time.Hour)
	quotaSvc := &mockQuotaService{}

	defaultCfg := llm.GatewayConfig{
		Provider:    "mock",
		BaseURL:     "https://shared.llm",
		APIKey:      "shared-key",
		Model:       "shared-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	svc := NewAIProxyService(gw, llmRepo, quotaSvc, rateLimiter, defaultCfg, encKey)

	// Do not specify Model in the request -- should fall back to user config model.
	ch, _ := svc.Proxy(context.Background(), userID.String(), domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello"},
		},
		Stream: true,
	})
	for range ch {
	}

	if capturedModel != "user-config-model" {
		t.Errorf("Model = %q, want %q (should fall back to user config model)", capturedModel, "user-config-model")
	}
}
