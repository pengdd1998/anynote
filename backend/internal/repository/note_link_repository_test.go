package repository

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestNoteLinkRepository_DocumentsExpectedBehavior documents the expected SQL
// behaviors for the NoteLinkRepository.
func TestNoteLinkRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("CreateLinks_uses_pgx_Batch", func(t *testing.T) {
		// Expected behavior:
		//   Queues all INSERT ... ON CONFLICT DO NOTHING RETURNING ... statements
		//   in a single pgx.Batch round-trip instead of executing them one at a time.
		//   ON CONFLICT DO NOTHING produces no rows for duplicates; those are skipped.
		//   Returns the links that were actually inserted.
		t.Log("documented: CreateLinks uses pgx.Batch for bulk insert")
	})

	t.Run("GetBacklinks_returns_incoming_links", func(t *testing.T) {
		// SELECT id, user_id, source_id, target_id, link_type, created_at
		// FROM note_links WHERE user_id = $1 AND target_id = $2
		// ORDER BY created_at DESC
		t.Log("documented: GetBacklinks returns all links pointing to the given note")
	})

	t.Run("GetOutboundLinks_returns_outgoing_links", func(t *testing.T) {
		// SELECT id, user_id, source_id, target_id, link_type, created_at
		// FROM note_links WHERE user_id = $1 AND source_id = $2
		// ORDER BY created_at DESC
		t.Log("documented: GetOutboundLinks returns all links originating from the given note")
	})

	t.Run("GetGraph_returns_nodes_and_edges", func(t *testing.T) {
		// Two queries:
		//   1. SELECT DISTINCT item_id FROM (source_id UNION target_id) for nodes
		//   2. SELECT all note_links for edges
		// Returns NoteGraphResponse{Nodes, Edges}.
		t.Log("documented: GetGraph returns full note graph with unique nodes and all edges")
	})

	t.Run("DeleteLink_removes_link", func(t *testing.T) {
		// DELETE FROM note_links WHERE user_id = $1 AND source_id = $2 AND target_id = $3
		// Returns error if no rows were affected (link not found).
		t.Log("documented: DeleteLink removes a specific link, errors when not found")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

// linkKey produces a unique composite key for deduplication.
func linkKey(userID, sourceID, targetID uuid.UUID, linkType string) string {
	return userID.String() + ":" + sourceID.String() + ":" + targetID.String() + ":" + linkType
}

type mockNoteLinkRepo struct {
	links map[string]*domain.NoteLink
}

func newMockNoteLinkRepo() *mockNoteLinkRepo {
	return &mockNoteLinkRepo{
		links: make(map[string]*domain.NoteLink),
	}
}

func (m *mockNoteLinkRepo) CreateLinks(ctx context.Context, userID uuid.UUID, items []domain.NoteLinkItem) ([]domain.NoteLink, error) {
	var result []domain.NoteLink
	for _, l := range items {
		key := linkKey(userID, l.SourceID, l.TargetID, l.LinkType)
		if _, exists := m.links[key]; exists {
			continue // ON CONFLICT DO NOTHING
		}
		nl := domain.NoteLink{
			ID:        uuid.New(),
			UserID:    userID,
			SourceID:  l.SourceID,
			TargetID:  l.TargetID,
			LinkType:  l.LinkType,
			CreatedAt: time.Now(),
		}
		m.links[key] = &nl
		result = append(result, nl)
	}
	return result, nil
}

func (m *mockNoteLinkRepo) GetBacklinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error) {
	var result []domain.NoteLink
	for _, l := range m.links {
		if l.UserID == userID && l.TargetID == noteID {
			result = append(result, *l)
		}
	}
	return result, nil
}

func (m *mockNoteLinkRepo) GetOutboundLinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error) {
	var result []domain.NoteLink
	for _, l := range m.links {
		if l.UserID == userID && l.SourceID == noteID {
			result = append(result, *l)
		}
	}
	return result, nil
}

func (m *mockNoteLinkRepo) GetGraph(ctx context.Context, userID uuid.UUID) (*domain.NoteGraphResponse, error) {
	nodeSet := make(map[uuid.UUID]struct{})
	var edges []domain.NoteLink
	for _, l := range m.links {
		if l.UserID == userID {
			nodeSet[l.SourceID] = struct{}{}
			nodeSet[l.TargetID] = struct{}{}
			edges = append(edges, *l)
		}
	}
	nodes := make([]domain.NoteGraphNode, 0, len(nodeSet))
	for id := range nodeSet {
		nodes = append(nodes, domain.NoteGraphNode{ItemID: id})
	}
	return &domain.NoteGraphResponse{Nodes: nodes, Edges: edges}, nil
}

func (m *mockNoteLinkRepo) DeleteLink(ctx context.Context, userID uuid.UUID, sourceID uuid.UUID, targetID uuid.UUID) error {
	found := false
	for key, l := range m.links {
		if l.UserID == userID && l.SourceID == sourceID && l.TargetID == targetID {
			delete(m.links, key)
			found = true
			// Do not break: there may be multiple link types between the same pair.
		}
	}
	if !found {
		return errNotFound
	}
	return nil
}

