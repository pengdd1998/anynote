package service

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// Sentinel errors for collab room operations.
var (
	ErrRoomNotFound    = errors.New("room not found")
	ErrRoomInactive    = errors.New("room is no longer active")
	ErrRoomExpired     = errors.New("room has expired")
	ErrRoomFull        = errors.New("room has reached maximum members")
	ErrAlreadyMember   = errors.New("user is already a member of this room")
	ErrNotMember       = errors.New("user is not a member of this room")
	ErrInvalidInvite   = errors.New("invalid invite code")
	ErrRoomNameTooLong = errors.New("room_name must be at most 255 characters")
	ErrMaxMembersRange = errors.New("max_members must be between 1 and 100")
)

// CollabRepository defines the data access interface for collab rooms.
type CollabRepository interface {
	CreateRoom(ctx context.Context, room *domain.CollabRoom) error
	GetRoomByInviteCode(ctx context.Context, inviteCode string) (*domain.CollabRoom, error)
	GetRoomByID(ctx context.Context, roomID string) (*domain.CollabRoom, error)
	AddMember(ctx context.Context, member *domain.CollabRoomMember) error
	RemoveMember(ctx context.Context, roomID, userID string) error
	GetRoomMembers(ctx context.Context, roomID string) ([]domain.CollabRoomMember, error)
	IsMember(ctx context.Context, roomID, userID string) (bool, error)
	DeactivateRoom(ctx context.Context, roomID string) error
	GetUserRooms(ctx context.Context, userID string) ([]domain.CollabRoom, error)
}

// CollabService manages collab room operations.
type CollabService interface {
	CreateRoom(ctx context.Context, userID string, req domain.CreateRoomRequest) (*domain.CollabRoom, error)
	JoinRoom(ctx context.Context, userID string, req domain.JoinRoomRequest) (*domain.CollabRoom, error)
	LeaveRoom(ctx context.Context, userID, roomID string) error
	GetRoomMembers(ctx context.Context, userID, roomID string) ([]domain.CollabRoomMember, error)
	GetUserRooms(ctx context.Context, userID string) ([]domain.CollabRoom, error)
}

type collabService struct {
	repo CollabRepository
}

// NewCollabService creates a new CollabService.
func NewCollabService(repo CollabRepository) CollabService {
	return &collabService{repo: repo}
}

// CreateRoom creates a new collab room with a generated UUID ID and random
// 8-character alphanumeric invite code. The creator is added as an owner member.
func (s *collabService) CreateRoom(ctx context.Context, userID string, req domain.CreateRoomRequest) (*domain.CollabRoom, error) {
	if len(req.RoomName) > 255 {
		return nil, ErrRoomNameTooLong
	}
	if req.MaxMembers < 1 || req.MaxMembers > 100 {
		return nil, ErrMaxMembersRange
	}

	inviteCode, err := generateInviteCode(8)
	if err != nil {
		return nil, fmt.Errorf("generate invite code: %w", err)
	}

	now := time.Now()
	room := &domain.CollabRoom{
		ID:          uuid.New().String(),
		CreatorID:   userID,
		InviteCode:  inviteCode,
		RoomName:    req.RoomName,
		MaxMembers:  req.MaxMembers,
		CreatedAt:   now,
		IsActive:    true,
		MemberCount: 1,
	}

	if err := s.repo.CreateRoom(ctx, room); err != nil {
		return nil, fmt.Errorf("create room: %w", err)
	}

	// Add creator as owner.
	owner := &domain.CollabRoomMember{
		RoomID:   room.ID,
		UserID:   userID,
		Role:     "owner",
		JoinedAt: now,
	}
	if err := s.repo.AddMember(ctx, owner); err != nil {
		return nil, fmt.Errorf("add owner member: %w", err)
	}

	return room, nil
}

// JoinRoom looks up a room by invite code, validates it is active and not full,
// then adds the user as a member.
func (s *collabService) JoinRoom(ctx context.Context, userID string, req domain.JoinRoomRequest) (*domain.CollabRoom, error) {
	if req.InviteCode == "" {
		return nil, ErrInvalidInvite
	}

	room, err := s.repo.GetRoomByInviteCode(ctx, req.InviteCode)
	if err != nil {
		return nil, ErrRoomNotFound
	}

	if !room.IsActive {
		return nil, ErrRoomInactive
	}

	if room.ExpiresAt != nil && room.ExpiresAt.Before(time.Now()) {
		return nil, ErrRoomExpired
	}

	if room.MemberCount >= room.MaxMembers {
		return nil, ErrRoomFull
	}

	// Check if already a member.
	isMember, err := s.repo.IsMember(ctx, room.ID, userID)
	if err != nil {
		return nil, fmt.Errorf("check membership: %w", err)
	}
	if isMember {
		return nil, ErrAlreadyMember
	}

	member := &domain.CollabRoomMember{
		RoomID:   room.ID,
		UserID:   userID,
		Role:     "member",
		JoinedAt: time.Now(),
	}
	if err := s.repo.AddMember(ctx, member); err != nil {
		return nil, fmt.Errorf("join room: %w", err)
	}

	// Refresh member count for the response.
	room.MemberCount++
	return room, nil
}

// LeaveRoom removes a user from a room. If the user is the creator (owner),
// the room is deactivated.
func (s *collabService) LeaveRoom(ctx context.Context, userID, roomID string) error {
	isMember, err := s.repo.IsMember(ctx, roomID, userID)
	if err != nil {
		return fmt.Errorf("check membership: %w", err)
	}
	if !isMember {
		return ErrNotMember
	}

	// Check if user is the creator/owner; if so, deactivate the room.
	room, err := s.repo.GetRoomByID(ctx, roomID)
	if err != nil {
		return ErrRoomNotFound
	}
	if room.CreatorID == userID {
		if deactErr := s.repo.DeactivateRoom(ctx, roomID); deactErr != nil {
			return fmt.Errorf("deactivate room on owner leave: %w", deactErr)
		}
	}

	if err := s.repo.RemoveMember(ctx, roomID, userID); err != nil {
		return fmt.Errorf("leave room: %w", err)
	}

	return nil
}

// GetRoomMembers returns all members of a room after verifying the caller is a member.
func (s *collabService) GetRoomMembers(ctx context.Context, userID, roomID string) ([]domain.CollabRoomMember, error) {
	isMember, err := s.repo.IsMember(ctx, roomID, userID)
	if err != nil {
		return nil, fmt.Errorf("check membership: %w", err)
	}
	if !isMember {
		return nil, ErrNotMember
	}

	members, err := s.repo.GetRoomMembers(ctx, roomID)
	if err != nil {
		return nil, fmt.Errorf("get room members: %w", err)
	}

	if members == nil {
		members = []domain.CollabRoomMember{}
	}
	return members, nil
}

// GetUserRooms returns all rooms the user is a member of.
func (s *collabService) GetUserRooms(ctx context.Context, userID string) ([]domain.CollabRoom, error) {
	rooms, err := s.repo.GetUserRooms(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get user rooms: %w", err)
	}

	if rooms == nil {
		rooms = []domain.CollabRoom{}
	}
	return rooms, nil
}

// generateInviteCode produces a random alphanumeric string of the given length.
// It uses characters that are easily distinguishable (no 0/O, 1/l/I).
func generateInviteCode(length int) (string, error) {
	const charset = "23456789ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"
	result := make([]byte, length)
	for i := range result {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			return "", fmt.Errorf("generate random byte: %w", err)
		}
		result[i] = charset[n.Int64()]
	}
	return string(result), nil
}
