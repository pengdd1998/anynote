package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// Sentinel errors for the presence service.
var (
	ErrRoomRequired    = errors.New("room identifier is required")
	ErrUserIDRequired  = errors.New("user_id is required")
	ErrNotInRoom       = errors.New("user is not in the room")
)

// RoomMember represents a user present in a collaboration room.
type RoomMember struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	JoinedAt int64  `json:"joined_at"` // Unix timestamp
}

// WSMessage is the envelope for all WebSocket messages.
type WSMessage struct {
	Type string          `json:"type"` // "join", "leave", "presence", "typing", "comment", "ping", "pong"
	Data json.RawMessage `json:"data"`
}

// PresenceService manages real-time room presence via Redis.
type PresenceService interface {
	// Join adds a user to a room and publishes a join event.
	Join(ctx context.Context, room, userID, username string) error
	// Leave removes a user from a room and publishes a leave event.
	Leave(ctx context.Context, room, userID string) error
	// GetRoomMembers returns all members currently in a room.
	GetRoomMembers(ctx context.Context, room string) ([]RoomMember, error)
	// SetTyping sets or clears a typing indicator for a user in a room.
	SetTyping(ctx context.Context, room, userID string, isTyping bool) error
	// GetTypingUsers returns user IDs of users currently typing in a room.
	GetTypingUsers(ctx context.Context, room string) ([]string, error)
	// BroadcastToRoom publishes a message to all subscribers of a room.
	BroadcastToRoom(ctx context.Context, room string, msg WSMessage) error
	// SubscribeRoom returns a channel that receives messages published to the room.
	SubscribeRoom(ctx context.Context, room string) <-chan WSMessage
}

// presenceService implements PresenceService using Redis.
type presenceService struct {
	rdb *redis.Client
}

// NewPresenceService creates a new PresenceService backed by Redis.
func NewPresenceService(rdb *redis.Client) PresenceService {
	return &presenceService{rdb: rdb}
}

// redisKey for room members: presence:room:{room}
func roomMembersKey(room string) string {
	return fmt.Sprintf("presence:room:%s", room)
}

// redisKey for typing indicator: typing:room:{room}:{userID}
func typingKey(room, userID string) string {
	return fmt.Sprintf("typing:room:%s:%s", room, userID)
}

// redisChannel for room pub/sub: room:{room}
func roomChannel(room string) string {
	return fmt.Sprintf("room:%s", room)
}

func (s *presenceService) Join(ctx context.Context, room, userID, username string) error {
	if room == "" {
		return ErrRoomRequired
	}
	if userID == "" {
		return ErrUserIDRequired
	}

	member := RoomMember{
		UserID:   userID,
		Username: username,
		JoinedAt: time.Now().Unix(),
	}

	data, err := json.Marshal(member)
	if err != nil {
		return fmt.Errorf("marshal room member: %w", err)
	}

	// Add member to the room's Redis set.
	key := roomMembersKey(room)
	if err := s.rdb.HSet(ctx, key, userID, data).Err(); err != nil {
		return fmt.Errorf("redis HSet member: %w", err)
	}

	// Publish join event to the room channel.
	joinData, _ := json.Marshal(map[string]string{
		"user_id":  userID,
		"username": username,
	})
	msg := WSMessage{Type: "join", Data: joinData}
	return s.BroadcastToRoom(ctx, room, msg)
}

func (s *presenceService) Leave(ctx context.Context, room, userID string) error {
	if room == "" {
		return ErrRoomRequired
	}
	if userID == "" {
		return ErrUserIDRequired
	}

	// Remove member from the room's Redis hash.
	key := roomMembersKey(room)
	removed, err := s.rdb.HDel(ctx, key, userID).Result()
	if err != nil {
		return fmt.Errorf("redis HDel member: %w", err)
	}
	if removed == 0 {
		return ErrNotInRoom
	}

	// Clear any typing indicator.
	_ = s.SetTyping(ctx, room, userID, false)

	// Publish leave event.
	leaveData, _ := json.Marshal(map[string]string{
		"user_id": userID,
	})
	msg := WSMessage{Type: "leave", Data: leaveData}
	return s.BroadcastToRoom(ctx, room, msg)
}

