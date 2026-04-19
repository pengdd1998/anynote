package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

type SyncBlobRepository struct {
	pool *pgxpool.Pool
}

func NewSyncBlobRepository(pool *pgxpool.Pool) *SyncBlobRepository {
	return &SyncBlobRepository{pool: pool}
}

func (r *SyncBlobRepository) PullSince(ctx context.Context, userID uuid.UUID, sinceVersion int) ([]domain.SyncBlob, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, item_type, item_id, version, encrypted_data, blob_size, created_at, updated_at
		 FROM sync_blobs
		 WHERE user_id = $1 AND version > $2
		 ORDER BY updated_at ASC`,
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

// Upsert inserts or updates a sync blob. Returns true if accepted, false if version conflict.
func (r *SyncBlobRepository) Upsert(ctx context.Context, blob *domain.SyncBlob) (bool, error) {
	// Check existing version
	var serverVersion int
	err := r.pool.QueryRow(ctx,
		`SELECT version FROM sync_blobs
		 WHERE user_id = $1 AND item_type = $2 AND item_id = $3`,
		blob.UserID, blob.ItemType, blob.ItemID,
	).Scan(&serverVersion)

	if err == nil && serverVersion >= blob.Version {
		// Server has equal or newer version — conflict
		blob.Version = serverVersion
		return false, nil
	}

	if err != nil {
		// No existing row — insert (err is "no rows")
		_, err = r.pool.Exec(ctx,
			`INSERT INTO sync_blobs (user_id, item_type, item_id, version, encrypted_data, blob_size, updated_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			blob.UserID, blob.ItemType, blob.ItemID, blob.Version, blob.EncryptedData, blob.BlobSize, time.Now(),
		)
		return err == nil, err
	}

	// Existing row with lower version — update
	_, err = r.pool.Exec(ctx,
		`UPDATE sync_blobs
		 SET version = $4, encrypted_data = $5, blob_size = $6, updated_at = $7
		 WHERE user_id = $1 AND item_type = $2 AND item_id = $3`,
		blob.UserID, blob.ItemType, blob.ItemID, blob.Version, blob.EncryptedData, blob.BlobSize, time.Now(),
	)
	return err == nil, err
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
