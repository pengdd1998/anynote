package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock CollabRepository
// ---------------------------------------------------------------------------

type mockCollabRepo struct {
	rooms      map[string]*domain.CollabRoom            // keyed by room ID
	members    map[string][]domain.CollabRoomMember     // keyed by room ID
	byInvite   map[string]string                        // invite code -> room ID
	createErr  error
	addMemErr  error
}

func newMockCollabRepo() *mockCollabRepo {
	return &mockCollabRepo{
		rooms:    make(map[string]*domain.CollabRoom),
		members:  make(map[string][]domain.CollabRoomMember),
		byInvite: make(map[string]string),
	}
}

func (m *mockCollabRepo) CreateRoom(_ context.Context, room *domain.CollabRoom) error {
	if m.createErr != nil {
		return m.createErr
	}
	m.rooms[room.ID] = room
	m.byInvite[room.InviteCode] = room.ID
	return nil
}

func (m *mockCollabRepo) GetRoomByInviteCode(_ context.Context, inviteCode string) (*domain.CollabRoom, error) {
	roomID, ok := m.byInvite[inviteCode]
	if !ok {
		return nil, fmt.Errorf("room not found by invite code: %w", errors.New("no rows"))
	}
	room := m.rooms[roomID]
	room.MemberCount = len(m.members[roomID])
	return room, nil
}

func (m *mockCollabRepo) GetRoomByID(_ context.Context, roomID string) (*domain.CollabRoom, error) {
	room, ok := m.rooms[roomID]
	if !ok {
		return nil, fmt.Errorf("room not found: %w", errors.New("no rows"))
	}
	return room, nil
}

func (m *mockCollabRepo) AddMember(_ context.Context, member *domain.CollabRoomMember) error {
	if m.addMemErr != nil {
		return m.addMemErr
	}
	room, ok := m.rooms[member.RoomID]
	if !ok {
		return fmt.Errorf("room not found")
	}
	currentMembers := m.members[member.RoomID]
	if len(currentMembers) >= room.MaxMembers {
		return fmt.Errorf("room is full")
	}
	member.ID = fmt.Sprintf("mem-%d", len(currentMembers)+1)
	m.members[member.RoomID] = append(m.members[member.RoomID], *member)
	return nil
}

func (m *mockCollabRepo) RemoveMember(_ context.Context, roomID, userID string) error {
	members := m.members[roomID]
	for i, mem := range members {
		if mem.UserID == userID {
			m.members[roomID] = append(members[:i], members[i+1:]...)
			return nil
		}
	}
	return fmt.Errorf("member not found in room")
}

func (m *mockCollabRepo) GetRoomMembers(_ context.Context, roomID string) ([]domain.CollabRoomMember, error) {
	return m.members[roomID], nil
}

func (m *mockCollabRepo) IsMember(_ context.Context, roomID, userID string) (bool, error) {
	for _, mem := range m.members[roomID] {
		if mem.UserID == userID {
			return true, nil
		}
	}
	return false, nil
}

func (m *mockCollabRepo) DeactivateRoom(_ context.Context, roomID string) error {
	room, ok := m.rooms[roomID]
	if !ok {
		return fmt.Errorf("room not found for deactivation")
	}
	room.IsActive = false
	return nil
}

func (m *mockCollabRepo) GetUserRooms(_ context.Context, userID string) ([]domain.CollabRoom, error) {
	var result []domain.CollabRoom
	for _, members := range m.members {
		for _, mem := range members {
			if mem.UserID == userID {
				room := m.rooms[mem.RoomID]
				room.MemberCount = len(m.members[mem.RoomID])
				result = append(result, *room)
			}
		}
	}
	return result, nil
}

// ---------------------------------------------------------------------------
// Tests: CreateRoom
// ---------------------------------------------------------------------------