func (s *presenceService) GetRoomMembers(ctx context.Context, room string) ([]RoomMember, error) {
	if room == "" {
		return nil, ErrRoomRequired
	}

	key := roomMembersKey(room)
	result, err := s.rdb.HGetAll(ctx, key).Result()
	if err != nil {
		return nil, fmt.Errorf("redis HGetAll members: %w", err)
	}

	members := make([]RoomMember, 0, len(result))
	for _, raw := range result {
		var m RoomMember
		if err := json.Unmarshal([]byte(raw), &m); err != nil {
			continue // skip malformed entries
		}
		members = append(members, m)
	}
	return members, nil
}

func (s *presenceService) SetTyping(ctx context.Context, room, userID string, isTyping bool) error {
	if room == "" {
		return ErrRoomRequired
	}
	if userID == "" {
		return ErrUserIDRequired
	}

	key := typingKey(room, userID)
	if isTyping {
		// 3-second TTL; client must re-send typing indicator to keep it active.
		if err := s.rdb.Set(ctx, key, "1", 3*time.Second).Err(); err != nil {
			return fmt.Errorf("redis Set typing: %w", err)
		}
	} else {
		s.rdb.Del(ctx, key)
	}

	// Broadcast typing state change.
	typingData, _ := json.Marshal(map[string]interface{}{
		"user_id":    userID,
		"is_typing":  isTyping,
	})
	msg := WSMessage{Type: "typing", Data: typingData}
	return s.BroadcastToRoom(ctx, room, msg)
}

func (s *presenceService) GetTypingUsers(ctx context.Context, room string) ([]string, error) {
	if room == "" {
		return nil, ErrRoomRequired
	}

	// Match keys: typing:room:{room}:*
	pattern := fmt.Sprintf("typing:room:%s:*", room)
	var users []string

	var cursor uint64
	for {
		keys, nextCursor, err := s.rdb.Scan(ctx, cursor, pattern, 100).Result()
		if err != nil {
			return nil, fmt.Errorf("redis Scan typing keys: %w", err)
		}
		for _, k := range keys {
			// Extract userID from the key suffix.
			// Key format: typing:room:{room}:{userID}
			userID := splitLastN(k, ':')
			if userID != "" {
				users = append(users, userID)
			}
		}
		cursor = nextCursor
		if cursor == 0 {
			break
		}
	}
	return users, nil
}

func (s *presenceService) BroadcastToRoom(ctx context.Context, room string, msg WSMessage) error {
	if room == "" {
		return ErrRoomRequired
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("marshal WSMessage: %w", err)
	}

	if err := s.rdb.Publish(ctx, roomChannel(room), data).Err(); err != nil {
		return fmt.Errorf("redis Publish: %w", err)
	}
	return nil
}

func (s *presenceService) SubscribeRoom(ctx context.Context, room string) <-chan WSMessage {
	ch := make(chan WSMessage, 64)

	sub := s.rdb.Subscribe(ctx, roomChannel(room))
	go func() {
		defer close(ch)
		msgCh := sub.Channel()
		for msg := range msgCh {
			var wsMsg WSMessage
			if err := json.Unmarshal([]byte(msg.Payload), &wsMsg); err != nil {
				continue // skip malformed messages
			}
			select {
			case ch <- wsMsg:
			default:
				// Drop message if channel is full; prevents slow consumer blocking.
			}
		}
	}()

	return ch
}

// splitLastN splits on the last occurrence of sep.
func splitLastN(s string, sep byte) string {
	for i := len(s) - 1; i >= 0; i-- {
		if s[i] == sep {
			return s[i+1:]
		}
	}
	return s
}
