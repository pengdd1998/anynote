package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

type SyncBlobRepository struct {
	pool *pgxpool.Pool
}

func NewSyncBlobRepository(pool *pgxpool.Pool) *SyncBlobRepository {
	return &SyncBlobRepository{pool: pool}
}

// PullSince returns sync blobs with version > sinceVersion, using cursor-based pagination.
// limit controls the page size, cursor is the last version from the previous page (0 for first page).
func (r *SyncBlobRepository) PullSince(ctx context.Context, userID uuid.UUID, sinceVersion int) ([]domain.SyncBlob, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, item_type, item_id, version, encrypted_data, blob_size, created_at, updated_at
		 FROM sync_blobs
		 WHERE user_id = $1 AND version > $2
		 ORDER BY version ASC`,
		userID, sinceVersion,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blobs []domain.SyncBlob
	for rows.Next() {
		var b domain.SyncBlob
		if err := rows.Scan(&b.ID, &b.UserID, &b.ItemType, &b.ItemID, &b.Version, &b.EncryptedData, &b.BlobSize, &b.CreatedAt, &b.UpdatedAt); err != nil {
			return nil, err
		}
		blobs = append(blobs, b)
	}
	return blobs, rows.Err()
}

// PullSincePaginated returns up to limit sync blobs with version > sinceVersion,
// ordered by version ascending for deterministic cursor-based pagination.
func (r *SyncBlobRepository) PullSincePaginated(ctx context.Context, userID uuid.UUID, sinceVersion int, limit int) ([]domain.SyncBlob, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, item_type, item_id, version, encrypted_data, blob_size, created_at, updated_at
		 FROM sync_blobs
		 WHERE user_id = $1 AND version > $2
		 ORDER BY version ASC
		 LIMIT $3`,
		userID, sinceVersion, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blobs []domain.SyncBlob
	for rows.Next() {
		var b domain.SyncBlob
		if err := rows.Scan(&b.ID, &b.UserID, &b.ItemType, &b.ItemID, &b.Version, &b.EncryptedData, &b.BlobSize, &b.CreatedAt, &b.UpdatedAt); err != nil {
			return nil, err
		}
		blobs = append(blobs, b)
	}
	return blobs, rows.Err()
}

// HasMoreSince checks whether there are any rows with version > sinceVersion for the user.
func (r *SyncBlobRepository) HasMoreSince(ctx context.Context, userID uuid.UUID, sinceVersion int) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM sync_blobs WHERE user_id = $1 AND version > $2 LIMIT 1)`,
		userID, sinceVersion,
	).Scan(&exists)
	return exists, err
}

// Upsert inserts or updates a sync blob atomically using INSERT ... ON CONFLICT.
// Returns true if the row was inserted or updated (client version > server version).
// Returns false if the server already has an equal or newer version (conflict).
func (r *SyncBlobRepository) Upsert(ctx context.Context, blob *domain.SyncBlob) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO sync_blobs (user_id, item_type, item_id, version, encrypted_data, blob_size, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
		 ON CONFLICT (user_id, item_type, item_id) DO UPDATE
		 SET version = $4, encrypted_data = $5, blob_size = $6, updated_at = NOW()
		 WHERE sync_blobs.version < $4`,
		blob.UserID, blob.ItemType, blob.ItemID, blob.Version, blob.EncryptedData, blob.BlobSize,
	)
	if err != nil {
		return false, fmt.Errorf("upsert sync blob: %w", err)
	}

	rowsAffected := tag.RowsAffected()
	if rowsAffected == 0 {
		// Server version >= client version, or no row was modified.
		// Fetch the current server version so the caller can report it.
		var serverVersion int
		if err := r.pool.QueryRow(ctx,
			`SELECT version FROM sync_blobs WHERE user_id = $1 AND item_type = $2 AND item_id = $3`,
			blob.UserID, blob.ItemType, blob.ItemID,
		).Scan(&serverVersion); err == nil {
			blob.Version = serverVersion
		}
		return false, nil
	}
	return true, nil
}

