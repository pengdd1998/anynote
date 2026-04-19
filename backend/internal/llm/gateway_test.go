package llm

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock Provider for Gateway tests
// ---------------------------------------------------------------------------

type mockGatewayProvider struct {
	chatFn       func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error)
	chatStreamFn func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error)
}

func (m *mockGatewayProvider) Name() string { return "test_provider" }

func (m *mockGatewayProvider) Chat(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
	if m.chatFn != nil {
		return m.chatFn(ctx, apiKey, baseURL, req)
	}
	return &ChatResponse{Content: "test response", Model: "test-model"}, nil
}

func (m *mockGatewayProvider) ChatStream(ctx context.Context, apiKey, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error) {
	if m.chatStreamFn != nil {
		return m.chatStreamFn(ctx, apiKey, baseURL, req)
	}
	ch := make(chan domain.StreamChunk, 2)
	ch <- domain.StreamChunk{Content: "test chunk"}
	ch <- domain.StreamChunk{Done: true}
	close(ch)
	return ch, nil
}

// ---------------------------------------------------------------------------
// Gateway Chat tests
// ---------------------------------------------------------------------------

func TestGateway_Chat_Success(t *testing.T) {
	gw := NewGateway()
	provider := &mockGatewayProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
			if apiKey != "test-key" {
				t.Errorf("apiKey = %q, want %q", apiKey, "test-key")
			}
			if baseURL != "https://api.test.llm" {
				t.Errorf("baseURL = %q, want %q", baseURL, "https://api.test.llm")
			}
			return &ChatResponse{Content: "Hello!", Model: "test-model"}, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{
		Provider:    "test_provider",
		BaseURL:     "https://api.test.llm",
		APIKey:      "test-key",
		Model:       "test-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	resp, err := gw.Chat(context.Background(), cfg, ChatRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello"},
		},
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if resp.Content != "Hello!" {
		t.Errorf("Content = %q, want %q", resp.Content, "Hello!")
	}
}

func TestGateway_Chat_UnsupportedProvider(t *testing.T) {
	gw := NewGateway()

	cfg := GatewayConfig{Provider: "nonexistent"}
	_, err := gw.Chat(context.Background(), cfg, ChatRequest{})
	if err == nil {
		t.Error("expected error for unsupported provider")
	}
}

