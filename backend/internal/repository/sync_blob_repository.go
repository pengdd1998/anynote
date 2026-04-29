// Package repository implements database access layer using pgxpool for PostgreSQL.
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
		`SELECT id, user_id, item_type, item_id, version, encrypted_data, blob_size, device_id, created_at, updated_at
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
		if err := rows.Scan(&b.ID, &b.UserID, &b.ItemType, &b.ItemID, &b.Version, &b.EncryptedData, &b.BlobSize, &b.DeviceID, &b.CreatedAt, &b.UpdatedAt); err != nil {
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
		`SELECT id, user_id, item_type, item_id, version, encrypted_data, blob_size, device_id, created_at, updated_at
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
		if err := rows.Scan(&b.ID, &b.UserID, &b.ItemType, &b.ItemID, &b.Version, &b.EncryptedData, &b.BlobSize, &b.DeviceID, &b.CreatedAt, &b.UpdatedAt); err != nil {
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
		`INSERT INTO sync_blobs (user_id, item_type, item_id, version, encrypted_data, blob_size, device_id, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
		 ON CONFLICT (user_id, item_type, item_id) DO UPDATE
		 SET version = $4, encrypted_data = $5, blob_size = $6, device_id = $7, updated_at = NOW()
		 WHERE sync_blobs.version < $4`,
		blob.UserID, blob.ItemType, blob.ItemID, blob.Version, blob.EncryptedData, blob.BlobSize, blob.DeviceID,
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

	// Wrap the entire batch in a transaction for atomicity.
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		for i := range blobs {
			results[i].ItemID = blobs[i].ItemID
			results[i].ItemType = blobs[i].ItemType
			results[i].ClientVersion = blobs[i].Version
			results[i].Error = fmt.Errorf("begin transaction: %w", err)
		}
		return results
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Phase 1: Send all upsert queries in a single batch.
	batch := &pgx.Batch{}
	for i, blob := range blobs {
		batch.Queue(
			`INSERT INTO sync_blobs (user_id, item_type, item_id, version, encrypted_data, blob_size, device_id, created_at, updated_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
			 ON CONFLICT (user_id, item_type, item_id) DO UPDATE
			 SET version = $4, encrypted_data = $5, blob_size = $6, device_id = $7, updated_at = NOW()
			 WHERE sync_blobs.version < $4`,
			blob.UserID, blob.ItemType, blob.ItemID, blob.Version, blob.EncryptedData, blob.BlobSize, blob.DeviceID,
		)
		results[i].ItemID = blob.ItemID
		results[i].ItemType = blob.ItemType
		results[i].ClientVersion = blob.Version
	}

	br := tx.SendBatch(ctx, batch)
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

		vbr := tx.SendBatch(ctx, verBatch)
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

	if err := tx.Commit(ctx); err != nil {
		for i := range blobs {
			results[i].Error = fmt.Errorf("commit batch upsert: %w", err)
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

// GetItemsByType returns a map of item_type -> count for the given user.
func (r *SyncBlobRepository) GetItemsByType(ctx context.Context, userID uuid.UUID) (map[string]int, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT item_type, COUNT(*) FROM sync_blobs WHERE user_id = $1 GROUP BY item_type`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("get items by type: %w", err)
	}
	defer rows.Close()

	result := make(map[string]int)
	for rows.Next() {
		var itemType string
		var count int
		if err := rows.Scan(&itemType, &count); err != nil {
			return nil, fmt.Errorf("scan items by type: %w", err)
		}
		result[itemType] = count
	}
	return result, rows.Err()
}

// GetConflictCount returns the total number of logged sync conflicts for the given user.
func (r *SyncBlobRepository) GetConflictCount(ctx context.Context, userID uuid.UUID) (int64, error) {
	var count int64
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM sync_operation_logs WHERE user_id = $1 AND operation_type = 'push' AND version = 0`,
		userID,
	).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("get conflict count: %w", err)
	}
	return count, nil
}

// InsertOperationLog records a sync operation log entry.
// version=0 is used as a sentinel to indicate a conflict (server rejected the push).
func (r *SyncBlobRepository) InsertOperationLog(ctx context.Context, log *domain.SyncOperationLog) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO sync_operation_logs (id, user_id, operation_type, item_type, item_id, version, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		log.ID, log.UserID, log.OperationType, log.ItemType, log.ItemID, log.Version, log.CreatedAt,
	)
	if err != nil {
		return fmt.Errorf("insert operation log: %w", err)
	}
	return nil
}