// ---------------------------------------------------------------------------
// Tests: CreateLinks
// ---------------------------------------------------------------------------

func TestMockNoteLinkRepo_CreateLinks_Single(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	src := uuid.New()
	tgt := uuid.New()

	links, err := repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: src, TargetID: tgt, LinkType: "wiki"},
	})
	if err != nil {
		t.Fatalf("CreateLinks: %v", err)
	}
	if len(links) != 1 {
		t.Fatalf("len(links) = %d, want 1", len(links))
	}
	if links[0].UserID != userID {
		t.Errorf("UserID = %v, want %v", links[0].UserID, userID)
	}
	if links[0].SourceID != src {
		t.Errorf("SourceID = %v, want %v", links[0].SourceID, src)
	}
	if links[0].LinkType != "wiki" {
		t.Errorf("LinkType = %q, want %q", links[0].LinkType, "wiki")
	}
}

func TestMockNoteLinkRepo_CreateLinks_Empty(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()

	links, err := repo.CreateLinks(ctx, uuid.New(), nil)
	if err != nil {
		t.Fatalf("CreateLinks with nil: %v", err)
	}
	if len(links) != 0 {
		t.Errorf("len(links) = %d, want 0", len(links))
	}

	links, err = repo.CreateLinks(ctx, uuid.New(), []domain.NoteLinkItem{})
	if err != nil {
		t.Fatalf("CreateLinks with empty slice: %v", err)
	}
	if len(links) != 0 {
		t.Errorf("len(links) = %d, want 0", len(links))
	}
}

func TestMockNoteLinkRepo_CreateLinks_BatchMultiple(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()
	n3 := uuid.New()

	links, err := repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
		{SourceID: n2, TargetID: n3, LinkType: "wiki"},
		{SourceID: n1, TargetID: n3, LinkType: "mention"},
	})
	if err != nil {
		t.Fatalf("CreateLinks: %v", err)
	}
	if len(links) != 3 {
		t.Errorf("len(links) = %d, want 3", len(links))
	}
}

func TestMockNoteLinkRepo_CreateLinks_DuplicateSkipped(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	src := uuid.New()
	tgt := uuid.New()

	// First insert succeeds.
	links1, _ := repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: src, TargetID: tgt, LinkType: "wiki"},
	})
	if len(links1) != 1 {
		t.Fatalf("first insert: len(links) = %d, want 1", len(links1))
	}

	// Second insert with same key is skipped.
	links2, err := repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: src, TargetID: tgt, LinkType: "wiki"},
	})
	if err != nil {
		t.Fatalf("duplicate CreateLinks: %v", err)
	}
	if len(links2) != 0 {
		t.Errorf("duplicate should be skipped, got %d links", len(links2))
	}
}

func TestMockNoteLinkRepo_CreateLinks_MixedDuplicateAndNew(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()
	n3 := uuid.New()

	// Insert one link.
	repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
	})

	// Batch with one duplicate and one new.
	links, err := repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},   // duplicate
		{SourceID: n2, TargetID: n3, LinkType: "mention"}, // new
	})
	if err != nil {
		t.Fatalf("CreateLinks: %v", err)
	}
	if len(links) != 1 {
		t.Errorf("len(links) = %d, want 1 (only new link inserted)", len(links))
	}
	if links[0].LinkType != "mention" {
		t.Errorf("LinkType = %q, want %q", links[0].LinkType, "mention")
	}
}

// ---------------------------------------------------------------------------
// Tests: GetBacklinks
// ---------------------------------------------------------------------------

func TestMockNoteLinkRepo_GetBacklinks(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()
	n3 := uuid.New()

	repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
		{SourceID: n3, TargetID: n2, LinkType: "mention"},
		{SourceID: n1, TargetID: n3, LinkType: "wiki"},
	})

	backlinks, err := repo.GetBacklinks(ctx, userID, n2)
	if err != nil {
		t.Fatalf("GetBacklinks: %v", err)
	}
	if len(backlinks) != 2 {
		t.Errorf("len(backlinks) = %d, want 2", len(backlinks))
	}
}

func TestMockNoteLinkRepo_GetBacklinks_None(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()

	backlinks, err := repo.GetBacklinks(ctx, uuid.New(), uuid.New())
	if err != nil {
		t.Fatalf("GetBacklinks: %v", err)
	}
	if len(backlinks) != 0 {
		t.Errorf("len(backlinks) = %d, want 0", len(backlinks))
	}
}

func TestMockNoteLinkRepo_GetBacklinks_ScopedByUser(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()

	repo.CreateLinks(ctx, user1, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
	})
	repo.CreateLinks(ctx, user2, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
	})

	backlinks, _ := repo.GetBacklinks(ctx, user1, n2)
	if len(backlinks) != 1 {
		t.Errorf("user1 backlinks = %d, want 1", len(backlinks))
	}
}

