package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

// DeviceRepository manages device identity records in PostgreSQL.
type DeviceRepository struct {
	pool *pgxpool.Pool
}

// NewDeviceRepository creates a new DeviceRepository.
func NewDeviceRepository(pool *pgxpool.Pool) *DeviceRepository {
	return &DeviceRepository{pool: pool}
}

// RegisterDevice inserts a new device or updates an existing one (upsert by
// user_id + device_id). Returns the resulting Device row.
func (r *DeviceRepository) RegisterDevice(ctx context.Context, userID, deviceID, deviceName, platform string) (*domain.Device, error) {
	var d domain.Device
	err := r.pool.QueryRow(ctx,
		`INSERT INTO devices (user_id, device_id, device_name, platform, last_seen)
		 VALUES ($1, $2, $3, $4, NOW())
		 ON CONFLICT (user_id, device_id) DO UPDATE
		   SET device_name = $3, platform = $4, last_seen = NOW()
		 RETURNING id, user_id, device_id, device_name, platform, last_seen, created_at`,
		userID, deviceID, deviceName, platform,
	).Scan(&d.ID, &d.UserID, &d.DeviceID, &d.DeviceName, &d.Platform, &d.LastSeen, &d.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("register device: %w", err)
	}
	return &d, nil
}

// ListDevices returns all devices registered for the given user, ordered by
// last_seen descending.
func (r *DeviceRepository) ListDevices(ctx context.Context, userID string) ([]*domain.Device, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, device_id, device_name, platform, last_seen, created_at
		 FROM devices
		 WHERE user_id = $1
		 ORDER BY last_seen DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("list devices: %w", err)
	}
	defer rows.Close()

	var devices []*domain.Device
	for rows.Next() {
		var d domain.Device
		if err := rows.Scan(&d.ID, &d.UserID, &d.DeviceID, &d.DeviceName, &d.Platform, &d.LastSeen, &d.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan device: %w", err)
		}
		devices = append(devices, &d)
	}
	return devices, rows.Err()
}

// DeleteDevice removes a specific device for the given user.
func (r *DeviceRepository) DeleteDevice(ctx context.Context, userID, deviceID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM devices WHERE user_id = $1 AND device_id = $2`,
		userID, deviceID,
	)
	if err != nil {
		return fmt.Errorf("delete device: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("delete device: device not found")
	}
	return nil
}

// UpdateLastSeen refreshes the last_seen timestamp for a device.
func (r *DeviceRepository) UpdateLastSeen(ctx context.Context, userID, deviceID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE devices SET last_seen = $1 WHERE user_id = $2 AND device_id = $3`,
		time.Now(), userID, deviceID,
	)
	if err != nil {
		return fmt.Errorf("update device last_seen: %w", err)
	}
	return nil
}

// CleanStaleDevices removes devices that have not been seen within the given
// retention period. Returns the number of rows deleted.
func (r *DeviceRepository) CleanStaleDevices(ctx context.Context, retentionDays int) (int64, error) {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM devices WHERE last_seen < NOW() - $1::interval`,
		fmt.Sprintf("%d days", retentionDays),
	)
	if err != nil {
		return 0, fmt.Errorf("clean stale devices: %w", err)
	}
	return tag.RowsAffected(), nil
}

// DeleteByUser removes all devices for a given user. Used during account deletion.
func (r *DeviceRepository) DeleteByUser(ctx context.Context, userID string) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM devices WHERE user_id = $1`, userID)
	if err != nil {
		return fmt.Errorf("delete devices by user: %w", err)
	}
	return nil
}
