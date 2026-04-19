package service

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

// ---------------------------------------------------------------------------
// miniredis helpers
// ---------------------------------------------------------------------------

func setupMiniredis(t *testing.T) (*miniredis.Miniredis, *redis.Client) {
	t.Helper()
	mr := miniredis.RunT(t)
	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	t.Cleanup(func() { rdb.Close() })
	return mr, rdb
}

// ---------------------------------------------------------------------------
// Tests: NewPresenceService
// ---------------------------------------------------------------------------

func TestNewPresenceService(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)
	if svc == nil {
		t.Fatal("NewPresenceService returned nil")
	}
}

// ---------------------------------------------------------------------------
// Tests: Join
// ---------------------------------------------------------------------------

func TestPresenceService_Join_Success(t *testing.T) {
	mr, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.Join(context.Background(), "room-1", "user-1", "alice")
	if err != nil {
		t.Fatalf("Join: %v", err)
	}

	// Verify the member was stored in Redis.
	mr.FastForward(0)
	key := roomMembersKey("room-1")
	data, err := rdb.HGet(context.Background(), key, "user-1").Result()
	if err != nil {
		t.Fatalf("HGet: %v", err)
	}
	var member RoomMember
	if err := json.Unmarshal([]byte(data), &member); err != nil {
		t.Fatalf("Unmarshal member: %v", err)
	}
	if member.UserID != "user-1" {
		t.Errorf("UserID = %q, want %q", member.UserID, "user-1")
	}
	if member.Username != "alice" {
		t.Errorf("Username = %q, want %q", member.Username, "alice")
	}
}

func TestPresenceService_Join_EmptyRoom(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.Join(context.Background(), "", "user-1", "alice")
	if err != ErrRoomRequired {
		t.Errorf("Join with empty room: err = %v, want ErrRoomRequired", err)
	}
}

func TestPresenceService_Join_EmptyUserID(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.Join(context.Background(), "room-1", "", "alice")
	if err != ErrUserIDRequired {
		t.Errorf("Join with empty userID: err = %v, want ErrUserIDRequired", err)
	}
}

func TestPresenceService_Join_MultipleUsers(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx := context.Background()
	_ = svc.Join(ctx, "room-1", "user-1", "alice")
	_ = svc.Join(ctx, "room-1", "user-2", "bob")

	members, err := svc.GetRoomMembers(ctx, "room-1")
	if err != nil {
		t.Fatalf("GetRoomMembers: %v", err)
	}
	if len(members) != 2 {
		t.Errorf("len(members) = %d, want 2", len(members))
	}
}

// ---------------------------------------------------------------------------
// Tests: Leave
// ---------------------------------------------------------------------------

func TestPresenceService_Leave_Success(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx := context.Background()
	_ = svc.Join(ctx, "room-1", "user-1", "alice")

	err := svc.Leave(ctx, "room-1", "user-1")
	if err != nil {
		t.Fatalf("Leave: %v", err)
	}

	// Verify the member was removed.
	members, _ := svc.GetRoomMembers(ctx, "room-1")
	if len(members) != 0 {
		t.Errorf("len(members) after leave = %d, want 0", len(members))
	}
}

func TestPresenceService_Leave_NotInRoom(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.Leave(context.Background(), "room-1", "user-1")
	if err != ErrNotInRoom {
		t.Errorf("Leave not-in-room: err = %v, want ErrNotInRoom", err)
	}
}

func TestPresenceService_Leave_EmptyRoom(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.Leave(context.Background(), "", "user-1")
	if err != ErrRoomRequired {
		t.Errorf("Leave with empty room: err = %v, want ErrRoomRequired", err)
	}
}

func TestPresenceService_Leave_EmptyUserID(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.Leave(context.Background(), "room-1", "")
	if err != ErrUserIDRequired {
		t.Errorf("Leave with empty userID: err = %v, want ErrUserIDRequired", err)
	}
}

