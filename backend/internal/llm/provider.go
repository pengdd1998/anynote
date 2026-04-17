package llm

import (
	"context"
)

// Provider defines the interface for LLM providers.
type Provider interface {
	Name() string
	ChatStream(ctx context.Context, apiKey string, baseURL string, req ChatRequest) (<-chan StreamChunk, error)
	Chat(ctx context.Context, apiKey string, baseURL string, req ChatRequest) (*ChatResponse, error)
}

// StreamChunk represents a chunk of streamed response.
type StreamChunk struct {
	Content string
	Done    bool
	Error   string
}
