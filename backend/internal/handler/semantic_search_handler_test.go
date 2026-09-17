package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

type mockSemanticRepo struct {
	upsertCalled bool
	upsertErr    error
	searchHits   []domain.SemanticSearchHit
	searchErr    error
	deleted      []uuid.UUID
	list         []domain.NoteEmbedding
}

func (m *mockSemanticRepo) Upsert(_ context.Context, _ uuid.UUID, _ uuid.UUID, _ string, _ []float64) error {
	m.upsertCalled = true
	return m.upsertErr
}

func (m *mockSemanticRepo) Delete(_ context.Context, _ uuid.UUID, noteID uuid.UUID) error {
	m.deleted = append(m.deleted, noteID)
	return nil
}

func (m *mockSemanticRepo) Search(_ context.Context, _ uuid.UUID, _ []float64, _ int) ([]domain.SemanticSearchHit, error) {
	return m.searchHits, m.searchErr
}

func (m *mockSemanticRepo) ListForUser(_ context.Context, _ uuid.UUID) ([]domain.NoteEmbedding, error) {
	return m.list, nil
}

func (m *mockSemanticRepo) GetUpdatedAt(_ context.Context, _ uuid.UUID, _ uuid.UUID) (time.Time, error) {
	return time.Time{}, errors.New("embedding not found")
}

// newAuthRequest builds a request with the user_id context value set,
// simulating what AuthMiddleware does for authenticated requests.
func newAuthRequest(method, path string, body interface{}) *http.Request {
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req := httptest.NewRequest(method, path, &buf)
	req = req.WithContext(ctxWithUserID(uuid.New().String()))
	return req
}

func TestSemanticSearchHandler_SearchValidation(t *testing.T) {
	h := NewSemanticSearchHandler(service.NewSemanticSearchService(&mockSemanticRepo{}))

	// NaN in the query vector must be rejected with 400.
	req := newAuthRequest(http.MethodPost, "/search/semantic", domain.SemanticSearchRequest{
		QueryVector: []float64{math.NaN(), 1},
	})
	rr := httptest.NewRecorder()
	h.Search(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("NaN query: status = %d, want 400", rr.Code)
	}

	// Empty vector must be rejected too.
	req = newAuthRequest(http.MethodPost, "/search/semantic", domain.SemanticSearchRequest{})
	rr = httptest.NewRecorder()
	h.Search(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("empty query: status = %d, want 400", rr.Code)
	}
}

func TestSemanticSearchHandler_SearchReturnsHits(t *testing.T) {
	noteID := uuid.New()
	repo := &mockSemanticRepo{
		searchHits: []domain.SemanticSearchHit{{NoteID: noteID, Distance: 0.25}},
	}
	h := NewSemanticSearchHandler(service.NewSemanticSearchService(repo))

	req := newAuthRequest(http.MethodPost, "/search/semantic", domain.SemanticSearchRequest{
		QueryVector: []float64{0.1, 0.2, 0.3},
		Limit:       5,
	})
	rr := httptest.NewRecorder()
	h.Search(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d, body: %s", rr.Code, rr.Body.String())
	}
	var resp domain.SemanticSearchResponse
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(resp.Hits) != 1 || resp.Hits[0].NoteID != noteID || resp.Hits[0].Distance != 0.25 {
		t.Errorf("hits = %+v, want one hit for %s at 0.25", resp.Hits, noteID)
	}
}

func TestSemanticSearchHandler_UpsertValidates(t *testing.T) {
	repo := &mockSemanticRepo{}
	h := NewSemanticSearchHandler(service.NewSemanticSearchService(repo))

	// Oversized vector is rejected before touching storage.
	big := make([]float64, 4097)
	req := newAuthRequest(http.MethodPut, "/search/embeddings", domain.UpsertEmbeddingRequest{
		NoteID:    uuid.New(),
		Embedding: big,
	})
	rr := httptest.NewRecorder()
	h.UpsertEmbedding(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("oversized vector: status = %d, want 400", rr.Code)
	}
	if repo.upsertCalled {
		t.Error("repo must not be called for invalid vectors")
	}

	// A valid vector reaches the repo.
	req = newAuthRequest(http.MethodPut, "/search/embeddings", domain.UpsertEmbeddingRequest{
		NoteID:    uuid.New(),
		Lang:      "zh",
		Embedding: []float64{0.5, -0.5},
	})
	rr = httptest.NewRecorder()
	h.UpsertEmbedding(rr, req)
	if rr.Code != http.StatusOK || !repo.upsertCalled {
		t.Errorf("valid upsert: status = %d, called = %v", rr.Code, repo.upsertCalled)
	}
}

func TestSemanticSearchHandler_DeleteEmbedding(t *testing.T) {
	repo := &mockSemanticRepo{}
	h := NewSemanticSearchHandler(service.NewSemanticSearchService(repo))

	noteID := uuid.New()
	req := newAuthRequest(http.MethodDelete, "/search/embeddings/"+noteID.String(), nil)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("noteId", noteID.String())
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))

	rr := httptest.NewRecorder()
	h.DeleteEmbedding(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
	if len(repo.deleted) != 1 || repo.deleted[0] != noteID {
		t.Errorf("deleted = %v, want [%s]", repo.deleted, noteID)
	}

	// Invalid id → 400.
	req = newAuthRequest(http.MethodDelete, "/search/embeddings/not-a-uuid", nil)
	rctx = chi.NewRouteContext()
	rctx.URLParams.Add("noteId", "not-a-uuid")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))
	rr = httptest.NewRecorder()
	h.DeleteEmbedding(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("invalid id: status = %d, want 400", rr.Code)
	}
}

func TestSemanticSearchService_RepoErrorPropagates(t *testing.T) {
	repo := &mockSemanticRepo{searchErr: errors.New("db down")}
	svc := service.NewSemanticSearchService(repo)
	if _, err := svc.Search(context.Background(), uuid.New(), []float64{1, 2}, 10); err == nil {
		t.Fatal("expected repo error to propagate")
	}
}

func TestSemanticSearchHandler_ListEmbeddings(t *testing.T) {
	repo := &mockSemanticRepo{}
	h := NewSemanticSearchHandler(service.NewSemanticSearchService(repo))

	// Empty list still serializes as a JSON array.
	req := newAuthRequest(http.MethodGet, "/search/embeddings", nil)
	rr := httptest.NewRecorder()
	h.ListEmbeddings(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status = %d", rr.Code)
	}
	var resp struct {
		Embeddings []domain.NoteEmbedding `json:"embeddings"`
	}
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp.Embeddings == nil || len(resp.Embeddings) != 0 {
		t.Errorf("embeddings = %+v, want empty non-nil array", resp.Embeddings)
	}
}
