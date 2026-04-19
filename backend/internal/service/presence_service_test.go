package service

import (
	"encoding/json"
	"testing"
)

// ---------------------------------------------------------------------------
// Tests: splitLastN helper
// ---------------------------------------------------------------------------

func TestSplitLastN(t *testing.T) {
	tests := []struct {
		input string
		sep   byte
		want  string
	}{
		{"typing:room:myroom:user123", ':', "user123"},
		{"typing:room:myroom:", ':', ""},
		{"no-separator", ':', "no-separator"},
		{"a:b", ':', "b"},
		{"", ':', ""},
		{"only-one-part", ':', "only-one-part"},
		{"multi:level:key:here", ':', "here"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := splitLastN(tt.input, tt.sep)
			if got != tt.want {
				t.Errorf("splitLastN(%q, %q) = %q, want %q", tt.input, string(tt.sep), got, tt.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Tests: Redis key helpers
// ---------------------------------------------------------------------------

func TestRoomMembersKey(t *testing.T) {
	key := roomMembersKey("test-room")
	if key != "presence:room:test-room" {
		t.Errorf("roomMembersKey = %q, want %q", key, "presence:room:test-room")
	}
}

func TestTypingKey(t *testing.T) {
	key := typingKey("room-1", "user-1")
	if key != "typing:room:room-1:user-1" {
		t.Errorf("typingKey = %q, want %q", key, "typing:room:room-1:user-1")
	}
}

func TestRoomChannel(t *testing.T) {
	ch := roomChannel("my-room")
	if ch != "room:my-room" {
		t.Errorf("roomChannel = %q, want %q", ch, "room:my-room")
	}
}

// ---------------------------------------------------------------------------
// Tests: Sentinel errors
// ---------------------------------------------------------------------------

func TestPresenceSentinelErrors(t *testing.T) {
	if ErrRoomRequired == nil {
		t.Error("ErrRoomRequired should not be nil")
	}
	if ErrUserIDRequired == nil {
		t.Error("ErrUserIDRequired should not be nil")
	}
	if ErrNotInRoom == nil {
		t.Error("ErrNotInRoom should not be nil")
	}

	if ErrRoomRequired.Error() != "room identifier is required" {
		t.Errorf("ErrRoomRequired = %q, want %q", ErrRoomRequired.Error(), "room identifier is required")
	}
	if ErrUserIDRequired.Error() != "user_id is required" {
		t.Errorf("ErrUserIDRequired = %q, want %q", ErrUserIDRequired.Error(), "user_id is required")
	}
	if ErrNotInRoom.Error() != "user is not in the room" {
		t.Errorf("ErrNotInRoom = %q, want %q", ErrNotInRoom.Error(), "user is not in the room")
	}
}

// ---------------------------------------------------------------------------
// Tests: RoomMember JSON serialization
// ---------------------------------------------------------------------------

func TestRoomMember_JSON(t *testing.T) {
	member := RoomMember{
		UserID:   "user-123",
		Username: "alice",
		JoinedAt: 1700000000,
	}

	data, err := json.Marshal(member)
	if err != nil {
		t.Fatalf("Marshal RoomMember: %v", err)
	}

	var decoded RoomMember
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal RoomMember: %v", err)
	}

	if decoded.UserID != "user-123" {
		t.Errorf("UserID = %q, want %q", decoded.UserID, "user-123")
	}
	if decoded.Username != "alice" {
		t.Errorf("Username = %q, want %q", decoded.Username, "alice")
	}
	if decoded.JoinedAt != 1700000000 {
		t.Errorf("JoinedAt = %d, want %d", decoded.JoinedAt, 1700000000)
	}
}

// ---------------------------------------------------------------------------
// Tests: WSMessage JSON serialization
// ---------------------------------------------------------------------------

func TestWSMessage_JSON(t *testing.T) {
	msg := WSMessage{
		Type: "ping",
		Data: json.RawMessage(`{}`),
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Marshal WSMessage: %v", err)
	}

	var decoded WSMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal WSMessage: %v", err)
	}

	if decoded.Type != "ping" {
		t.Errorf("Type = %q, want %q", decoded.Type, "ping")
	}
}

func TestWSMessage_Types(t *testing.T) {
	types := []string{"join", "leave", "presence", "typing", "comment", "edit", "cursor", "ping", "pong", "error"}
	for _, typ := range types {
		msg := WSMessage{Type: typ, Data: json.RawMessage(`{}`)}
		data, err := json.Marshal(msg)
		if err != nil {
			t.Errorf("Marshal type %q: %v", typ, err)
			continue
		}
		var decoded WSMessage
		if err := json.Unmarshal(data, &decoded); err != nil {
			t.Errorf("Unmarshal type %q: %v", typ, err)
			continue
		}
		if decoded.Type != typ {
			t.Errorf("Type = %q, want %q", decoded.Type, typ)
		}
	}
}

func TestWSMessage_SenderRoomID(t *testing.T) {
	msg := WSMessage{
		Type:   "edit",
		Data:   json.RawMessage(`{"ops":[],"version":1}`),
		Sender: "user-99",
		RoomID: "room-abc",
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal WSMessage: %v", err)
	}

	var decoded WSMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal WSMessage: %v", err)
	}
	if decoded.Sender != "user-99" {
		t.Errorf("Sender = %q, want %q", decoded.Sender, "user-99")
	}
	if decoded.RoomID != "room-abc" {
		t.Errorf("RoomID = %q, want %q", decoded.RoomID, "room-abc")
	}
}

func TestWSMessage_SenderRoomID_Omitempty(t *testing.T) {
	msg := WSMessage{
		Type: "ping",
		Data: json.RawMessage(`{}`),
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal WSMessage: %v", err)
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("unmarshal to raw map: %v", err)
	}
	if _, exists := raw["sender"]; exists {
		t.Error("sender should be omitted when empty")
	}
	if _, exists := raw["room_id"]; exists {
		t.Error("room_id should be omitted when empty")
	}
}
