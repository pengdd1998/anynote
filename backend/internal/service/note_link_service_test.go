package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock NoteLinkRepository
// ---------------------------------------------------------------------------

type mockNoteLinkRepo struct {
	createLinksFn     func(ctx context.Context, userID uuid.UUID, links []domain.NoteLinkItem) ([]domain.NoteLink, error)
	getBacklinksFn    func(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error)
	getOutboundFn     func(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error)
	getGraphFn        func(ctx context.Context, userID uuid.UUID) (*domain.NoteGraphResponse, error)
	deleteLinkFn      func(ctx context.Context, userID uuid.UUID, sourceID uuid.UUID, targetID uuid.UUID) error
}

func (m *mockNoteLinkRepo) CreateLinks(ctx context.Context, userID uuid.UUID, links []domain.NoteLinkItem) ([]domain.NoteLink, error) {
	if m.createLinksFn != nil {
		return m.createLinksFn(ctx, userID, links)
	}
	return nil, nil
}

func (m *mockNoteLinkRepo) GetBacklinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error) {
	if m.getBacklinksFn != nil {
		return m.getBacklinksFn(ctx, userID, noteID)
	}
	return nil, nil
}

func (m *mockNoteLinkRepo) GetOutboundLinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error) {
	if m.getOutboundFn != nil {
		return m.getOutboundFn(ctx, userID, noteID)
	}
	return nil, nil
}

func (m *mockNoteLinkRepo) GetGraph(ctx context.Context, userID uuid.UUID) (*domain.NoteGraphResponse, error) {
	if m.getGraphFn != nil {
		return m.getGraphFn(ctx, userID)
	}
	return nil, nil
}