func TestCollabService_CreateRoom_Success(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	userID := "user-1"
	room, err := svc.CreateRoom(context.Background(), userID, domain.CreateRoomRequest{
		RoomName:   "Test Room",
		MaxMembers: 5,
	})
	if err != nil {
		t.Fatalf("CreateRoom returned error: %v", err)
	}
	if room.ID == "" {
		t.Error("room.ID should not be empty")
	}
	if room.CreatorID != userID {
		t.Errorf("CreatorID = %q, want %q", room.CreatorID, userID)
	}
	if room.InviteCode == "" {
		t.Error("InviteCode should not be empty")
	}
	if len(room.InviteCode) != 8 {
		t.Errorf("InviteCode length = %d, want 8", len(room.InviteCode))
	}
	if room.RoomName != "Test Room" {
		t.Errorf("RoomName = %q, want %q", room.RoomName, "Test Room")
	}
	if room.MaxMembers != 5 {
		t.Errorf("MaxMembers = %d, want 5", room.MaxMembers)
	}
	if !room.IsActive {
		t.Error("IsActive should be true for new room")
	}
	if room.MemberCount != 1 {
		t.Errorf("MemberCount = %d, want 1 (creator)", room.MemberCount)
	}

	// Verify creator was added as owner.
	members, _ := repo.GetRoomMembers(context.Background(), room.ID)
	if len(members) != 1 {
		t.Fatalf("expected 1 member, got %d", len(members))
	}
	if members[0].UserID != userID {
		t.Errorf("member UserID = %q, want %q", members[0].UserID, userID)
	}
	if members[0].Role != "owner" {
		t.Errorf("member Role = %q, want %q", members[0].Role, "owner")
	}
}

func TestCollabService_CreateRoom_DefaultMaxMembers(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	// The default of 10 is applied at the handler layer; the service validates
	// the value it receives. This test verifies the service accepts 10.
	room, err := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName:   "Defaults",
		MaxMembers: 10,
	})
	if err != nil {
		t.Fatalf("CreateRoom returned error: %v", err)
	}
	if room.MaxMembers != 10 {
		t.Errorf("MaxMembers = %d, want 10", room.MaxMembers)
	}
}

func TestCollabService_CreateRoom_NameTooLong(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	longName := strings.Repeat("x", 256)
	_, err := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName:   longName,
		MaxMembers: 10,
	})
	if err != ErrRoomNameTooLong {
		t.Errorf("error = %v, want ErrRoomNameTooLong", err)
	}
}

func TestCollabService_CreateRoom_MaxMembersTooLow(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	_, err := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName:   "Test",
		MaxMembers: 0,
	})
	if err != ErrMaxMembersRange {
		t.Errorf("error = %v, want ErrMaxMembersRange", err)
	}
}

func TestCollabService_CreateRoom_MaxMembersTooHigh(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	_, err := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName:   "Test",
		MaxMembers: 101,
	})
	if err != ErrMaxMembersRange {
		t.Errorf("error = %v, want ErrMaxMembersRange", err)
	}
}

func TestCollabService_CreateRoom_MaxMembersBoundary(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	// Min boundary: 1
	room, err := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName:   "Min",
		MaxMembers: 1,
	})
	if err != nil {
		t.Fatalf("MaxMembers=1 should succeed: %v", err)
	}
	if room.MaxMembers != 1 {
		t.Errorf("MaxMembers = %d, want 1", room.MaxMembers)
	}

	// Max boundary: 100
	room2, err := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName:   "Max",
		MaxMembers: 100,
	})
	if err != nil {
		t.Fatalf("MaxMembers=100 should succeed: %v", err)
	}
	if room2.MaxMembers != 100 {
		t.Errorf("MaxMembers = %d, want 100", room2.MaxMembers)
	}
}

func TestCollabService_CreateRoom_DBError(t *testing.T) {
	repo := newMockCollabRepo()
	repo.createErr = errors.New("db connection lost")
	svc := NewCollabService(repo)

	_, err := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName:   "Test",
		MaxMembers: 10,
	})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestCollabService_CreateRoom_InviteCodeUniqueness(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room1, _ := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName: "Room 1", MaxMembers: 10,
	})
	room2, _ := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName: "Room 2", MaxMembers: 10,
	})

	if room1.InviteCode == room2.InviteCode {
		t.Error("two rooms should have different invite codes")
	}
}

func TestCollabService_CreateRoom_EmptyName(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, err := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName:   "",
		MaxMembers: 10,
	})
	if err != nil {
		t.Fatalf("empty name should succeed: %v", err)
	}
	if room.RoomName != "" {
		t.Errorf("RoomName = %q, want empty", room.RoomName)
	}
}