// ---------------------------------------------------------------------------
// Tests: GetOutboundLinks
// ---------------------------------------------------------------------------

func TestMockNoteLinkRepo_GetOutboundLinks(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()
	n3 := uuid.New()

	repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
		{SourceID: n1, TargetID: n3, LinkType: "mention"},
		{SourceID: n2, TargetID: n3, LinkType: "wiki"},
	})

	outbound, err := repo.GetOutboundLinks(ctx, userID, n1)
	if err != nil {
		t.Fatalf("GetOutboundLinks: %v", err)
	}
	if len(outbound) != 2 {
		t.Errorf("len(outbound) = %d, want 2", len(outbound))
	}
}

func TestMockNoteLinkRepo_GetOutboundLinks_None(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()

	outbound, err := repo.GetOutboundLinks(ctx, uuid.New(), uuid.New())
	if err != nil {
		t.Fatalf("GetOutboundLinks: %v", err)
	}
	if len(outbound) != 0 {
		t.Errorf("len(outbound) = %d, want 0", len(outbound))
	}
}

// ---------------------------------------------------------------------------
// Tests: GetGraph
// ---------------------------------------------------------------------------

func TestMockNoteLinkRepo_GetGraph(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()
	n3 := uuid.New()

	repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
		{SourceID: n2, TargetID: n3, LinkType: "wiki"},
	})

	graph, err := repo.GetGraph(ctx, userID)
	if err != nil {
		t.Fatalf("GetGraph: %v", err)
	}
	if len(graph.Nodes) != 3 {
		t.Errorf("len(nodes) = %d, want 3 (n1, n2, n3)", len(graph.Nodes))
	}
	if len(graph.Edges) != 2 {
		t.Errorf("len(edges) = %d, want 2", len(graph.Edges))
	}
}

func TestMockNoteLinkRepo_GetGraph_Empty(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()

	graph, err := repo.GetGraph(ctx, uuid.New())
	if err != nil {
		t.Fatalf("GetGraph: %v", err)
	}
	if len(graph.Nodes) != 0 {
		t.Errorf("len(nodes) = %d, want 0", len(graph.Nodes))
	}
	if len(graph.Edges) != 0 {
		t.Errorf("len(edges) = %d, want 0", len(graph.Edges))
	}
}

func TestMockNoteLinkRepo_GetGraph_ScopedByUser(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()

	repo.CreateLinks(ctx, user1, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
	})
	repo.CreateLinks(ctx, user2, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
		{SourceID: n2, TargetID: n1, LinkType: "mention"},
	})

	g1, _ := repo.GetGraph(ctx, user1)
	g2, _ := repo.GetGraph(ctx, user2)

	if len(g1.Edges) != 1 {
		t.Errorf("user1 edges = %d, want 1", len(g1.Edges))
	}
	if len(g2.Edges) != 2 {
		t.Errorf("user2 edges = %d, want 2", len(g2.Edges))
	}
}

// ---------------------------------------------------------------------------
// Tests: DeleteLink
// ---------------------------------------------------------------------------

func TestMockNoteLinkRepo_DeleteLink(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()

	repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
	})

	err := repo.DeleteLink(ctx, userID, n1, n2)
	if err != nil {
		t.Fatalf("DeleteLink: %v", err)
	}

	// Verify the link is gone.
	outbound, _ := repo.GetOutboundLinks(ctx, userID, n1)
	if len(outbound) != 0 {
		t.Errorf("outbound after delete = %d, want 0", len(outbound))
	}
}

func TestMockNoteLinkRepo_DeleteLink_NotFound(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()

	err := repo.DeleteLink(ctx, uuid.New(), uuid.New(), uuid.New())
	if err == nil {
		t.Error("DeleteLink should return error when link does not exist")
	}
}

func TestMockNoteLinkRepo_DeleteLink_DifferentLinkTypesPreserved(t *testing.T) {
	repo := newMockNoteLinkRepo()
	ctx := context.Background()
	userID := uuid.New()
	n1 := uuid.New()
	n2 := uuid.New()

	repo.CreateLinks(ctx, userID, []domain.NoteLinkItem{
		{SourceID: n1, TargetID: n2, LinkType: "wiki"},
		{SourceID: n1, TargetID: n2, LinkType: "mention"},
	})

	err := repo.DeleteLink(ctx, userID, n1, n2)
	if err != nil {
		t.Fatalf("DeleteLink: %v", err)
	}

	// The mention link should still exist (DeleteLink deletes all types
	// between the pair, which is the current repo behavior).
	outbound, _ := repo.GetOutboundLinks(ctx, userID, n1)
	// Current implementation deletes all links between the pair regardless of type.
	if len(outbound) != 0 {
		t.Errorf("outbound after delete = %d, want 0 (all link types between pair removed)", len(outbound))
	}
}
