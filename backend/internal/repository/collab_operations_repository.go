package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

// CollabOperationsRepository manages CRDT operation persistence in PostgreSQL.
type CollabOperationsRepository struct {
	pool *pgxpool.Pool
}

// NewCollabOperationsRepository creates a new CollabOperationsRepository.
func NewCollabOperationsRepository(pool *pgxpool.Pool) *CollabOperationsRepository {
	return &CollabOperationsRepository{pool: pool}
}

// StoreOperation persists a CRDT operation.
func (r *CollabOperationsRepository) StoreOperation(ctx context.Context, op *domain.CollabOperation) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO collab_operations (id, room_id, site_id, clock, operation_type, payload, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		op.ID, op.RoomID, op.SiteID, op.Clock, op.OperationType, op.Payload, op.CreatedAt,
	)
	if err != nil {
		return fmt.Errorf("store collab operation: %w", err)
	}
	return nil
}

// GetOperationsSince returns all operations in a room with clock > sinceClock,
// ordered by clock ascending.
func (r *CollabOperationsRepository) GetOperationsSince(ctx context.Context, roomID string, sinceClock int) ([]domain.CollabOperation, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, room_id, site_id, clock, operation_type, payload, created_at
		 FROM collab_operations
		 WHERE room_id = $1 AND clock > $2
		 ORDER BY clock ASC`,
		roomID, sinceClock,
	)
	if err != nil {
		return nil, fmt.Errorf("get operations since: %w", err)
	}
	defer rows.Close()

	return scanOperations(rows)
}

// GetOperationsByRoom returns the most recent N operations for a room,
// ordered by clock descending (newest first).
func (r *CollabOperationsRepository) GetOperationsByRoom(ctx context.Context, roomID string, limit int) ([]domain.CollabOperation, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, room_id, site_id, clock, operation_type, payload, created_at
		 FROM collab_operations
		 WHERE room_id = $1
		 ORDER BY clock DESC
		 LIMIT $2`,
		roomID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("get operations by room: %w", err)
	}
	defer rows.Close()

	return scanOperations(rows)
}

// scanOperations scans a pgx.Rows into a slice of CollabOperation.
func scanOperations(rows pgx.Rows) ([]domain.CollabOperation, error) {
	var ops []domain.CollabOperation
	for rows.Next() {
		var op domain.CollabOperation
		if err := rows.Scan(&op.ID, &op.RoomID, &op.SiteID, &op.Clock, &op.OperationType, &op.Payload, &op.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan collab operation: %w", err)
		}
		ops = append(ops, op)
	}
	return ops, rows.Err()
}
