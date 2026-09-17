package service

import (
	"context"
	"errors"
	"math"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// Semantic search limits.
const (
	MaxEmbeddingDim = 4096
	MinEmbeddingDim = 1
	DefaultSearchK  = 20
	MaxSearchK      = 50
)

// ErrInvalidEmbedding is returned for vectors the server refuses to store
// or use as a query (wrong size, non-finite values).
var ErrInvalidEmbedding = errors.New("invalid embedding vector")

// SemanticSearchRepository is the data access surface for note vectors.
type SemanticSearchRepository interface {
	Upsert(ctx context.Context, userID uuid.UUID, noteID uuid.UUID, lang string, embedding []float64) error
	Delete(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) error
	Search(ctx context.Context, userID uuid.UUID, query []float64, limit int) ([]domain.SemanticSearchHit, error)
	ListForUser(ctx context.Context, userID uuid.UUID) ([]domain.NoteEmbedding, error)
	GetUpdatedAt(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) (time.Time, error)
}

// SemanticSearchService indexes client-computed note vectors and answers
// nearest-neighbor queries. It never sees note text.
type SemanticSearchService interface {
	UpsertEmbedding(ctx context.Context, userID uuid.UUID, noteID uuid.UUID, lang string, embedding []float64) error
	DeleteEmbedding(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) error
	Search(ctx context.Context, userID uuid.UUID, query []float64, limit int) ([]domain.SemanticSearchHit, error)
	ListEmbeddings(ctx context.Context, userID uuid.UUID) ([]domain.NoteEmbedding, error)
}

type semanticSearchService struct {
	repo SemanticSearchRepository
}

func NewSemanticSearchService(repo SemanticSearchRepository) SemanticSearchService {
	return &semanticSearchService{repo: repo}
}

// validateEmbedding enforces a sane, finite vector.
func validateEmbedding(v []float64) error {
	if len(v) < MinEmbeddingDim || len(v) > MaxEmbeddingDim {
		return ErrInvalidEmbedding
	}
	for _, f := range v {
		if math.IsNaN(f) || math.IsInf(f, 0) {
			return ErrInvalidEmbedding
		}
	}
	return nil
}

func (s *semanticSearchService) UpsertEmbedding(ctx context.Context, userID uuid.UUID, noteID uuid.UUID, lang string, embedding []float64) error {
	if err := validateEmbedding(embedding); err != nil {
		return err
	}
	return s.repo.Upsert(ctx, userID, noteID, lang, embedding)
}

func (s *semanticSearchService) DeleteEmbedding(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) error {
	return s.repo.Delete(ctx, userID, noteID)
}

func (s *semanticSearchService) Search(ctx context.Context, userID uuid.UUID, query []float64, limit int) ([]domain.SemanticSearchHit, error) {
	if err := validateEmbedding(query); err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = DefaultSearchK
	}
	if limit > MaxSearchK {
		limit = MaxSearchK
	}
	return s.repo.Search(ctx, userID, query, limit)
}

func (s *semanticSearchService) ListEmbeddings(ctx context.Context, userID uuid.UUID) ([]domain.NoteEmbedding, error) {
	return s.repo.ListForUser(ctx, userID)
}
