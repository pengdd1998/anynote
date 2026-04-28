package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

// CollabRepository manages collab room data in PostgreSQL.
type CollabRepository struct {
	pool *pgxpool.Pool
}

// NewCollabRepository creates a new CollabRepository.
func NewCollabRepository(pool *pgxpool.Pool) *CollabRepository {
	return &CollabRepository{pool: pool}
}

// CreateRoom inserts a new collab room.
func (r *CollabRepository) CreateRoom(ctx context.Context, room *domain.CollabRoom) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO collab_rooms (id, creator_id, invite_code, room_name, max_members, created_at, expires_at, is_active)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		room.ID, room.CreatorID, room.InviteCode, room.RoomName, room.MaxMembers, room.CreatedAt, room.ExpiresAt, room.IsActive,
	)
	if err != nil {
		return fmt.Errorf("create collab room: %w", err)
	}
	return nil
}

// GetRoomByInviteCode returns a room by its invite code, including the member count.
func (r *CollabRepository) GetRoomByInviteCode(ctx context.Context, inviteCode string) (*domain.CollabRoom, error) {
	var room domain.CollabRoom
	err := r.pool.QueryRow(ctx,
		`SELECT r.id, r.creator_id, r.invite_code, r.room_name, r.max_members,
		        r.created_at, r.expires_at, r.is_active,
		        COALESCE(m.cnt, 0) AS member_count
		 FROM collab_rooms r
		 LEFT JOIN (SELECT room_id, COUNT(*) AS cnt FROM collab_room_members GROUP BY room_id) m
		   ON m.room_id = r.id
		 WHERE r.invite_code = $1`,
		inviteCode,
	).Scan(&room.ID, &room.CreatorID, &room.InviteCode, &room.RoomName, &room.MaxMembers,
		&room.CreatedAt, &room.ExpiresAt, &room.IsActive, &room.MemberCount)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("room not found by invite code: %w", err)
		}
		return nil, fmt.Errorf("get room by invite code: %w", err)
	}
	return &room, nil
}

// GetRoomByID returns a room by its ID.
func (r *CollabRepository) GetRoomByID(ctx context.Context, roomID string) (*domain.CollabRoom, error) {
	var room domain.CollabRoom
	err := r.pool.QueryRow(ctx,
		`SELECT id, creator_id, invite_code, room_name, max_members,
		        created_at, expires_at, is_active
		 FROM collab_rooms
		 WHERE id = $1`,
		roomID,
	).Scan(&room.ID, &room.CreatorID, &room.InviteCode, &room.RoomName, &room.MaxMembers,
		&room.CreatedAt, &room.ExpiresAt, &room.IsActive)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("room not found: %w", err)
		}
		return nil, fmt.Errorf("get room by id: %w", err)
	}
	return &room, nil
}

// AddMember inserts a new member into a room. It checks that the room has not
// exceeded max_members before inserting.
func (r *CollabRepository) AddMember(ctx context.Context, member *domain.CollabRoomMember) error {
	// Check current member count against max_members.
	var maxMembers int
	err := r.pool.QueryRow(ctx,
		`SELECT max_members FROM collab_rooms WHERE id = $1`,
		member.RoomID,
	).Scan(&maxMembers)
	if err != nil {
		return fmt.Errorf("check room capacity: %w", err)
	}

	var currentCount int
	err = r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM collab_room_members WHERE room_id = $1`,
		member.RoomID,
	).Scan(&currentCount)
	if err != nil {
		return fmt.Errorf("count room members: %w", err)
	}

	if currentCount >= maxMembers {
		return fmt.Errorf("room is full: current %d, max %d", currentCount, maxMembers)
	}

	var id string
	err = r.pool.QueryRow(ctx,
		`INSERT INTO collab_room_members (room_id, user_id, role)
		 VALUES ($1, $2, $3)
		 RETURNING id`,
		member.RoomID, member.UserID, member.Role,
	).Scan(&id)
	if err != nil {
		return fmt.Errorf("add room member: %w", err)
	}
	member.ID = id
	return nil
}

// RemoveMember removes a user from a room.
func (r *CollabRepository) RemoveMember(ctx context.Context, roomID, userID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM collab_room_members WHERE room_id = $1 AND user_id = $2`,
		roomID, userID,
	)
	if err != nil {
		return fmt.Errorf("remove room member: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("member not found in room")
	}
	return nil
}

// GetRoomMembers returns all members of a room.
func (r *CollabRepository) GetRoomMembers(ctx context.Context, roomID string) ([]domain.CollabRoomMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, room_id, user_id, role, joined_at
		 FROM collab_room_members
		 WHERE room_id = $1
		 ORDER BY joined_at ASC`,
		roomID,
	)
	if err != nil {
		return nil, fmt.Errorf("get room members: %w", err)
	}
	defer rows.Close()

	var members []domain.CollabRoomMember
	for rows.Next() {
		var m domain.CollabRoomMember
		if err := rows.Scan(&m.ID, &m.RoomID, &m.UserID, &m.Role, &m.JoinedAt); err != nil {
			return nil, fmt.Errorf("scan room member: %w", err)
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

// IsMember returns whether the given user is a member of the room.
func (r *CollabRepository) IsMember(ctx context.Context, roomID, userID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM collab_room_members WHERE room_id = $1 AND user_id = $2)`,
		roomID, userID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check room membership: %w", err)
	}
	return exists, nil
}

// DeactivateRoom sets is_active to false for a room.
func (r *CollabRepository) DeactivateRoom(ctx context.Context, roomID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE collab_rooms SET is_active = false WHERE id = $1`,
		roomID,
	)
	if err != nil {
		return fmt.Errorf("deactivate room: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("room not found for deactivation")
	}
	return nil
}

// GetUserRooms returns all rooms the user is a member of, with member counts.
func (r *CollabRepository) GetUserRooms(ctx context.Context, userID string) ([]domain.CollabRoom, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT r.id, r.creator_id, r.invite_code, r.room_name, r.max_members,
		        r.created_at, r.expires_at, r.is_active,
		        COALESCE(m.cnt, 0) AS member_count
		 FROM collab_rooms r
		 JOIN collab_room_members rm ON rm.room_id = r.id
		 LEFT JOIN (SELECT room_id, COUNT(*) AS cnt FROM collab_room_members GROUP BY room_id) m
		   ON m.room_id = r.id
		 WHERE rm.user_id = $1
		 ORDER BY r.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("get user rooms: %w", err)
	}
	defer rows.Close()

	var rooms []domain.CollabRoom
	for rows.Next() {
		var room domain.CollabRoom
		if err := rows.Scan(&room.ID, &room.CreatorID, &room.InviteCode, &room.RoomName,
			&room.MaxMembers, &room.CreatedAt, &room.ExpiresAt, &room.IsActive,
			&room.MemberCount); err != nil {
			return nil, fmt.Errorf("scan user room: %w", err)
		}
		rooms = append(rooms, room)
	}
	return rooms, rows.Err()
}
