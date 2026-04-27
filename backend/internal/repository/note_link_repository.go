package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

// NoteLinkRepository manages note link data in PostgreSQL.
type NoteLinkRepository struct {
	pool *pgxpool.Pool
}

// NewNoteLinkRepository creates a new NoteLinkRepository.
func NewNoteLinkRepository(pool *pgxpool.Pool) *NoteLinkRepository {
	return &NoteLinkRepository{pool: pool}
}

// CreateLinks inserts a batch of note links using pgx.Batch for a single
// round-trip, ignoring duplicates.
func (r *NoteLinkRepository) CreateLinks(ctx context.Context, userID uuid.UUID, links []domain.NoteLinkItem) ([]domain.NoteLink, error) {
	if len(links) == 0 {
		return []domain.NoteLink{}, nil
	}

	batch := &pgx.Batch{}
	for _, l := range links {
		batch.Queue(
			`INSERT INTO note_links (user_id, source_id, target_id, link_type)
			 VALUES ($1, $2, $3, $4)
			 ON CONFLICT (user_id, source_id, target_id, link_type) DO NOTHING
			 RETURNING id, user_id, source_id, target_id, link_type, created_at`,
			userID, l.SourceID, l.TargetID, l.LinkType,
		)
	}

	br := r.pool.SendBatch(ctx, batch)
	defer br.Close()

	result := make([]domain.NoteLink, 0, len(links))
	for range links {
		var nl domain.NoteLink
		err := br.QueryRow().Scan(&nl.ID, &nl.UserID, &nl.SourceID, &nl.TargetID, &nl.LinkType, &nl.CreatedAt)
		if err != nil {
			// ON CONFLICT DO NOTHING returns no rows; skip.
			if errors.Is(err, pgx.ErrNoRows) {
				continue
			}
			return nil, fmt.Errorf("create note link: %w", err)
		}
		result = append(result, nl)
	}
	return result, nil
}

// GetBacklinks returns all links pointing to the given note.
func (r *NoteLinkRepository) GetBacklinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, source_id, target_id, link_type, created_at
		 FROM note_links
		 WHERE user_id = $1 AND target_id = $2
		 ORDER BY created_at DESC`,
		userID, noteID,
	)
	if err != nil {
		return nil, fmt.Errorf("get backlinks: %w", err)
	}
	defer rows.Close()

	var links []domain.NoteLink
	for rows.Next() {
		var nl domain.NoteLink
		if err := rows.Scan(&nl.ID, &nl.UserID, &nl.SourceID, &nl.TargetID, &nl.LinkType, &nl.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan backlink: %w", err)
		}
		links = append(links, nl)
	}
	return links, rows.Err()
}

// GetOutboundLinks returns all links originating from the given note.
func (r *NoteLinkRepository) GetOutboundLinks(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) ([]domain.NoteLink, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, source_id, target_id, link_type, created_at
		 FROM note_links
		 WHERE user_id = $1 AND source_id = $2
		 ORDER BY created_at DESC`,
		userID, noteID,
	)
	if err != nil {
		return nil, fmt.Errorf("get outbound links: %w", err)
	}
	defer rows.Close()

	var links []domain.NoteLink
	for rows.Next() {
		var nl domain.NoteLink
		if err := rows.Scan(&nl.ID, &nl.UserID, &nl.SourceID, &nl.TargetID, &nl.LinkType, &nl.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan outbound link: %w", err)
		}
		links = append(links, nl)
	}
	return links, rows.Err()
}

// GetGraph returns the full note graph (all nodes and edges) for a user.
func (r *NoteLinkRepository) GetGraph(ctx context.Context, userID uuid.UUID) (*domain.NoteGraphResponse, error) {
	// Get unique node IDs from both source and target sides.
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT item_id FROM (
		     SELECT source_id AS item_id FROM note_links WHERE user_id = $1
		     UNION
		     SELECT target_id AS item_id FROM note_links WHERE user_id = $1
		 ) sub`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("get graph nodes: %w", err)
	}
	defer rows.Close()

	var nodes []domain.NoteGraphNode
	for rows.Next() {
		var n domain.NoteGraphNode
		if err := rows.Scan(&n.ItemID); err != nil {
			return nil, fmt.Errorf("scan graph node: %w", err)
		}
		nodes = append(nodes, n)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Get all edges.
	linkRows, err := r.pool.Query(ctx,
		`SELECT id, user_id, source_id, target_id, link_type, created_at
		 FROM note_links WHERE user_id = $1
		 ORDER BY created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("get graph edges: %w", err)
	}
	defer linkRows.Close()

	var edges []domain.NoteLink
	for linkRows.Next() {
		var nl domain.NoteLink
		if err := linkRows.Scan(&nl.ID, &nl.UserID, &nl.SourceID, &nl.TargetID, &nl.LinkType, &nl.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan graph edge: %w", err)
		}
		edges = append(edges, nl)
	}

	return &domain.NoteGraphResponse{Nodes: nodes, Edges: edges}, linkRows.Err()
}

// DeleteLink removes a specific link between two notes.
func (r *NoteLinkRepository) DeleteLink(ctx context.Context, userID uuid.UUID, sourceID uuid.UUID, targetID uuid.UUID) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM note_links WHERE user_id = $1 AND source_id = $2 AND target_id = $3`,
		userID, sourceID, targetID,
	)
	if err != nil {
		return fmt.Errorf("delete note link: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("note link not found")
	}
	return nil
}
