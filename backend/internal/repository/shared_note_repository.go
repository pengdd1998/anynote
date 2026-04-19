package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

type SharedNoteRepository struct {
	pool *pgxpool.Pool
}

func NewSharedNoteRepository(pool *pgxpool.Pool) *SharedNoteRepository {
	return &SharedNoteRepository{pool: pool}
}

func (r *SharedNoteRepository) Create(ctx context.Context, note *domain.SharedNote) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO shared_notes (id, encrypted_content, encrypted_title, share_key_hash, has_password, is_public, expires_at, max_views, created_by)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		note.ID, note.EncryptedContent, note.EncryptedTitle, note.ShareKeyHash,
		note.HasPassword, note.IsPublic, note.ExpiresAt, note.MaxViews, note.CreatedBy,
	)
	return err
}

func (r *SharedNoteRepository) GetByID(ctx context.Context, id string) (*domain.SharedNote, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, encrypted_content, encrypted_title, share_key_hash, has_password, is_public, expires_at, view_count, max_views, reaction_heart, reaction_bookmark, created_by, created_at
		 FROM shared_notes WHERE id = $1`, id,
	)

	var note domain.SharedNote
	err := row.Scan(&note.ID, &note.EncryptedContent, &note.EncryptedTitle, &note.ShareKeyHash,
		&note.HasPassword, &note.IsPublic, &note.ExpiresAt, &note.ViewCount, &note.MaxViews,
		&note.ReactionHeart, &note.ReactionBookmark, &note.CreatedBy, &note.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &note, nil
}

func (r *SharedNoteRepository) IncrementViewCount(ctx context.Context, id string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE shared_notes SET view_count = view_count + 1 WHERE id = $1`, id,
	)
	return err
}

func (r *SharedNoteRepository) DeleteExpired(ctx context.Context) (int64, error) {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM shared_notes WHERE expires_at IS NOT NULL AND expires_at < $1`,
		time.Now(),
	)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

func (r *SharedNoteRepository) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.SharedNote, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, encrypted_content, encrypted_title, share_key_hash, has_password, is_public, expires_at, view_count, max_views, reaction_heart, reaction_bookmark, created_by, created_at
		 FROM shared_notes WHERE created_by = $1 ORDER BY created_at DESC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notes []domain.SharedNote
	for rows.Next() {
		var n domain.SharedNote
		if err := rows.Scan(&n.ID, &n.EncryptedContent, &n.EncryptedTitle, &n.ShareKeyHash,
			&n.HasPassword, &n.IsPublic, &n.ExpiresAt, &n.ViewCount, &n.MaxViews,
			&n.ReactionHeart, &n.ReactionBookmark, &n.CreatedBy, &n.CreatedAt); err != nil {
			return nil, err
		}
		notes = append(notes, n)
	}
	return notes, rows.Err()
}

// ListPublic returns public shared notes for the discovery feed, paginated.
func (r *SharedNoteRepository) ListPublic(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, encrypted_title, has_password, view_count, reaction_heart, reaction_bookmark, created_at
		 FROM shared_notes
		 WHERE is_public = TRUE AND (expires_at IS NULL OR expires_at > NOW())
		 ORDER BY created_at DESC
		 LIMIT $1 OFFSET $2`, limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.DiscoverFeedItem
	for rows.Next() {
		var item domain.DiscoverFeedItem
		if err := rows.Scan(&item.ID, &item.EncryptedTitle, &item.HasPassword,
			&item.ViewCount, &item.ReactionHeart, &item.ReactionBookmark, &item.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// React toggles a reaction on a shared note for a user.
// If the reaction already exists it is removed (unlike), otherwise it is added (like).
// Returns the new state and count.
func (r *SharedNoteRepository) React(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error) {
	// Map reaction type to column names.
	var counterCol string
	switch reactionType {
	case "heart":
		counterCol = "reaction_heart"
	case "bookmark":
		counterCol = "reaction_bookmark"
	default:
		return nil, domain.ErrInvalidReaction
	}

	// Check if the reaction already exists.
	var existingID string
	err := r.pool.QueryRow(ctx,
		`SELECT id FROM note_reactions WHERE shared_note_id = $1 AND user_id = $2 AND reaction_type = $3`,
		sharedNoteID, userID, reactionType,
	).Scan(&existingID)

	if err == nil {
		// Reaction exists -- remove it (toggle off).
		_, err = r.pool.Exec(ctx,
			`DELETE FROM note_reactions WHERE id = $1`, existingID,
		)
		if err != nil {
			return nil, err
		}
		// Decrement the denormalized counter.
		_, err = r.pool.Exec(ctx,
			`UPDATE shared_notes SET `+counterCol+` = GREATEST(`+counterCol+` - 1, 0) WHERE id = $1`,
			sharedNoteID,
		)
		if err != nil {
			return nil, err
		}
		// Read the new count.
		var newCount int
		err = r.pool.QueryRow(ctx,
			`SELECT `+counterCol+` FROM shared_notes WHERE id = $1`, sharedNoteID,
		).Scan(&newCount)
		if err != nil {
			return nil, err
		}
		return &domain.ReactResponse{
			ReactionType: reactionType,
			Active:       false,
			Count:        newCount,
		}, nil
	}

	// Reaction does not exist -- add it.
	_, err = r.pool.Exec(ctx,
		`INSERT INTO note_reactions (shared_note_id, user_id, reaction_type) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
		sharedNoteID, userID, reactionType,
	)
	if err != nil {
		return nil, err
	}
	// Increment the denormalized counter.
	_, err = r.pool.Exec(ctx,
		`UPDATE shared_notes SET `+counterCol+` = `+counterCol+` + 1 WHERE id = $1`,
		sharedNoteID,
	)
	if err != nil {
		return nil, err
	}
	// Read the new count.
	var newCount int
	err = r.pool.QueryRow(ctx,
		`SELECT `+counterCol+` FROM shared_notes WHERE id = $1`, sharedNoteID,
	).Scan(&newCount)
	if err != nil {
		return nil, err
	}
	return &domain.ReactResponse{
		ReactionType: reactionType,
		Active:       true,
		Count:        newCount,
	}, nil
}

// GetUserReaction returns the reaction state for a user on a specific shared note.
func (r *SharedNoteRepository) GetUserReaction(ctx context.Context, sharedNoteID string, userID uuid.UUID) (map[string]bool, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT reaction_type FROM note_reactions WHERE shared_note_id = $1 AND user_id = $2`,
		sharedNoteID, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	reactions := map[string]bool{}
	for rows.Next() {
		var rt string
		if err := rows.Scan(&rt); err != nil {
			return nil, err
		}
		reactions[rt] = true
	}
	return reactions, rows.Err()
}