// ---------------------------------------------------------------------------
// Tests: JoinRoom
// ---------------------------------------------------------------------------

func TestCollabService_JoinRoom_Success(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Joinable", MaxMembers: 10,
	})

	joined, err := svc.JoinRoom(context.Background(), "joiner-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != nil {
		t.Fatalf("JoinRoom returned error: %v", err)
	}
	if joined.ID != room.ID {
		t.Errorf("joined room ID = %q, want %q", joined.ID, room.ID)
	}
	if joined.MemberCount != 2 {
		t.Errorf("MemberCount = %d, want 2", joined.MemberCount)
	}

	// Verify member was added.
	isMember, _ := repo.IsMember(context.Background(), room.ID, "joiner-1")
	if !isMember {
		t.Error("joiner-1 should be a member after joining")
	}
}

func TestCollabService_JoinRoom_EmptyInviteCode(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	_, err := svc.JoinRoom(context.Background(), "user-1", domain.JoinRoomRequest{
		InviteCode: "",
	})
	if err != ErrInvalidInvite {
		t.Errorf("error = %v, want ErrInvalidInvite", err)
	}
}

func TestCollabService_JoinRoom_InvalidInviteCode(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	_, err := svc.JoinRoom(context.Background(), "user-1", domain.JoinRoomRequest{
		InviteCode: "NONEXIST",
	})
	if err != ErrRoomNotFound {
		t.Errorf("error = %v, want ErrRoomNotFound", err)
	}
}

func TestCollabService_JoinRoom_InactiveRoom(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Inactive", MaxMembers: 10,
	})
	// Deactivate the room.
	repo.DeactivateRoom(context.Background(), room.ID)

	_, err := svc.JoinRoom(context.Background(), "joiner-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != ErrRoomInactive {
		t.Errorf("error = %v, want ErrRoomInactive", err)
	}
}

func TestCollabService_JoinRoom_ExpiredRoom(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Expired", MaxMembers: 10,
	})
	// Set expiry in the past.
	past := time.Now().Add(-1 * time.Hour)
	repo.rooms[room.ID].ExpiresAt = &past

	_, err := svc.JoinRoom(context.Background(), "joiner-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != ErrRoomExpired {
		t.Errorf("error = %v, want ErrRoomExpired", err)
	}
}

func TestCollabService_JoinRoom_FutureExpirySucceeds(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "FutureExpiry", MaxMembers: 10,
	})
	future := time.Now().Add(24 * time.Hour)
	repo.rooms[room.ID].ExpiresAt = &future

	_, err := svc.JoinRoom(context.Background(), "joiner-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != nil {
		t.Fatalf("future expiry should succeed: %v", err)
	}
}

func TestCollabService_JoinRoom_RoomFull(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	// Create room with max 1 member (creator takes that slot).
	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Tiny", MaxMembers: 1,
	})

	_, err := svc.JoinRoom(context.Background(), "joiner-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != ErrRoomFull {
		t.Errorf("error = %v, want ErrRoomFull", err)
	}
}

func TestCollabService_JoinRoom_AlreadyMember(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "AlreadyIn", MaxMembers: 10,
	})

	// Creator tries to join their own room.
	_, err := svc.JoinRoom(context.Background(), "creator-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != ErrAlreadyMember {
		t.Errorf("error = %v, want ErrAlreadyMember", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: LeaveRoom
// ---------------------------------------------------------------------------

func TestCollabService_LeaveRoom_Success(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Leavable", MaxMembers: 10,
	})
	svc.JoinRoom(context.Background(), "joiner-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})

	err := svc.LeaveRoom(context.Background(), "joiner-1", room.ID)
	if err != nil {
		t.Fatalf("LeaveRoom returned error: %v", err)
	}

	isMember, _ := repo.IsMember(context.Background(), room.ID, "joiner-1")
	if isMember {
		t.Error("joiner-1 should no longer be a member after leaving")
	}
}

func TestCollabService_LeaveRoom_NotMember(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Private", MaxMembers: 10,
	})

	err := svc.LeaveRoom(context.Background(), "stranger-1", room.ID)
	if err != ErrNotMember {
		t.Errorf("error = %v, want ErrNotMember", err)
	}
}