func TestGateway_Chat_DefaultsModelFromConfig(t *testing.T) {
	gw := NewGateway()
	var capturedModel string
	provider := &mockGatewayProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
			capturedModel = req.Model
			return &ChatResponse{}, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{
		Provider:    "test_provider",
		Model:       "default-model-v1",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	_, err := gw.Chat(context.Background(), cfg, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if capturedModel != "default-model-v1" {
		t.Errorf("Model = %q, want %q", capturedModel, "default-model-v1")
	}
}

func TestGateway_Chat_RequestModelOverridesConfig(t *testing.T) {
	gw := NewGateway()
	var capturedModel string
	provider := &mockGatewayProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
			capturedModel = req.Model
			return &ChatResponse{}, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{
		Provider:    "test_provider",
		Model:       "config-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	_, err := gw.Chat(context.Background(), cfg, ChatRequest{
		Model:    "override-model",
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if capturedModel != "override-model" {
		t.Errorf("Model = %q, want %q", capturedModel, "override-model")
	}
}

func TestGateway_Chat_SetsStreamFalse(t *testing.T) {
	gw := NewGateway()
	var capturedStream bool
	provider := &mockGatewayProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
			capturedStream = req.Stream
			return &ChatResponse{}, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{Provider: "test_provider", MaxTokens: 4096, Temperature: 0.7}
	_, err := gw.Chat(context.Background(), cfg, ChatRequest{
		Stream:   true, // should be overridden to false
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if capturedStream {
		t.Error("Stream should be forced to false for non-streaming Chat")
	}
}

// ---------------------------------------------------------------------------
// Gateway ChatStream tests
// ---------------------------------------------------------------------------

func TestGateway_ChatStream_Success(t *testing.T) {
	gw := NewGateway()
	provider := &mockGatewayProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error) {
			ch := make(chan domain.StreamChunk, 3)
			ch <- domain.StreamChunk{Content: "Hello"}
			ch <- domain.StreamChunk{Content: " World"}
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{
		Provider:    "test_provider",
		BaseURL:     "https://api.test.llm",
		APIKey:      "test-key",
		Model:       "test-model",
		MaxTokens:   4096,
		Temperature: 0.7,
	}

	ch, err := gw.ChatStream(context.Background(), cfg, ChatRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello"},
		},
	})
	if err != nil {
		t.Fatalf("ChatStream: %v", err)
	}

	var content string
	for chunk := range ch {
		if chunk.Error != "" {
			t.Fatalf("stream error: %s", chunk.Error)
		}
		content += chunk.Content
	}
	if content != "Hello World" {
		t.Errorf("content = %q, want %q", content, "Hello World")
	}
}

func TestGateway_ChatStream_UnsupportedProvider(t *testing.T) {
	gw := NewGateway()
	cfg := GatewayConfig{Provider: "nonexistent"}

	_, err := gw.ChatStream(context.Background(), cfg, ChatRequest{})
	if err == nil {
		t.Error("expected error for unsupported provider")
	}
}

func TestGateway_ChatStream_SetsStreamTrue(t *testing.T) {
	gw := NewGateway()
	var capturedStream bool
	provider := &mockGatewayProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error) {
			capturedStream = req.Stream
			ch := make(chan domain.StreamChunk, 1)
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{Provider: "test_provider", MaxTokens: 4096, Temperature: 0.7}
	ch, _ := gw.ChatStream(context.Background(), cfg, ChatRequest{
		Stream:   false, // should be overridden to true
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})
	for range ch {
	}
	if !capturedStream {
		t.Error("Stream should be forced to true for ChatStream")
	}
}

func TestGateway_ChatStream_DefaultsTemperatureAndMaxTokens(t *testing.T) {
	gw := NewGateway()
	var capturedTemp *float32
	var capturedMaxTokens *int
	provider := &mockGatewayProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error) {
			capturedTemp = req.Temperature
			capturedMaxTokens = req.MaxTokens
			ch := make(chan domain.StreamChunk, 1)
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{
		Provider:    "test_provider",
		MaxTokens:   2048,
		Temperature: 0.5,
	}
	ch, _ := gw.ChatStream(context.Background(), cfg, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})
	for range ch {
	}

	if capturedTemp == nil || *capturedTemp != 0.5 {
		t.Errorf("Temperature = %v, want 0.5", capturedTemp)
	}
	if capturedMaxTokens == nil || *capturedMaxTokens != 2048 {
		t.Errorf("MaxTokens = %v, want 2048", capturedMaxTokens)
	}
}

func TestGateway_ChatStream_ProviderError(t *testing.T) {
	gw := NewGateway()
	provider := &mockGatewayProvider{
		chatStreamFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error) {
			return nil, errors.New("connection refused")
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{Provider: "test_provider", MaxTokens: 4096, Temperature: 0.7}
	_, err := gw.ChatStream(context.Background(), cfg, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})
	if err == nil {
		t.Error("expected error when provider fails")
	}
}

// ---------------------------------------------------------------------------
// Gateway Chat Retry tests
// ---------------------------------------------------------------------------

func TestGateway_Chat_RetryOnProviderError(t *testing.T) {
	gw := NewGateway()
	callCount := 0
	provider := &mockGatewayProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
			callCount++
			// The gateway delegates directly to the provider with no retry loop.
			// Retry logic lives inside the real OpenAICompatProvider.Chat which
			// handles HTTP status codes.  With a mock provider we can only
			// verify that the gateway passes retry config through and calls
			// the provider exactly once.
			return &ChatResponse{Content: "success"}, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{
		Provider:       "test_provider",
		MaxTokens:      4096,
		Temperature:    0.7,
		MaxRetries:     3,
		RetryBaseDelay: 1 * time.Millisecond,
	}

	resp, err := gw.Chat(context.Background(), cfg, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	// Gateway calls the provider exactly once; retries are the provider's concern.
	if callCount != 1 {
		t.Errorf("callCount = %d, want 1 (gateway delegates retries to the provider)", callCount)
	}
	if resp.Content != "success" {
		t.Errorf("Content = %q, want %q", resp.Content, "success")
	}
}

func TestGateway_Chat_DefaultRetryConfig(t *testing.T) {
	gw := NewGateway()
	var capturedMaxRetries int
	var capturedRetryDelay time.Duration
	provider := &mockGatewayProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
			capturedMaxRetries = req.MaxRetries
			capturedRetryDelay = req.RetryBaseDelay
			return &ChatResponse{}, nil
		},
	}
	gw.Register("test_provider", provider)

	cfg := GatewayConfig{
		Provider:    "test_provider",
		MaxTokens:   4096,
		Temperature: 0.7,
		// No MaxRetries or RetryBaseDelay set -- should get defaults.
	}

	_, err := gw.Chat(context.Background(), cfg, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if capturedMaxRetries != 3 {
		t.Errorf("MaxRetries = %d, want 3 (default)", capturedMaxRetries)
	}
	if capturedRetryDelay != 1*time.Second {
		t.Errorf("RetryBaseDelay = %v, want 1s (default)", capturedRetryDelay)
	}
}
