package handler

import (
	"context"
	"errors"
	"testing"

	"github.com/anynote/backend/internal/domain"
	"github.com/google/uuid"
)

// maxTokensCap must fall back to the free-tier cap when the quota lookup
// fails, and honour the plan tier otherwise.
func TestAIHandler_MaxTokensCap(t *testing.T) {
	uid := uuid.New()

	erroring := &mockQuotaSvcForHandler{
		getQuotaFn: func(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
			return nil, errors.New("quota backend down")
		},
	}
	if got := (&AIHandler{quotaSvc: erroring}).maxTokensCap(context.Background(), uid); got != maxTokensFree {
		t.Errorf("quota error: cap = %d, want free cap %d", got, maxTokensFree)
	}

	pro := &mockQuotaSvcForHandler{
		getQuotaFn: func(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
			return &domain.QuotaResponse{Plan: "pro"}, nil
		},
	}
	if got := (&AIHandler{quotaSvc: pro}).maxTokensCap(context.Background(), uid); got != maxTokensPro {
		t.Errorf("plan pro: cap = %d, want pro cap %d", got, maxTokensPro)
	}

	free := &mockQuotaSvcForHandler{
		getQuotaFn: func(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
			return &domain.QuotaResponse{Plan: "unknown-plan"}, nil
		},
	}
	if got := (&AIHandler{quotaSvc: free}).maxTokensCap(context.Background(), uid); got != maxTokensFree {
		t.Errorf("plan unknown: cap = %d, want free cap %d", got, maxTokensFree)
	}
}

// AddAIProxyTokens / Inc/DecAIActiveStreams must not panic and must accept
// zero/negative token values without recording them.
func TestAIMetrics_TokenAndStreamCounters(t *testing.T) {
	AddAIProxyTokens("test-provider", 0, 0)
	AddAIProxyTokens("test-provider", 12, 34)
	IncAIActiveStreams()
	DecAIActiveStreams()
}