// BatchUpsert pipelines all upsert queries in a single pgx.Batch round-trip.
// For items where the server version >= client version (conflict), it issues a
// secondary batch to fetch server versions.
func (r *SyncBlobRepository) BatchUpsert(ctx context.Context, blobs []*domain.SyncBlob) []domain.BatchUpsertResult {
	results := make([]domain.BatchUpsertResult, len(blobs))

	if len(blobs) == 0 {
		return results
	}

	// Phase 1: Send all upsert queries in a single batch.
	batch := &pgx.Batch{}
	for i, blob := range blobs {
		batch.Queue(
			`INSERT INTO sync_blobs (user_id, item_type, item_id, version, encrypted_data, blob_size, created_at, updated_at)
			 VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
			 ON CONFLICT (user_id, item_type, item_id) DO UPDATE
			 SET version = $4, encrypted_data = $5, blob_size = $6, updated_at = NOW()
			 WHERE sync_blobs.version < $4`,
			blob.UserID, blob.ItemType, blob.ItemID, blob.Version, blob.EncryptedData, blob.BlobSize,
		)
		results[i].ItemID = blob.ItemID
	}

	br := r.pool.SendBatch(ctx, batch)
	defer br.Close()

	// Collect results from phase 1.
	var conflictIndices []int
	for i := range blobs {
		tag, err := br.Exec()
		if err != nil {
			results[i].Error = fmt.Errorf("batch upsert item %s: %w", blobs[i].ItemID, err)
			continue
		}
		if tag.RowsAffected() > 0 {
			results[i].Accepted = true
		} else {
			conflictIndices = append(conflictIndices, i)
		}
	}

	// Phase 2: For conflicts, fetch current server versions in a second batch.
	if len(conflictIndices) > 0 {
		verBatch := &pgx.Batch{}
		for _, idx := range conflictIndices {
			blob := blobs[idx]
			verBatch.Queue(
				`SELECT version FROM sync_blobs WHERE user_id = $1 AND item_type = $2 AND item_id = $3`,
				blob.UserID, blob.ItemType, blob.ItemID,
			)
		}

		vbr := r.pool.SendBatch(ctx, verBatch)
		defer vbr.Close()

		for _, idx := range conflictIndices {
			var serverVersion int
			if err := vbr.QueryRow().Scan(&serverVersion); err != nil {
				// If we cannot determine the server version, keep the client version.
				results[idx].ServerVersion = blobs[idx].Version
			} else {
				results[idx].ServerVersion = serverVersion
				blobs[idx].Version = serverVersion
			}
		}
	}

	return results
}

func (r *SyncBlobRepository) GetLatestVersion(ctx context.Context, userID uuid.UUID) (int, error) {
	var version *int
	err := r.pool.QueryRow(ctx,
		`SELECT MAX(version) FROM sync_blobs WHERE user_id = $1`, userID,
	).Scan(&version)
	if err != nil {
		return 0, err
	}
	if version == nil {
		return 0, nil
	}
	return *version, nil
}

func (r *SyncBlobRepository) CountItems(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM sync_blobs WHERE user_id = $1`, userID,
	).Scan(&count)
	return count, err
}

func (r *SyncBlobRepository) GetLastUpdated(ctx context.Context, userID uuid.UUID) (time.Time, error) {
	var t *time.Time
	err := r.pool.QueryRow(ctx,
		`SELECT MAX(updated_at) FROM sync_blobs WHERE user_id = $1`, userID,
	).Scan(&t)
	if err != nil || t == nil {
		return time.Time{}, err
	}
	return *t, nil
}

// GetStatusSummary returns the sync status (latest version, total items, last updated)
// in a single database round-trip.
func (r *SyncBlobRepository) GetStatusSummary(ctx context.Context, userID uuid.UUID) (domain.SyncStatusSummary, error) {
	var summary domain.SyncStatusSummary
	var lastUpdated *time.Time

	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(MAX(version), 0), COUNT(*), COALESCE(MAX(updated_at), NULL)
		 FROM sync_blobs WHERE user_id = $1`,
		userID,
	).Scan(&summary.LatestVersion, &summary.TotalItems, &lastUpdated)
	if err != nil {
		return summary, fmt.Errorf("get status summary: %w", err)
	}

	if lastUpdated != nil {
		summary.LastUpdated = *lastUpdated
	}
	return summary, nil
}