func TestCollabService_LeaveRoom_OwnerDeactivates(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "OwnerLeave", MaxMembers: 10,
	})

	err := svc.LeaveRoom(context.Background(), "creator-1", room.ID)
	if err != nil {
		t.Fatalf("LeaveRoom (owner) returned error: %v", err)
	}

	// Room should be deactivated.
	updatedRoom, _ := repo.GetRoomByID(context.Background(), room.ID)
	if updatedRoom.IsActive {
		t.Error("room should be inactive after owner leaves")
	}
}

func TestCollabService_LeaveRoom_NonOwnerDoesNotDeactivate(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "MemberLeave", MaxMembers: 10,
	})
	svc.JoinRoom(context.Background(), "joiner-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})

	err := svc.LeaveRoom(context.Background(), "joiner-1", room.ID)
	if err != nil {
		t.Fatalf("LeaveRoom (member) returned error: %v", err)
	}

	// Room should still be active.
	updatedRoom, _ := repo.GetRoomByID(context.Background(), room.ID)
	if !updatedRoom.IsActive {
		t.Error("room should still be active after non-owner member leaves")
	}
}

func TestCollabService_LeaveRoom_RoomNotFound(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	// When the room does not exist, IsMember returns false first,
	// so ErrNotMember is returned (correct behavior: membership check
	// happens before room lookup).
	err := svc.LeaveRoom(context.Background(), "user-1", "nonexistent-room")
	if err != ErrNotMember {
		t.Errorf("error = %v, want ErrNotMember", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetRoomMembers
// ---------------------------------------------------------------------------

func TestCollabService_GetRoomMembers_Success(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Members", MaxMembers: 10,
	})
	svc.JoinRoom(context.Background(), "joiner-1", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})

	members, err := svc.GetRoomMembers(context.Background(), "creator-1", room.ID)
	if err != nil {
		t.Fatalf("GetRoomMembers returned error: %v", err)
	}
	if len(members) != 2 {
		t.Errorf("members count = %d, want 2", len(members))
	}
}

func TestCollabService_GetRoomMembers_NotMember(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Private", MaxMembers: 10,
	})

	_, err := svc.GetRoomMembers(context.Background(), "stranger-1", room.ID)
	if err != ErrNotMember {
		t.Errorf("error = %v, want ErrNotMember", err)
	}
}

func TestCollabService_GetRoomMembers_EmptyRoom(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	room, _ := svc.CreateRoom(context.Background(), "creator-1", domain.CreateRoomRequest{
		RoomName: "Empty", MaxMembers: 10,
	})
	// Remove the creator (owner leaves).
	svc.LeaveRoom(context.Background(), "creator-1", room.ID)

	// Room is now empty and inactive; trying to get members as the former
	// owner should fail because they are no longer a member.
	_, err := svc.GetRoomMembers(context.Background(), "creator-1", room.ID)
	if err != ErrNotMember {
		t.Errorf("error = %v, want ErrNotMember", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetUserRooms
// ---------------------------------------------------------------------------

func TestCollabService_GetUserRooms_Success(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	_, _ = svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName: "Room A", MaxMembers: 10,
	})
	_, _ = svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName: "Room B", MaxMembers: 10,
	})

	rooms, err := svc.GetUserRooms(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("GetUserRooms returned error: %v", err)
	}
	if len(rooms) != 2 {
		t.Errorf("rooms count = %d, want 2", len(rooms))
	}
}

func TestCollabService_GetUserRooms_NoRooms(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	rooms, err := svc.GetUserRooms(context.Background(), "user-no-rooms")
	if err != nil {
		t.Fatalf("GetUserRooms returned error: %v", err)
	}
	if rooms == nil {
		t.Error("rooms should be non-nil empty slice, got nil")
	}
	if len(rooms) != 0 {
		t.Errorf("rooms count = %d, want 0", len(rooms))
	}
}

