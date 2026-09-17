package service

import (
	"context"
	"errors"
	"math"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

type fakeSemanticRepo struct {
	upserts []uuid.UUID
	list    []domain.NoteEmbedding
}

func (f *fakeSemanticRepo) Upsert(_ context.Context, _ uuid.UUID, noteID uuid.UUID, _ string, _ []float64) error {
	f.upserts = append(f.upserts, noteID)
	return nil
}

func (f *fakeSemanticRepo) Delete(_ context.Context, _ uuid.UUID, _ uuid.UUID) error { return nil }

func (f *fakeSemanticRepo) Search(_ context.Context, _ uuid.UUID, _ []float64, limit int) ([]domain.SemanticSearchHit, error) {
	// Echo the limit so tests can assert clamping.
	return []domain.SemanticSearchHit{{NoteID: uuid.New(), Distance: float64(limit)}}, nil
}

func (f *fakeSemanticRepo) ListForUser(_ context.Context, _ uuid.UUID) ([]domain.NoteEmbedding, error) {
	return f.list, nil
}

func (f *fakeSemanticRepo) GetUpdatedAt(_ context.Context, _ uuid.UUID, _ uuid.UUID) (time.Time, error) {
	return time.Time{}, errors.New("not found")
}

func TestSemanticSearchService_UpsertValidation(t *testing.T) {
	repo := &fakeSemanticRepo{}
	svc := NewSemanticSearchService(repo)
	userID := uuid.New()

	cases := []struct {
		name string
		vec  []float64
	}{
		{"empty", nil},
		{"too large", make([]float64, MaxEmbeddingDim+1)},
		{"nan", []float64{math.NaN()}},
		{"inf", []float64{math.Inf(1)}},
	}
	for _, tc := range cases {
		if err := svc.UpsertEmbedding(context.Background(), userID, uuid.New(), "", tc.vec); !errors.Is(err, ErrInvalidEmbedding) {
			t.Errorf("%s: err = %v, want ErrInvalidEmbedding", tc.name, err)
		}
	}
	if len(repo.upserts) != 0 {
		t.Errorf("repo called %d times for invalid vectors", len(repo.upserts))
	}

	if err := svc.UpsertEmbedding(context.Background(), userID, uuid.New(), "zh", []float64{0.1, 0.2}); err != nil {
		t.Errorf("valid upsert: %v", err)
	}
	if len(repo.upserts) != 1 {
		t.Errorf("upserts = %d, want 1", len(repo.upserts))
	}
}

func TestSemanticSearchService_SearchLimitClamping(t *testing.T) {
	svc := NewSemanticSearchService(&fakeSemanticRepo{})
	ctx := context.Background()
	userID := uuid.New()

	for _, tc := range []struct{ requested, want int }{
		{0, DefaultSearchK},
		{-5, DefaultSearchK},
		{999, MaxSearchK},
		{7, 7},
	} {
		hits, err := svc.Search(ctx, userID, []float64{1, 2}, tc.requested)
		if err != nil {
			t.Fatalf("search(%d): %v", tc.requested, err)
		}
		if len(hits) != 1 || int(hits[0].Distance) != tc.want {
			t.Errorf("search(%d) effective limit = %v, want %d", tc.requested, hits[0].Distance, tc.want)
		}
	}

	if _, err := svc.Search(ctx, userID, []float64{}, 10); !errors.Is(err, ErrInvalidEmbedding) {
		t.Errorf("empty query: err = %v, want ErrInvalidEmbedding", err)
	}
}

func TestSemanticSearchService_DeleteAndList(t *testing.T) {
	repo := &fakeSemanticRepo{list: []domain.NoteEmbedding{{Dim: 1024}}}
	svc := NewSemanticSearchService(repo)
	ctx := context.Background()

	if err := svc.DeleteEmbedding(ctx, uuid.New(), uuid.New()); err != nil {
		t.Errorf("delete: %v", err)
	}
	list, err := svc.ListEmbeddings(ctx, uuid.New())
	if err != nil || len(list) != 1 {
		t.Errorf("list = %v, err = %v", list, err)
	}
}