func (m *mockNoteLinkRepo) DeleteLink(ctx context.Context, userID uuid.UUID, sourceID uuid.UUID, targetID uuid.UUID) error {
	if m.deleteLinkFn != nil {
		return m.deleteLinkFn(ctx, userID, sourceID, targetID)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Tests: CreateLinks
// ---------------------------------------------------------------------------

func TestNoteLinkService_CreateLinks_Success(t *testing.T) {
	userID := uuid.New()
	sourceID := uuid.New()
	targetID := uuid.New()

	repo := &mockNoteLinkRepo{
		createLinksFn: func(_ context.Context, uid uuid.UUID, links []domain.NoteLinkItem) ([]domain.NoteLink, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if len(links) != 1 {
				t.Fatalf("links count = %d, want 1", len(links))
			}
			if links[0].SourceID != sourceID {
				t.Errorf("SourceID = %v, want %v", links[0].SourceID, sourceID)
			}
			if links[0].TargetID != targetID {
				t.Errorf("TargetID = %v, want %v", links[0].TargetID, targetID)
			}
			return []domain.NoteLink{
				{
					ID:        uuid.New(),
					UserID:    uid,
					SourceID:  sourceID,
					TargetID:  targetID,
					LinkType:  "markdown",
					CreatedAt: time.Now(),
				},
			}, nil
		},
	}

	svc := NewNoteLinkService(repo)
	links, err := svc.CreateLinks(context.Background(), userID, []domain.NoteLinkItem{
		{SourceID: sourceID, TargetID: targetID, LinkType: "markdown"},
	})
	if err != nil {
		t.Fatalf("CreateLinks: %v", err)
	}
	if len(links) != 1 {
		t.Errorf("links count = %d, want 1", len(links))
	}
}

func TestNoteLinkService_CreateLinks_Multiple(t *testing.T) {
	userID := uuid.New()

	repo := &mockNoteLinkRepo{
		createLinksFn: func(_ context.Context, _ uuid.UUID, links []domain.NoteLinkItem) ([]domain.NoteLink, error) {
			result := make([]domain.NoteLink, len(links))
			for i, l := range links {
				result[i] = domain.NoteLink{
					ID:       uuid.New(),
					UserID:   userID,
					SourceID: l.SourceID,
					TargetID: l.TargetID,
					LinkType: l.LinkType,
				}
			}
			return result, nil
		},
	}

	svc := NewNoteLinkService(repo)
	items := []domain.NoteLinkItem{
		{SourceID: uuid.New(), TargetID: uuid.New(), LinkType: "markdown"},
		{SourceID: uuid.New(), TargetID: uuid.New(), LinkType: "wiki"},
		{SourceID: uuid.New(), TargetID: uuid.New(), LinkType: "embed"},
	}

	links, err := svc.CreateLinks(context.Background(), userID, items)
	if err != nil {
		t.Fatalf("CreateLinks: %v", err)
	}
	if len(links) != 3 {
		t.Errorf("links count = %d, want 3", len(links))
	}
}

func TestNoteLinkService_CreateLinks_RepoError(t *testing.T) {
	userID := uuid.New()

	repo := &mockNoteLinkRepo{
		createLinksFn: func(_ context.Context, _ uuid.UUID, _ []domain.NoteLinkItem) ([]domain.NoteLink, error) {
			return nil, errors.New("db connection lost")
		},
	}

	svc := NewNoteLinkService(repo)
	_, err := svc.CreateLinks(context.Background(), userID, []domain.NoteLinkItem{
		{SourceID: uuid.New(), TargetID: uuid.New(), LinkType: "markdown"},
	})
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

func TestNoteLinkService_CreateLinks_Empty(t *testing.T) {
	userID := uuid.New()
	called := false

	repo := &mockNoteLinkRepo{
		createLinksFn: func(_ context.Context, _ uuid.UUID, _ []domain.NoteLinkItem) ([]domain.NoteLink, error) {
			called = true
			return nil, nil
		},
	}

	svc := NewNoteLinkService(repo)
	links, err := svc.CreateLinks(context.Background(), userID, []domain.NoteLinkItem{})
	if err != nil {
		t.Fatalf("CreateLinks: %v", err)
	}
	if !called {
		t.Error("repo should have been called even with empty input")
	}
	if links != nil {
		t.Errorf("links = %v, want nil", links)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetBacklinks
// ---------------------------------------------------------------------------

func TestNoteLinkService_GetBacklinks_Success(t *testing.T) {
	userID := uuid.New()
	noteID := uuid.New()
	backlinkSource := uuid.New()

	repo := &mockNoteLinkRepo{
		getBacklinksFn: func(_ context.Context, uid uuid.UUID, nid uuid.UUID) ([]domain.NoteLink, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if nid != noteID {
				t.Errorf("noteID = %v, want %v", nid, noteID)
			}
			return []domain.NoteLink{
				{
					ID:        uuid.New(),
					UserID:    userID,
					SourceID:  backlinkSource,
					TargetID:  noteID,
					LinkType:  "markdown",
					CreatedAt: time.Now(),
				},
			}, nil
		},
	}

	svc := NewNoteLinkService(repo)
	links, err := svc.GetBacklinks(context.Background(), userID, noteID)
	if err != nil {
		t.Fatalf("GetBacklinks: %v", err)
	}
	if len(links) != 1 {
		t.Errorf("links count = %d, want 1", len(links))
	}
	if links[0].TargetID != noteID {
		t.Errorf("TargetID = %v, want %v (the note we asked about)", links[0].TargetID, noteID)
	}
}

func TestNoteLinkService_GetBacklinks_NoBacklinks(t *testing.T) {
	userID := uuid.New()
	noteID := uuid.New()

	repo := &mockNoteLinkRepo{
		getBacklinksFn: func(_ context.Context, _ uuid.UUID, _ uuid.UUID) ([]domain.NoteLink, error) {
			return []domain.NoteLink{}, nil
		},
	}

	svc := NewNoteLinkService(repo)
	links, err := svc.GetBacklinks(context.Background(), userID, noteID)
	if err != nil {
		t.Fatalf("GetBacklinks: %v", err)
	}
	if len(links) != 0 {
		t.Errorf("links count = %d, want 0", len(links))
	}
}

func TestNoteLinkService_GetBacklinks_RepoError(t *testing.T) {
	repo := &mockNoteLinkRepo{
		getBacklinksFn: func(_ context.Context, _ uuid.UUID, _ uuid.UUID) ([]domain.NoteLink, error) {
			return nil, errors.New("db error")
		},
	}

	svc := NewNoteLinkService(repo)
	_, err := svc.GetBacklinks(context.Background(), uuid.New(), uuid.New())
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetOutboundLinks
// ---------------------------------------------------------------------------

func TestNoteLinkService_GetOutboundLinks_Success(t *testing.T) {
	userID := uuid.New()
	noteID := uuid.New()
	target1 := uuid.New()
	target2 := uuid.New()

	repo := &mockNoteLinkRepo{
		getOutboundFn: func(_ context.Context, uid uuid.UUID, nid uuid.UUID) ([]domain.NoteLink, error) {
			return []domain.NoteLink{
				{ID: uuid.New(), UserID: uid, SourceID: nid, TargetID: target1, LinkType: "markdown"},
				{ID: uuid.New(), UserID: uid, SourceID: nid, TargetID: target2, LinkType: "wiki"},
			}, nil
		},
	}

	svc := NewNoteLinkService(repo)
	links, err := svc.GetOutboundLinks(context.Background(), userID, noteID)
	if err != nil {
		t.Fatalf("GetOutboundLinks: %v", err)
	}
	if len(links) != 2 {
		t.Errorf("links count = %d, want 2", len(links))
	}
}

func TestNoteLinkService_GetOutboundLinks_RepoError(t *testing.T) {
	repo := &mockNoteLinkRepo{
		getOutboundFn: func(_ context.Context, _ uuid.UUID, _ uuid.UUID) ([]domain.NoteLink, error) {
			return nil, errors.New("db error")
		},
	}

	svc := NewNoteLinkService(repo)
	_, err := svc.GetOutboundLinks(context.Background(), uuid.New(), uuid.New())
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetGraph
// ---------------------------------------------------------------------------

func TestNoteLinkService_GetGraph_Success(t *testing.T) {
	userID := uuid.New()
	node1 := uuid.New()
	node2 := uuid.New()

	repo := &mockNoteLinkRepo{
		getGraphFn: func(_ context.Context, uid uuid.UUID) (*domain.NoteGraphResponse, error) {
			return &domain.NoteGraphResponse{
				Nodes: []domain.NoteGraphNode{
					{ItemID: node1},
					{ItemID: node2},
				},
				Edges: []domain.NoteLink{
					{ID: uuid.New(), UserID: uid, SourceID: node1, TargetID: node2, LinkType: "markdown"},
				},
			}, nil
		},
	}

	svc := NewNoteLinkService(repo)
	graph, err := svc.GetGraph(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetGraph: %v", err)
	}
	if len(graph.Nodes) != 2 {
		t.Errorf("nodes count = %d, want 2", len(graph.Nodes))
	}
	if len(graph.Edges) != 1 {
		t.Errorf("edges count = %d, want 1", len(graph.Edges))
	}
}

func TestNoteLinkService_GetGraph_Empty(t *testing.T) {
	repo := &mockNoteLinkRepo{
		getGraphFn: func(_ context.Context, _ uuid.UUID) (*domain.NoteGraphResponse, error) {
			return &domain.NoteGraphResponse{
				Nodes: []domain.NoteGraphNode{},
				Edges: []domain.NoteLink{},
			}, nil
		},
	}

	svc := NewNoteLinkService(repo)
	graph, err := svc.GetGraph(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("GetGraph: %v", err)
	}
	if len(graph.Nodes) != 0 {
		t.Errorf("nodes count = %d, want 0", len(graph.Nodes))
	}
	if len(graph.Edges) != 0 {
		t.Errorf("edges count = %d, want 0", len(graph.Edges))
	}
}

func TestNoteLinkService_GetGraph_RepoError(t *testing.T) {
	repo := &mockNoteLinkRepo{
		getGraphFn: func(_ context.Context, _ uuid.UUID) (*domain.NoteGraphResponse, error) {
			return nil, errors.New("db error")
		},
	}

	svc := NewNoteLinkService(repo)
	_, err := svc.GetGraph(context.Background(), uuid.New())
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: DeleteLink
// ---------------------------------------------------------------------------

func TestNoteLinkService_DeleteLink_Success(t *testing.T) {
	userID := uuid.New()
	sourceID := uuid.New()
	targetID := uuid.New()

	var capturedSource, capturedTarget uuid.UUID
	repo := &mockNoteLinkRepo{
		deleteLinkFn: func(_ context.Context, uid uuid.UUID, sid uuid.UUID, tid uuid.UUID) error {
			capturedSource = sid
			capturedTarget = tid
			return nil
		},
	}

	svc := NewNoteLinkService(repo)
	err := svc.DeleteLink(context.Background(), userID, sourceID, targetID)
	if err != nil {
		t.Fatalf("DeleteLink: %v", err)
	}
	if capturedSource != sourceID {
		t.Errorf("sourceID = %v, want %v", capturedSource, sourceID)
	}
	if capturedTarget != targetID {
		t.Errorf("targetID = %v, want %v", capturedTarget, targetID)
	}
}

func TestNoteLinkService_DeleteLink_RepoError(t *testing.T) {
	repo := &mockNoteLinkRepo{
		deleteLinkFn: func(_ context.Context, _ uuid.UUID, _ uuid.UUID, _ uuid.UUID) error {
			return errors.New("link not found")
		},
	}

	svc := NewNoteLinkService(repo)
	err := svc.DeleteLink(context.Background(), uuid.New(), uuid.New(), uuid.New())
	if err == nil {
		t.Error("expected error when repo fails")
	}
}