// BatchInsertOperationLogs records multiple sync operation log entries in a single round-trip.
func (r *SyncBlobRepository) BatchInsertOperationLogs(ctx context.Context, logs []domain.SyncOperationLog) error {
	if len(logs) == 0 {
		return nil
	}

	batch := &pgx.Batch{}
	for _, log := range logs {
		batch.Queue(
			`INSERT INTO sync_operation_logs (id, user_id, operation_type, item_type, item_id, version, created_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			log.ID, log.UserID, log.OperationType, log.ItemType, log.ItemID, log.Version, log.CreatedAt,
		)
	}

	br := r.pool.SendBatch(ctx, batch)
	defer br.Close()

	for range logs {
		if _, err := br.Exec(); err != nil {
			return fmt.Errorf("batch insert operation log: %w", err)
		}
	}
	return nil
}

// ListTagsByType returns metadata for all sync blobs of the given item_type for a user.
// Since blob contents are encrypted, only metadata fields are returned.
func (r *SyncBlobRepository) ListTagsByType(ctx context.Context, userID uuid.UUID, itemType string) ([]domain.TagListItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT item_id, version, blob_size, updated_at
		 FROM sync_blobs
		 WHERE user_id = $1 AND item_type = $2
		 ORDER BY updated_at DESC`,
		userID, itemType,
	)
	if err != nil {
		return nil, fmt.Errorf("list tags by type: %w", err)
	}
	defer rows.Close()

	var tags []domain.TagListItem
	for rows.Next() {
		var t domain.TagListItem
		if err := rows.Scan(&t.ItemID, &t.Version, &t.BlobSize, &t.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan tag item: %w", err)
		}
		tags = append(tags, t)
	}
	return tags, rows.Err()
}

// BatchDelete removes multiple sync blobs for a user atomically within a transaction.
// Returns the number of rows actually deleted.
func (r *SyncBlobRepository) BatchDelete(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (int, error) {
	if len(itemIDs) == 0 {
		return 0, nil
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Use a batch to send all delete queries in a single round-trip.
	batch := &pgx.Batch{}
	for _, id := range itemIDs {
		batch.Queue(
			`DELETE FROM sync_blobs WHERE user_id = $1 AND item_id = $2`,
			userID, id,
		)
	}

	br := tx.SendBatch(ctx, batch)
	defer br.Close()

	var deleted int
	for range itemIDs {
		tag, err := br.Exec()
		if err != nil {
			return 0, fmt.Errorf("batch delete item: %w", err)
		}
		deleted += int(tag.RowsAffected())
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit batch delete: %w", err)
	}

	return deleted, nil
}

// GetOperationCounts returns push and pull operation counts in the last 24 hours.
func (r *SyncBlobRepository) GetOperationCounts(ctx context.Context, userID uuid.UUID) (pushCount, pullCount int64, err error) {
	err = r.pool.QueryRow(ctx,
		`SELECT
		   COALESCE(SUM(CASE WHEN operation_type = 'push' AND version > 0 THEN 1 ELSE 0 END), 0),
		   COALESCE(SUM(CASE WHEN operation_type = 'pull' THEN 1 ELSE 0 END), 0)
		 FROM sync_operation_logs
		 WHERE user_id = $1 AND created_at > NOW() - INTERVAL '24 hours'`,
		userID,
	).Scan(&pushCount, &pullCount)
	if err != nil {
		return 0, 0, fmt.Errorf("get operation counts: %w", err)
	}
	return pushCount, pullCount, nil
}

// ListOperationLogs returns recent sync operation logs for a user, ordered by created_at descending.
func (r *SyncBlobRepository) ListOperationLogs(ctx context.Context, userID uuid.UUID, limit int) ([]domain.SyncOperationLog, error) {
	if limit < 1 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}

	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, operation_type, item_type, item_id, version, created_at
		 FROM sync_operation_logs
		 WHERE user_id = $1
		 ORDER BY created_at DESC
		 LIMIT $2`,
		userID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("list operation logs: %w", err)
	}
	defer rows.Close()

	var logs []domain.SyncOperationLog
	for rows.Next() {
		var l domain.SyncOperationLog
		if err := rows.Scan(&l.ID, &l.UserID, &l.OperationType, &l.ItemType, &l.ItemID, &l.Version, &l.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan operation log: %w", err)
		}
		logs = append(logs, l)
	}
	return logs, rows.Err()
}

// CleanOldOperationLogs removes sync_operation_logs entries older than retentionDays.
// Returns the number of rows deleted.
func (r *SyncBlobRepository) CleanOldOperationLogs(ctx context.Context, retentionDays int) (int64, error) {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM sync_operation_logs WHERE created_at < NOW() - $1::interval`,
		fmt.Sprintf("%d days", retentionDays),
	)
	if err != nil {
		return 0, fmt.Errorf("clean old operation logs: %w", err)
	}
	return tag.RowsAffected(), nil
}