func TestCollabService_GetUserRooms_OnlyJoinedRooms(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	// user-1 creates a room
	room, _ := svc.CreateRoom(context.Background(), "user-1", domain.CreateRoomRequest{
		RoomName: "Owned", MaxMembers: 10,
	})

	// user-2 joins
	svc.JoinRoom(context.Background(), "user-2", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})

	// user-3 creates separate room
	svc.CreateRoom(context.Background(), "user-3", domain.CreateRoomRequest{
		RoomName: "Other", MaxMembers: 10,
	})

	// user-2 should see only the room they joined.
	rooms, err := svc.GetUserRooms(context.Background(), "user-2")
	if err != nil {
		t.Fatalf("GetUserRooms returned error: %v", err)
	}
	if len(rooms) != 1 {
		t.Errorf("rooms count = %d, want 1", len(rooms))
	}
	if rooms[0].ID != room.ID {
		t.Errorf("room ID = %q, want %q", rooms[0].ID, room.ID)
	}
}

// ---------------------------------------------------------------------------
// Tests: generateInviteCode
// ---------------------------------------------------------------------------

func TestGenerateInviteCode_Length(t *testing.T) {
	code, err := generateInviteCode(8)
	if err != nil {
		t.Fatalf("generateInviteCode returned error: %v", err)
	}
	if len(code) != 8 {
		t.Errorf("invite code length = %d, want 8", len(code))
	}
}

func TestGenerateInviteCode_Uniqueness(t *testing.T) {
	codes := make(map[string]bool)
	for i := 0; i < 100; i++ {
		code, err := generateInviteCode(8)
		if err != nil {
			t.Fatalf("generateInviteCode returned error: %v", err)
		}
		if codes[code] {
			t.Errorf("duplicate invite code generated: %s", code)
		}
		codes[code] = true
	}
}

func TestGenerateInviteCode_OnlyAllowedChars(t *testing.T) {
	code, err := generateInviteCode(100)
	if err != nil {
		t.Fatalf("generateInviteCode returned error: %v", err)
	}
	const allowed = "23456789ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"
	for _, ch := range code {
		if !strings.ContainsRune(allowed, ch) {
			t.Errorf("invite code contains disallowed character: %c", ch)
		}
	}
}

// ---------------------------------------------------------------------------
// Tests: Multi-user scenario
// ---------------------------------------------------------------------------

func TestCollabService_FullJoinLeaveScenario(t *testing.T) {
	repo := newMockCollabRepo()
	svc := NewCollabService(repo)

	// Step 1: Creator creates room.
	room, err := svc.CreateRoom(context.Background(), "creator", domain.CreateRoomRequest{
		RoomName: "Scenario", MaxMembers: 3,
	})
	if err != nil {
		t.Fatalf("step 1: %v", err)
	}

	// Step 2: User A joins.
	_, err = svc.JoinRoom(context.Background(), "userA", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != nil {
		t.Fatalf("step 2: %v", err)
	}

	// Step 3: User B joins.
	_, err = svc.JoinRoom(context.Background(), "userB", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != nil {
		t.Fatalf("step 3: %v", err)
	}

	// Step 4: Room is now full (3 members).
	_, err = svc.JoinRoom(context.Background(), "userC", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != ErrRoomFull {
		t.Errorf("step 4: error = %v, want ErrRoomFull", err)
	}

	// Step 5: User A leaves; room should still be active.
	err = svc.LeaveRoom(context.Background(), "userA", room.ID)
	if err != nil {
		t.Fatalf("step 5: %v", err)
	}
	updated, _ := repo.GetRoomByID(context.Background(), room.ID)
	if !updated.IsActive {
		t.Error("step 5: room should still be active when non-owner leaves")
	}

	// Step 6: User C can now join (spot freed).
	_, err = svc.JoinRoom(context.Background(), "userC", domain.JoinRoomRequest{
		InviteCode: room.InviteCode,
	})
	if err != nil {
		t.Fatalf("step 6: %v", err)
	}

	// Step 7: Verify final member list.
	members, err := svc.GetRoomMembers(context.Background(), "creator", room.ID)
	if err != nil {
		t.Fatalf("step 7: %v", err)
	}
	if len(members) != 3 {
		t.Errorf("step 7: members = %d, want 3", len(members))
	}

	// Step 8: Creator leaves -> room deactivated.
	err = svc.LeaveRoom(context.Background(), "creator", room.ID)
	if err != nil {
		t.Fatalf("step 8: %v", err)
	}
	updated, _ = repo.GetRoomByID(context.Background(), room.ID)
	if updated.IsActive {
		t.Error("step 8: room should be inactive after owner leaves")
	}
}
