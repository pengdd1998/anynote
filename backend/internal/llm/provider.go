package llm

import (
	"context"

	"github.com/anynote/backend/internal/domain"
)

// Provider defines the interface for LLM providers.
type Provider interface {
	Name() string
	ChatStream(ctx context.Context, apiKey string, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error)
	Chat(ctx context.Context, apiKey string, baseURL string, req ChatRequest) (*ChatResponse, error)
}
