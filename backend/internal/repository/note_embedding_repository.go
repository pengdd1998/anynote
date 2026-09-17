package repository

import (
	"context"
	"errors"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

// ErrEmbeddingNotFound is returned when the user has no embedding for the
// requested note.
var ErrEmbeddingNotFound = errors.New("embedding not found")

// NoteEmbeddingRepository stores and queries client-computed note vectors.
//
// Vectors travel as pgvector's text literal ('[0.1,0.2]') and are cast with
// ::vector in SQL. The literal is built exclusively from strconv-formatted
// finite floats, so no user-controlled text ever reaches the parser.
type NoteEmbeddingRepository struct {
	pool *pgxpool.Pool
}

func NewNoteEmbeddingRepository(pool *pgxpool.Pool) *NoteEmbeddingRepository {
	return &NoteEmbeddingRepository{pool: pool}
}

// Upsert inserts or refreshes the embedding for one note.
func (r *NoteEmbeddingRepository) Upsert(ctx context.Context, userID uuid.UUID, noteID uuid.UUID, lang string, embedding []float64) error {
	literal, err := vectorLiteral(embedding)
	if err != nil {
		return err
	}
	_, err = r.pool.Exec(ctx,
		`INSERT INTO note_embeddings (user_id, note_id, lang, dim, embedding, updated_at)
		 VALUES ($1, $2, $3, $4, $5::vector, NOW())
		 ON CONFLICT (user_id, note_id)
		 DO UPDATE SET lang = EXCLUDED.lang, dim = EXCLUDED.dim,
		               embedding = EXCLUDED.embedding, updated_at = NOW()`,
		userID, noteID, lang, len(embedding), literal,
	)
	return err
}

// Delete removes the embedding for one note; no-op when absent.
func (r *NoteEmbeddingRepository) Delete(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM note_embeddings WHERE user_id = $1 AND note_id = $2`,
		userID, noteID,
	)
	return err
}

// Search returns the nearest notes by cosine distance, filtered to the
// caller's own embeddings with a matching dimension.
func (r *NoteEmbeddingRepository) Search(ctx context.Context, userID uuid.UUID, query []float64, limit int) ([]domain.SemanticSearchHit, error) {
	literal, err := vectorLiteral(query)
	if err != nil {
		return nil, err
	}
	rows, err := r.pool.Query(ctx,
		`SELECT note_id, lang, embedding <=> $1::vector AS distance
		 FROM note_embeddings
		 WHERE user_id = $2 AND dim = $3
		 ORDER BY distance
		 LIMIT $4`,
		literal, userID, len(query), limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	hits := []domain.SemanticSearchHit{}
	for rows.Next() {
		var h domain.SemanticSearchHit
		if err := rows.Scan(&h.NoteID, &h.Lang, &h.Distance); err != nil {
			return nil, err
		}
		hits = append(hits, h)
	}
	return hits, rows.Err()
}

// ListForUser returns the user's indexed notes (for client cache checks).
func (r *NoteEmbeddingRepository) ListForUser(ctx context.Context, userID uuid.UUID) ([]domain.NoteEmbedding, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT note_id, lang, dim, updated_at FROM note_embeddings WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []domain.NoteEmbedding{}
	for rows.Next() {
		var e domain.NoteEmbedding
		if err := rows.Scan(&e.NoteID, &e.Lang, &e.Dim, &e.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// GetUpdatedAt returns when the note was last embedded, or ErrEmbeddingNotFound.
func (r *NoteEmbeddingRepository) GetUpdatedAt(ctx context.Context, userID uuid.UUID, noteID uuid.UUID) (time.Time, error) {
	var ts time.Time
	err := r.pool.QueryRow(ctx,
		`SELECT updated_at FROM note_embeddings WHERE user_id = $1 AND note_id = $2`,
		userID, noteID,
	).Scan(&ts)
	if errors.Is(err, pgx.ErrNoRows) {
		return time.Time{}, ErrEmbeddingNotFound
	}
	return ts, err
}

// vectorLiteral renders a float slice as a pgvector text literal, rejecting
// NaN/Inf values that pgvector cannot parse.
func vectorLiteral(v []float64) (string, error) {
	if len(v) == 0 {
		return "", errors.New("embedding must not be empty")
	}
	var b strings.Builder
	b.WriteByte('[')
	for i, f := range v {
		if i > 0 {
			b.WriteByte(',')
		}
		if math.IsNaN(f) || math.IsInf(f, 0) {
			return "", errors.New("embedding values must be finite")
		}
		b.WriteString(strconv.FormatFloat(f, 'g', -1, 64))
	}
	b.WriteByte(']')
	return b.String(), nil
}