func TestPresenceService_Leave_ClearsTyping(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx := context.Background()
	_ = svc.Join(ctx, "room-1", "user-1", "alice")
	_ = svc.SetTyping(ctx, "room-1", "user-1", true)

	// Leave should clear typing indicator.
	_ = svc.Leave(ctx, "room-1", "user-1")

	typing, _ := svc.GetTypingUsers(ctx, "room-1")
	if len(typing) != 0 {
		t.Errorf("len(typing) after leave = %d, want 0", len(typing))
	}
}

// ---------------------------------------------------------------------------
// Tests: GetRoomMembers
// ---------------------------------------------------------------------------

func TestPresenceService_GetRoomMembers_Empty(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	members, err := svc.GetRoomMembers(context.Background(), "room-empty")
	if err != nil {
		t.Fatalf("GetRoomMembers: %v", err)
	}
	if len(members) != 0 {
		t.Errorf("len(members) = %d, want 0", len(members))
	}
}

func TestPresenceService_GetRoomMembers_EmptyRoom(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	_, err := svc.GetRoomMembers(context.Background(), "")
	if err != ErrRoomRequired {
		t.Errorf("GetRoomMembers with empty room: err = %v, want ErrRoomRequired", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: SetTyping
// ---------------------------------------------------------------------------

func TestPresenceService_SetTyping_True(t *testing.T) {
	mr, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.SetTyping(context.Background(), "room-1", "user-1", true)
	if err != nil {
		t.Fatalf("SetTyping: %v", err)
	}

	// Verify the typing key exists.
	mr.FastForward(0)
	key := typingKey("room-1", "user-1")
	val, err := rdb.Get(context.Background(), key).Result()
	if err != nil {
		t.Fatalf("Get typing key: %v", err)
	}
	if val != "1" {
		t.Errorf("typing value = %q, want %q", val, "1")
	}
}

func TestPresenceService_SetTyping_False(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx := context.Background()
	_ = svc.SetTyping(ctx, "room-1", "user-1", true)
	_ = svc.SetTyping(ctx, "room-1", "user-1", false)

	typing, _ := svc.GetTypingUsers(ctx, "room-1")
	if len(typing) != 0 {
		t.Errorf("len(typing) after clear = %d, want 0", len(typing))
	}
}

func TestPresenceService_SetTyping_EmptyRoom(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.SetTyping(context.Background(), "", "user-1", true)
	if err != ErrRoomRequired {
		t.Errorf("SetTyping with empty room: err = %v, want ErrRoomRequired", err)
	}
}

func TestPresenceService_SetTyping_EmptyUserID(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	err := svc.SetTyping(context.Background(), "room-1", "", true)
	if err != ErrUserIDRequired {
		t.Errorf("SetTyping with empty userID: err = %v, want ErrUserIDRequired", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetTypingUsers
// ---------------------------------------------------------------------------

func TestPresenceService_GetTypingUsers_None(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	users, err := svc.GetTypingUsers(context.Background(), "room-1")
	if err != nil {
		t.Fatalf("GetTypingUsers: %v", err)
	}
	if len(users) != 0 {
		t.Errorf("len(users) = %d, want 0", len(users))
	}
}

func TestPresenceService_GetTypingUsers_Multiple(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx := context.Background()
	_ = svc.SetTyping(ctx, "room-1", "user-1", true)
	_ = svc.SetTyping(ctx, "room-1", "user-2", true)

	users, err := svc.GetTypingUsers(ctx, "room-1")
	if err != nil {
		t.Fatalf("GetTypingUsers: %v", err)
	}
	if len(users) != 2 {
		t.Errorf("len(users) = %d, want 2", len(users))
	}
}

func TestPresenceService_GetTypingUsers_EmptyRoom(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	_, err := svc.GetTypingUsers(context.Background(), "")
	if err != ErrRoomRequired {
		t.Errorf("GetTypingUsers with empty room: err = %v, want ErrRoomRequired", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: BroadcastToRoom
// ---------------------------------------------------------------------------

func TestPresenceService_BroadcastToRoom_Success(t *testing.T) {
	mr, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	msg := WSMessage{Type: "ping", Data: json.RawMessage(`{}`)}
	err := svc.BroadcastToRoom(context.Background(), "room-1", msg)
	if err != nil {
		t.Fatalf("BroadcastToRoom: %v", err)
	}

	// Verify the message was published.
	mr.FastForward(0)
	// Miniredis Publish works; we can verify through SubscribeRoom.
}

func TestPresenceService_BroadcastToRoom_EmptyRoom(t *testing.T) {
	_, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	msg := WSMessage{Type: "ping", Data: json.RawMessage(`{}`)}
	err := svc.BroadcastToRoom(context.Background(), "", msg)
	if err != ErrRoomRequired {
		t.Errorf("BroadcastToRoom with empty room: err = %v, want ErrRoomRequired", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: SubscribeRoom
// ---------------------------------------------------------------------------

func TestPresenceService_SubscribeRoom_ReceivesMessage(t *testing.T) {
	mr, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	ch := svc.SubscribeRoom(ctx, "room-1")

	// Give the subscription a moment to be ready.
	time.Sleep(50 * time.Millisecond)

	// Broadcast a message.
	msg := WSMessage{Type: "test", Data: json.RawMessage(`{"key":"value"}`)}
	_ = svc.BroadcastToRoom(ctx, "room-1", msg)

	// Fast-forward miniredis to deliver the message.
	mr.FastForward(0)

	// Wait for the message.
	select {
	case received := <-ch:
		if received.Type != "test" {
			t.Errorf("received.Type = %q, want %q", received.Type, "test")
		}
	case <-time.After(1 * time.Second):
		t.Error("timeout waiting for message")
	}
}

// ---------------------------------------------------------------------------
// Tests: Join broadcasts via SubscribeRoom
// ---------------------------------------------------------------------------

func TestPresenceService_Join_BroadcastsJoinEvent(t *testing.T) {
	mr, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	ch := svc.SubscribeRoom(ctx, "room-1")
	time.Sleep(50 * time.Millisecond)

	err := svc.Join(ctx, "room-1", "user-1", "alice")
	if err != nil {
		t.Fatalf("Join: %v", err)
	}
	mr.FastForward(0)

	select {
	case msg := <-ch:
		if msg.Type != "join" {
			t.Errorf("msg.Type = %q, want %q", msg.Type, "join")
		}
	case <-time.After(1 * time.Second):
		t.Error("timeout waiting for join event")
	}
}

// ---------------------------------------------------------------------------
// Tests: Leave broadcasts via SubscribeRoom
// ---------------------------------------------------------------------------

func TestPresenceService_Leave_BroadcastsLeaveEvent(t *testing.T) {
	mr, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// Join first to consume the join event.
	_ = svc.Join(ctx, "room-1", "user-1", "alice")

	ch := svc.SubscribeRoom(ctx, "room-1")
	time.Sleep(50 * time.Millisecond)

	err := svc.Leave(ctx, "room-1", "user-1")
	if err != nil {
		t.Fatalf("Leave: %v", err)
	}
	mr.FastForward(0)

	// Leave broadcasts two events: typing clear + leave.
	// Read messages until we find the leave event.
	foundLeave := false
	timeout := time.After(1 * time.Second)
	for !foundLeave {
		select {
		case msg := <-ch:
			if msg.Type == "leave" {
				foundLeave = true
			}
		case <-timeout:
			t.Error("timeout waiting for leave event")
			return
		}
	}
}

// ---------------------------------------------------------------------------
// Tests: SetTyping broadcasts via SubscribeRoom
// ---------------------------------------------------------------------------

func TestPresenceService_SetTyping_BroadcastsTypingEvent(t *testing.T) {
	mr, rdb := setupMiniredis(t)
	svc := NewPresenceService(rdb)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	ch := svc.SubscribeRoom(ctx, "room-1")
	time.Sleep(50 * time.Millisecond)

	err := svc.SetTyping(ctx, "room-1", "user-1", true)
	if err != nil {
		t.Fatalf("SetTyping: %v", err)
	}
	mr.FastForward(0)

	select {
	case msg := <-ch:
		if msg.Type != "typing" {
			t.Errorf("msg.Type = %q, want %q", msg.Type, "typing")
		}
	case <-time.After(1 * time.Second):
		t.Error("timeout waiting for typing event")
	}
}
