package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock PresenceService
// ---------------------------------------------------------------------------

type mockPresenceService struct {
	joinFn          func(ctx context.Context, room, userID, username string) error
	leaveFn         func(ctx context.Context, room, userID string) error
	getRoomMembersFn func(ctx context.Context, room string) ([]service.RoomMember, error)
	setTypingFn     func(ctx context.Context, room, userID string, isTyping bool) error
	getTypingUsersFn func(ctx context.Context, room string) ([]string, error)
	broadcastFn     func(ctx context.Context, room string, msg service.WSMessage) error
	subscribeRoomFn func(ctx context.Context, room string) <-chan service.WSMessage
}

func (m *mockPresenceService) Join(ctx context.Context, room, userID, username string) error {
	if m.joinFn != nil {
		return m.joinFn(ctx, room, userID, username)
	}
	return nil
}

func (m *mockPresenceService) Leave(ctx context.Context, room, userID string) error {
	if m.leaveFn != nil {
		return m.leaveFn(ctx, room, userID)
	}
	return nil
}

func (m *mockPresenceService) GetRoomMembers(ctx context.Context, room string) ([]service.RoomMember, error) {
	if m.getRoomMembersFn != nil {
		return m.getRoomMembersFn(ctx, room)
	}
	return []service.RoomMember{}, nil
}

func (m *mockPresenceService) SetTyping(ctx context.Context, room, userID string, isTyping bool) error {
	if m.setTypingFn != nil {
		return m.setTypingFn(ctx, room, userID, isTyping)
	}
	return nil
}

func (m *mockPresenceService) GetTypingUsers(ctx context.Context, room string) ([]string, error) {
	if m.getTypingUsersFn != nil {
		return m.getTypingUsersFn(ctx, room)
	}
	return nil, nil
}

func (m *mockPresenceService) BroadcastToRoom(ctx context.Context, room string, msg service.WSMessage) error {
	if m.broadcastFn != nil {
		return m.broadcastFn(ctx, room, msg)
	}
	return nil
}

func (m *mockPresenceService) SubscribeRoom(ctx context.Context, room string) <-chan service.WSMessage {
	if m.subscribeRoomFn != nil {
		return m.subscribeRoomFn(ctx, room)
	}
	ch := make(chan service.WSMessage)
	close(ch)
	return ch
}

func (m *mockPresenceService) Heartbeat(ctx context.Context, room string) error { return nil }

// ---------------------------------------------------------------------------
// Tests: NewWSHandler
// ---------------------------------------------------------------------------

func TestNewWSHandler(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := NewWSHandler(presenceSvc, nil, nil, "jwt-secret", nil)
	if h == nil {
		t.Fatal("NewWSHandler returned nil")
	}
	if h.jwtSecret != "jwt-secret" {
		t.Errorf("jwtSecret = %q, want %q", h.jwtSecret, "jwt-secret")
	}
}

func TestNewWSHandler_AllowedOrigins(t *testing.T) {
	presenceSvc := &mockPresenceService{}

	t.Run("empty origins falls back to wildcard", func(t *testing.T) {
		h := NewWSHandler(presenceSvc, nil, nil, "jwt-secret", nil)
		patterns := h.originPatterns()
		if len(patterns) != 1 || patterns[0] != "*" {
			t.Errorf("originPatterns() = %v, want [*]", patterns)
		}
	})

	t.Run("configured origins returned as-is", func(t *testing.T) {
		origins := []string{"https://app.example.com", "https://web.example.com"}
		h := NewWSHandler(presenceSvc, nil, nil, "jwt-secret", origins)
		patterns := h.originPatterns()
		if len(patterns) != 2 {
			t.Fatalf("originPatterns() returned %d patterns, want 2", len(patterns))
		}
		if patterns[0] != "https://app.example.com" {
			t.Errorf("patterns[0] = %q, want %q", patterns[0], "https://app.example.com")
		}
		if patterns[1] != "https://web.example.com" {
			t.Errorf("patterns[1] = %q, want %q", patterns[1], "https://web.example.com")
		}
	})
}

// ---------------------------------------------------------------------------
// Tests: validateToken (tested via HandleConnection HTTP responses)
// ---------------------------------------------------------------------------

func TestWSHandler_HandleConnection_MissingToken(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := NewWSHandler(presenceSvc, nil, nil, testJWTSecret, nil)

	req := httptest.NewRequest(http.MethodGet, "/ws?room=test-room", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnauthorized, rec.Body.String())
	}
}

func TestWSHandler_HandleConnection_InvalidToken(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := NewWSHandler(presenceSvc, nil, nil, testJWTSecret, nil)

	req := httptest.NewRequest(http.MethodGet, "/ws?token=invalid-token&room=test-room", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnauthorized, rec.Body.String())
	}
}

func TestWSHandler_HandleConnection_MissingRoom(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := NewWSHandler(presenceSvc, nil, nil, testJWTSecret, nil)

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	req := httptest.NewRequest(http.MethodGet, "/ws?token="+token, nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: validateToken directly (unit test the internal method)
// ---------------------------------------------------------------------------

func TestWSHandler_ValidateToken_Valid(t *testing.T) {
	h := &WSHandler{jwtSecret: testJWTSecret}

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	gotUserID, err := h.validateToken(token)
	if err != nil {
		t.Fatalf("validateToken returned error: %v", err)
	}
	if gotUserID != userID {
		t.Errorf("userID = %q, want %q", gotUserID, userID)
	}
}

func TestWSHandler_ValidateToken_Expired(t *testing.T) {
	h := &WSHandler{jwtSecret: testJWTSecret}

	// Create an expired token.
	claims := jwt.MapClaims{
		"user_id": uuid.New().String(),
		"iat":     time.Now().Add(-2 * time.Hour).Unix(),
		"exp":     time.Now().Add(-1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(testJWTSecret))

	_, err := h.validateToken(tokenStr)
	if err == nil {
		t.Error("expected error for expired token, got nil")
	}
}

func TestWSHandler_ValidateToken_WrongSecret(t *testing.T) {
	h := &WSHandler{jwtSecret: "correct-secret"}

	// Sign with a different secret.
	claims := jwt.MapClaims{
		"user_id": uuid.New().String(),
		"exp":     time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte("wrong-secret"))

	_, err := h.validateToken(tokenStr)
	if err == nil {
		t.Error("expected error for wrong secret, got nil")
	}
}

func TestWSHandler_ValidateToken_MissingUserID(t *testing.T) {
	h := &WSHandler{jwtSecret: testJWTSecret}

	// Token without user_id claim.
	claims := jwt.MapClaims{
		"email": "test@example.com",
		"exp":   time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(testJWTSecret))

	_, err := h.validateToken(tokenStr)
	if err == nil {
		t.Error("expected error for missing user_id, got nil")
	}
}

func TestWSHandler_ValidateToken_EmptyUserID(t *testing.T) {
	h := &WSHandler{jwtSecret: testJWTSecret}

	claims := jwt.MapClaims{
		"user_id": "",
		"exp":     time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(testJWTSecret))

	_, err := h.validateToken(tokenStr)
	if err == nil {
		t.Error("expected error for empty user_id, got nil")
	}
}

func TestWSHandler_ValidateToken_InvalidSigningMethod(t *testing.T) {
	h := &WSHandler{jwtSecret: testJWTSecret}

	// Use signing method none (should be rejected).
	claims := jwt.MapClaims{
		"user_id": uuid.New().String(),
		"exp":     time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	tokenStr, _ := token.SignedString(jwt.UnsafeAllowNoneSignatureType)

	_, err := h.validateToken(tokenStr)
	if err == nil {
		t.Error("expected error for invalid signing method, got nil")
	}
}

// ---------------------------------------------------------------------------
// Tests: handleTyping
// ---------------------------------------------------------------------------

func TestWSHandler_HandleTyping_SetTyping(t *testing.T) {
	var capturedRoom, capturedUserID string
	var capturedIsTyping bool

	presenceSvc := &mockPresenceService{
		setTypingFn: func(ctx context.Context, room, userID string, isTyping bool) error {
			capturedRoom = room
			capturedUserID = userID
			capturedIsTyping = isTyping
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}

	data := json.RawMessage(`{"is_typing": true}`)
	h.handleTyping(context.Background(), "room-1", "user-1", data)

	if capturedRoom != "room-1" {
		t.Errorf("room = %q, want %q", capturedRoom, "room-1")
	}
	if capturedUserID != "user-1" {
		t.Errorf("userID = %q, want %q", capturedUserID, "user-1")
	}
	if !capturedIsTyping {
		t.Error("isTyping should be true")
	}
}

func TestWSHandler_HandleTyping_NotTyping(t *testing.T) {
	var capturedIsTyping bool

	presenceSvc := &mockPresenceService{
		setTypingFn: func(ctx context.Context, room, userID string, isTyping bool) error {
			capturedIsTyping = isTyping
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}

	data := json.RawMessage(`{"is_typing": false}`)
	h.handleTyping(context.Background(), "room-1", "user-1", data)

	if capturedIsTyping {
		t.Error("isTyping should be false")
	}
}

func TestWSHandler_HandleTyping_InvalidData(t *testing.T) {
	// Malformed JSON should be silently ignored (no panic, no error).
	presenceSvc := &mockPresenceService{
		setTypingFn: func(ctx context.Context, room, userID string, isTyping bool) error {
			t.Error("SetTyping should not be called for invalid data")
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}

	data := json.RawMessage(`not-json`)
	h.handleTyping(context.Background(), "room-1", "user-1", data)
}

func TestWSHandler_HandleTyping_ServiceError(t *testing.T) {
	// Service errors in handleTyping should be silently handled (logged, not panicked).
	presenceSvc := &mockPresenceService{
		setTypingFn: func(ctx context.Context, room, userID string, isTyping bool) error {
			return errors.New("redis connection lost")
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}

	data := json.RawMessage(`{"is_typing": true}`)
	// Should not panic.
	h.handleTyping(context.Background(), "room-1", "user-1", data)
}

// ---------------------------------------------------------------------------
// Tests: wsWriteJSON
// ---------------------------------------------------------------------------

func TestWSWriteJSON_Marshal(t *testing.T) {
	msg := service.WSMessage{
		Type: "pong",
		Data: json.RawMessage(`{}`),
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal WSMessage: %v", err)
	}

	var decoded service.WSMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal WSMessage: %v", err)
	}
	if decoded.Type != "pong" {
		t.Errorf("Type = %q, want %q", decoded.Type, "pong")
	}
}

// ---------------------------------------------------------------------------
// Tests: clientRateLimiter
// ---------------------------------------------------------------------------

func TestClientRateLimiter_AllowsUnderLimit(t *testing.T) {
	limiter := newClientRateLimiter(3, 1*time.Second)

	for i := 0; i < 3; i++ {
		if !limiter.Allow() {
			t.Fatalf("Allow() should return true for call %d under limit", i+1)
		}
	}
}

func TestClientRateLimiter_BlocksOverLimit(t *testing.T) {
	limiter := newClientRateLimiter(2, 1*time.Second)

	if !limiter.Allow() {
		t.Fatal("first Allow() should succeed")
	}
	if !limiter.Allow() {
		t.Fatal("second Allow() should succeed")
	}
	if limiter.Allow() {
		t.Fatal("third Allow() should be rate limited")
	}
}

func TestClientRateLimiter_WindowExpires(t *testing.T) {
	limiter := newClientRateLimiter(1, 50*time.Millisecond)

	if !limiter.Allow() {
		t.Fatal("first Allow() should succeed")
	}
	if limiter.Allow() {
		t.Fatal("second Allow() should be rate limited")
	}

	// Wait for the window to expire.
	time.Sleep(60 * time.Millisecond)

	if !limiter.Allow() {
		t.Fatal("Allow() should succeed after window expires")
	}
}

func TestClientRateLimiter_SingleRequest(t *testing.T) {
	limiter := newClientRateLimiter(1, 1*time.Second)

	if !limiter.Allow() {
		t.Fatal("single request should be allowed")
	}
	if limiter.Allow() {
		t.Fatal("second request should be blocked")
	}
}

// ---------------------------------------------------------------------------
// Tests: handleEdit
// ---------------------------------------------------------------------------

func TestWSHandler_HandleEdit_Broadcasts(t *testing.T) {
	var capturedRoom string
	var capturedMsg service.WSMessage

	presenceSvc := &mockPresenceService{
		broadcastFn: func(ctx context.Context, room string, msg service.WSMessage) error {
			capturedRoom = room
			capturedMsg = msg
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	editData := json.RawMessage(`{"ops":[{"type":"insert","pos":0,"text":"hello"}],"version":1}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	// handleEdit requires a conn, but for this test we only care about broadcast.
	// We pass nil for conn since the rate limit should not be hit.
	h.handleEdit(context.Background(), "note-uuid-1", "user-42", msg, limiter, nil)

	if capturedRoom != "note-uuid-1" {
		t.Errorf("room = %q, want %q", capturedRoom, "note-uuid-1")
	}
	if capturedMsg.Type != "edit" {
		t.Errorf("msg type = %q, want %q", capturedMsg.Type, "edit")
	}
	if capturedMsg.Sender != "user-42" {
		t.Errorf("msg sender = %q, want %q", capturedMsg.Sender, "user-42")
	}
	if capturedMsg.RoomID != "note-uuid-1" {
		t.Errorf("msg room_id = %q, want %q", capturedMsg.RoomID, "note-uuid-1")
	}
	// Verify payload is relayed as-is (zero-knowledge).
	var payload map[string]interface{}
	if err := json.Unmarshal(capturedMsg.Data, &payload); err != nil {
		t.Fatalf("unmarshal payload: %v", err)
	}
	if payload["version"].(float64) != 1 {
		t.Errorf("payload version = %v, want 1", payload["version"])
	}
}

func TestWSHandler_HandleEdit_RateLimited(t *testing.T) {
	broadcastCalled := false
	presenceSvc := &mockPresenceService{
		broadcastFn: func(ctx context.Context, room string, msg service.WSMessage) error {
			broadcastCalled = true
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}
	// Create a limiter with capacity 1 to trigger rate limiting quickly.
	limiter := newClientRateLimiter(1, rateLimitWindow)

	editData := json.RawMessage(`{"ops":[],"version":1}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	// First call should succeed and broadcast.
	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
	if !broadcastCalled {
		t.Fatal("first edit should have broadcast")
	}

	// Reset flag for second call.
	broadcastCalled = false

	// Second call should be rate limited. conn is nil, so the error message
	// write will fail, but the important thing is broadcast is not called.
	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
	if broadcastCalled {
		t.Fatal("rate-limited edit should not have broadcast")
	}
}

func TestWSHandler_HandleEdit_PreservesPayload(t *testing.T) {
	var capturedData json.RawMessage
	presenceSvc := &mockPresenceService{
		broadcastFn: func(ctx context.Context, room string, msg service.WSMessage) error {
			capturedData = msg.Data
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	// Arbitrary encrypted payload that the server should never modify.
	originalData := json.RawMessage(`{"encrypted":"dGhpcyBpcyBlbmNyeXB0ZWQ=","iv":"abcdef"}`)
	msg := service.WSMessage{Type: "edit", Data: originalData}

	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)

	if string(capturedData) != string(originalData) {
		t.Errorf("payload was modified: got %q, want %q", string(capturedData), string(originalData))
	}
}

func TestWSHandler_HandleEdit_ServiceError(t *testing.T) {
	presenceSvc := &mockPresenceService{
		broadcastFn: func(ctx context.Context, room string, msg service.WSMessage) error {
			return errors.New("redis connection lost")
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	editData := json.RawMessage(`{"ops":[],"version":1}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	// Should not panic when broadcast fails.
	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
}

// ---------------------------------------------------------------------------
// Tests: handleCursor
// ---------------------------------------------------------------------------

func TestWSHandler_HandleCursor_Broadcasts(t *testing.T) {
	var capturedRoom string
	var capturedMsg service.WSMessage

	presenceSvc := &mockPresenceService{
		broadcastFn: func(ctx context.Context, room string, msg service.WSMessage) error {
			capturedRoom = room
			capturedMsg = msg
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}
	limiter := newClientRateLimiter(MaxCursorRate, rateLimitWindow)

	cursorData := json.RawMessage(`{"position":42,"selection_end":50}`)
	msg := service.WSMessage{Type: "cursor", Data: cursorData}

	h.handleCursor(context.Background(), "note-uuid-1", "user-42", msg, limiter, nil)

	if capturedRoom != "note-uuid-1" {
		t.Errorf("room = %q, want %q", capturedRoom, "note-uuid-1")
	}
	if capturedMsg.Type != "cursor" {
		t.Errorf("msg type = %q, want %q", capturedMsg.Type, "cursor")
	}
	if capturedMsg.Sender != "user-42" {
		t.Errorf("msg sender = %q, want %q", capturedMsg.Sender, "user-42")
	}
	if capturedMsg.RoomID != "note-uuid-1" {
		t.Errorf("msg room_id = %q, want %q", capturedMsg.RoomID, "note-uuid-1")
	}
}

func TestWSHandler_HandleCursor_RateLimited(t *testing.T) {
	broadcastCalled := false
	presenceSvc := &mockPresenceService{
		broadcastFn: func(ctx context.Context, room string, msg service.WSMessage) error {
			broadcastCalled = true
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}
	limiter := newClientRateLimiter(1, rateLimitWindow)

	cursorData := json.RawMessage(`{"position":1}`)
	msg := service.WSMessage{Type: "cursor", Data: cursorData}

	// First call should succeed.
	h.handleCursor(context.Background(), "room-1", "user-1", msg, limiter, nil)
	if !broadcastCalled {
		t.Fatal("first cursor should have broadcast")
	}

	broadcastCalled = false

	// Second call should be rate limited.
	h.handleCursor(context.Background(), "room-1", "user-1", msg, limiter, nil)
	if broadcastCalled {
		t.Fatal("rate-limited cursor should not have broadcast")
	}
}

func TestWSHandler_HandleCursor_PreservesPayload(t *testing.T) {
	var capturedData json.RawMessage
	presenceSvc := &mockPresenceService{
		broadcastFn: func(ctx context.Context, room string, msg service.WSMessage) error {
			capturedData = msg.Data
			return nil
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}
	limiter := newClientRateLimiter(MaxCursorRate, rateLimitWindow)

	originalData := json.RawMessage(`{"position":100,"selection_end":150}`)
	msg := service.WSMessage{Type: "cursor", Data: originalData}

	h.handleCursor(context.Background(), "room-1", "user-1", msg, limiter, nil)

	if string(capturedData) != string(originalData) {
		t.Errorf("payload was modified: got %q, want %q", string(capturedData), string(originalData))
	}
}

func TestWSHandler_HandleCursor_ServiceError(t *testing.T) {
	presenceSvc := &mockPresenceService{
		broadcastFn: func(ctx context.Context, room string, msg service.WSMessage) error {
			return errors.New("redis connection lost")
		},
	}

	h := &WSHandler{presenceSvc: presenceSvc, jwtSecret: testJWTSecret}
	limiter := newClientRateLimiter(MaxCursorRate, rateLimitWindow)

	cursorData := json.RawMessage(`{"position":1}`)
	msg := service.WSMessage{Type: "cursor", Data: cursorData}

	// Should not panic when broadcast fails.
	h.handleCursor(context.Background(), "room-1", "user-1", msg, limiter, nil)
}

// ---------------------------------------------------------------------------
// Tests: WSMessage with Sender and RoomID fields
// ---------------------------------------------------------------------------

func TestWSMessage_SenderRoomID(t *testing.T) {
	msg := service.WSMessage{
		Type:   "edit",
		Data:   json.RawMessage(`{"ops":[],"version":1}`),
		Sender: "user-42",
		RoomID: "note-uuid-1",
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal WSMessage: %v", err)
	}

	var decoded service.WSMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal WSMessage: %v", err)
	}
	if decoded.Sender != "user-42" {
		t.Errorf("Sender = %q, want %q", decoded.Sender, "user-42")
	}
	if decoded.RoomID != "note-uuid-1" {
		t.Errorf("RoomID = %q, want %q", decoded.RoomID, "note-uuid-1")
	}
}

func TestWSMessage_SenderRoomID_Omitempty(t *testing.T) {
	msg := service.WSMessage{
		Type: "ping",
		Data: json.RawMessage(`{}`),
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal WSMessage: %v", err)
	}

	// Verify sender and room_id are omitted when empty.
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

func TestWSMessage_AllTypes(t *testing.T) {
	types := []string{"join", "leave", "presence", "typing", "comment", "edit", "cursor", "ping", "pong", "error"}
	for _, typ := range types {
		msg := service.WSMessage{Type: typ, Data: json.RawMessage(`{}`)}
		data, err := json.Marshal(msg)
		if err != nil {
			t.Errorf("Marshal type %q: %v", typ, err)
			continue
		}
		var decoded service.WSMessage
		if err := json.Unmarshal(data, &decoded); err != nil {
			t.Errorf("Unmarshal type %q: %v", typ, err)
			continue
		}
		if decoded.Type != typ {
			t.Errorf("Type = %q, want %q", decoded.Type, typ)
		}
	}
}

// ---------------------------------------------------------------------------
// Mocks for CollabMembershipChecker and CollabOpsStore
// ---------------------------------------------------------------------------

type mockCollabMembershipChecker struct {
	isMemberFn func(ctx context.Context, roomID, userID string) (bool, error)
}

func (m *mockCollabMembershipChecker) IsMember(ctx context.Context, roomID, userID string) (bool, error) {
	if m.isMemberFn != nil {
		return m.isMemberFn(ctx, roomID, userID)
	}
	return false, nil
}

type mockCollabOpsStore struct {
	storeFn          func(ctx context.Context, op *domain.CollabOperation) error
	getSinceFn       func(ctx context.Context, roomID string, sinceClock int) ([]domain.CollabOperation, error)
}

func (m *mockCollabOpsStore) StoreOperation(ctx context.Context, op *domain.CollabOperation) error {
	if m.storeFn != nil {
		return m.storeFn(ctx, op)
	}
	return nil
}

func (m *mockCollabOpsStore) GetOperationsSince(ctx context.Context, roomID string, sinceClock int) ([]domain.CollabOperation, error) {
	if m.getSinceFn != nil {
		return m.getSinceFn(ctx, roomID, sinceClock)
	}
	return nil, nil
}

// ---------------------------------------------------------------------------
// Tests: Room Access Control (pre-WebSocket-upgrade HTTP checks)
// ---------------------------------------------------------------------------

func TestWSHandler_HandleConnection_NonMember(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	collabRepo := &mockCollabMembershipChecker{
		isMemberFn: func(_ context.Context, roomID, userID string) (bool, error) {
			return false, nil
		},
	}

	h := NewWSHandler(presenceSvc, collabRepo, nil, testJWTSecret, nil)

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	req := httptest.NewRequest(http.MethodGet, "/ws?token="+token+"&room=room-1", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusForbidden, rec.Body.String())
	}
}

func TestWSHandler_HandleConnection_Member(t *testing.T) {
	collabRepo := &mockCollabMembershipChecker{
		isMemberFn: func(_ context.Context, roomID, userID string) (bool, error) {
			return true, nil
		},
	}

	h := NewWSHandler(&mockPresenceService{}, collabRepo, nil, testJWTSecret, nil)

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	req := httptest.NewRequest(http.MethodGet, "/ws?token="+token+"&room=room-1", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	// The handler passes the access check and attempts WebSocket upgrade.
	// The upgrade fails in httptest (returns 200 but no body due to WS protocol),
	// so we verify the handler did NOT reject with Forbidden or InternalServerError.
	if rec.Code == http.StatusForbidden {
		t.Fatal("member should not be forbidden")
	}
	if rec.Code == http.StatusInternalServerError {
		t.Fatal("member should not get internal server error")
	}
}

func TestWSHandler_HandleConnection_MembershipCheckError(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	collabRepo := &mockCollabMembershipChecker{
		isMemberFn: func(_ context.Context, _, _ string) (bool, error) {
			return false, errors.New("database unavailable")
		},
	}

	h := NewWSHandler(presenceSvc, collabRepo, nil, testJWTSecret, nil)

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	req := httptest.NewRequest(http.MethodGet, "/ws?token="+token+"&room=room-1", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

func TestWSHandler_HandleConnection_NoCollabRepo_SkipsCheck(t *testing.T) {
	// No collabRepo (nil) -- membership check is skipped entirely.
	h := NewWSHandler(&mockPresenceService{}, nil, nil, testJWTSecret, nil)

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	req := httptest.NewRequest(http.MethodGet, "/ws?token="+token+"&room=room-1", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	// Should not be Forbidden -- membership check was skipped.
	if rec.Code == http.StatusForbidden {
		t.Fatal("should not be forbidden when collabRepo is nil")
	}
	if rec.Code == http.StatusInternalServerError {
		t.Fatal("should not get internal server error when collabRepo is nil")
	}
}

// ---------------------------------------------------------------------------
// Tests: CRDT operation persistence (handleEdit with opsRepo)
// ---------------------------------------------------------------------------

func TestWSHandler_HandleEdit_PersistsOperation(t *testing.T) {
	var storedOp *domain.CollabOperation
	opsStore := &mockCollabOpsStore{
		storeFn: func(_ context.Context, op *domain.CollabOperation) error {
			storedOp = op
			return nil
		},
	}

	presenceSvc := &mockPresenceService{}
	h := &WSHandler{
		presenceSvc: presenceSvc,
		opsRepo:     opsStore,
		jwtSecret:   testJWTSecret,
	}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	editData := json.RawMessage(`{"site_id":"site-1","clock":42,"operation_type":"insert","payload":{"ops":[{"type":"insert"}]}}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)

	if storedOp == nil {
		t.Fatal("operation should have been persisted")
	}
	if storedOp.RoomID != "room-1" {
		t.Errorf("room_id = %q, want %q", storedOp.RoomID, "room-1")
	}
	if storedOp.SiteID != "site-1" {
		t.Errorf("site_id = %q, want %q", storedOp.SiteID, "site-1")
	}
	if storedOp.Clock != 42 {
		t.Errorf("clock = %d, want 42", storedOp.Clock)
	}
	if storedOp.OperationType != "insert" {
		t.Errorf("operation_type = %q, want %q", storedOp.OperationType, "insert")
	}
}

func TestWSHandler_HandleEdit_PersistError(t *testing.T) {
	opsStore := &mockCollabOpsStore{
		storeFn: func(_ context.Context, _ *domain.CollabOperation) error {
			return errors.New("disk full")
		},
	}

	presenceSvc := &mockPresenceService{}
	h := &WSHandler{
		presenceSvc: presenceSvc,
		opsRepo:     opsStore,
		jwtSecret:   testJWTSecret,
	}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	editData := json.RawMessage(`{"site_id":"site-1","clock":1,"operation_type":"insert","payload":{}}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	// Should not panic on persistence error.
	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
}

func TestWSHandler_HandleEdit_SkipsPersistForMissingFields(t *testing.T) {
	storeCalled := false
	opsStore := &mockCollabOpsStore{
		storeFn: func(_ context.Context, _ *domain.CollabOperation) error {
			storeCalled = true
			return nil
		},
	}

	presenceSvc := &mockPresenceService{}
	h := &WSHandler{
		presenceSvc: presenceSvc,
		opsRepo:     opsStore,
		jwtSecret:   testJWTSecret,
	}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	t.Run("missing site_id", func(t *testing.T) {
		storeCalled = false
		editData := json.RawMessage(`{"clock":1,"operation_type":"insert","payload":{}}`)
		msg := service.WSMessage{Type: "edit", Data: editData}
		h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
		if storeCalled {
			t.Error("should not persist when site_id is missing")
		}
	})

	t.Run("missing clock", func(t *testing.T) {
		storeCalled = false
		editData := json.RawMessage(`{"site_id":"site-1","operation_type":"insert","payload":{}}`)
		msg := service.WSMessage{Type: "edit", Data: editData}
		h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
		if storeCalled {
			t.Error("should not persist when clock is zero")
		}
	})

	t.Run("malformed data", func(t *testing.T) {
		storeCalled = false
		editData := json.RawMessage(`not-json`)
		msg := service.WSMessage{Type: "edit", Data: editData}
		h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
		if storeCalled {
			t.Error("should not persist for malformed data")
		}
	})
}

func TestWSHandler_HandleEdit_NoOpsRepo_SkipsPersist(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := &WSHandler{
		presenceSvc: presenceSvc,
		opsRepo:     nil, // No opsRepo configured.
		jwtSecret:   testJWTSecret,
	}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	editData := json.RawMessage(`{"site_id":"site-1","clock":1,"operation_type":"insert","payload":{}}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	// Should not panic when opsRepo is nil.
	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
}

func TestWSHandler_HandleEdit_PersistWithDeleteOp(t *testing.T) {
	var storedOp *domain.CollabOperation
	opsStore := &mockCollabOpsStore{
		storeFn: func(_ context.Context, op *domain.CollabOperation) error {
			storedOp = op
			return nil
		},
	}

	presenceSvc := &mockPresenceService{}
	h := &WSHandler{
		presenceSvc: presenceSvc,
		opsRepo:     opsStore,
		jwtSecret:   testJWTSecret,
	}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	editData := json.RawMessage(`{"site_id":"site-2","clock":10,"operation_type":"delete","payload":{"range":[0,5]}}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)

	if storedOp == nil {
		t.Fatal("delete operation should have been persisted")
	}
	if storedOp.OperationType != "delete" {
		t.Errorf("operation_type = %q, want %q", storedOp.OperationType, "delete")
	}
	if storedOp.Clock != 10 {
		t.Errorf("clock = %d, want 10", storedOp.Clock)
	}
}

func TestWSHandler_HandleEdit_PersistGeneratesUUID(t *testing.T) {
	var storedOp *domain.CollabOperation
	opsStore := &mockCollabOpsStore{
		storeFn: func(_ context.Context, op *domain.CollabOperation) error {
			storedOp = op
			return nil
		},
	}

	presenceSvc := &mockPresenceService{}
	h := &WSHandler{
		presenceSvc: presenceSvc,
		opsRepo:     opsStore,
		jwtSecret:   testJWTSecret,
	}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	editData := json.RawMessage(`{"site_id":"site-1","clock":1,"operation_type":"insert","payload":{}}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)

	if storedOp == nil {
		t.Fatal("operation should have been persisted")
	}
	// Verify the generated ID is a valid UUID.
	_, err := uuid.Parse(storedOp.ID)
	if err != nil {
		t.Errorf("stored op ID = %q is not a valid UUID: %v", storedOp.ID, err)
	}
}

func TestWSHandler_HandleEdit_PersistSetsTimestamp(t *testing.T) {
	var storedOp *domain.CollabOperation
	opsStore := &mockCollabOpsStore{
		storeFn: func(_ context.Context, op *domain.CollabOperation) error {
			storedOp = op
			return nil
		},
	}

	presenceSvc := &mockPresenceService{}
	h := &WSHandler{
		presenceSvc: presenceSvc,
		opsRepo:     opsStore,
		jwtSecret:   testJWTSecret,
	}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	before := time.Now()
	editData := json.RawMessage(`{"site_id":"site-1","clock":1,"operation_type":"insert","payload":{}}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)
	after := time.Now()

	if storedOp == nil {
		t.Fatal("operation should have been persisted")
	}
	if storedOp.CreatedAt.Before(before) || storedOp.CreatedAt.After(after) {
		t.Errorf("created_at = %v, expected between %v and %v", storedOp.CreatedAt, before, after)
	}
}

// ---------------------------------------------------------------------------
// Tests: NewWSHandler with collab repo and ops store
// ---------------------------------------------------------------------------

func TestNewWSHandler_WithCollabRepo(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	collabRepo := &mockCollabMembershipChecker{}
	opsStore := &mockCollabOpsStore{}

	h := NewWSHandler(presenceSvc, collabRepo, opsStore, "jwt-secret", nil)
	if h == nil {
		t.Fatal("NewWSHandler returned nil")
	}
	if h.collabRepo != collabRepo {
		t.Error("collabRepo not set correctly")
	}
	if h.opsRepo != opsStore {
		t.Error("opsRepo not set correctly")
	}
}

func TestNewWSHandler_NilRepos(t *testing.T) {
	presenceSvc := &mockPresenceService{}

	h := NewWSHandler(presenceSvc, nil, nil, "jwt-secret", nil)
	if h == nil {
		t.Fatal("NewWSHandler returned nil")
	}
	if h.collabRepo != nil {
		t.Error("collabRepo should be nil")
	}
	if h.opsRepo != nil {
		t.Error("opsRepo should be nil")
	}
}

// ---------------------------------------------------------------------------
// Tests: CollabOperation domain type
// ---------------------------------------------------------------------------

func TestCollabOperation_JSONRoundTrip(t *testing.T) {
	op := domain.CollabOperation{
		ID:            uuid.New().String(),
		RoomID:        "room-1",
		SiteID:        "site-1",
		Clock:         42,
		OperationType: "insert",
		Payload:       []byte(`{"ops":[{"type":"insert"}]}`),
		CreatedAt:     time.Now().Truncate(time.Millisecond),
	}

	data, err := json.Marshal(op)
	if err != nil {
		t.Fatalf("marshal CollabOperation: %v", err)
	}

	var decoded domain.CollabOperation
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal CollabOperation: %v", err)
	}

	if decoded.ID != op.ID {
		t.Errorf("ID = %q, want %q", decoded.ID, op.ID)
	}
	if decoded.RoomID != op.RoomID {
		t.Errorf("RoomID = %q, want %q", decoded.RoomID, op.RoomID)
	}
	if decoded.SiteID != op.SiteID {
		t.Errorf("SiteID = %q, want %q", decoded.SiteID, op.SiteID)
	}
	if decoded.Clock != op.Clock {
		t.Errorf("Clock = %d, want %d", decoded.Clock, op.Clock)
	}
	if decoded.OperationType != op.OperationType {
		t.Errorf("OperationType = %q, want %q", decoded.OperationType, op.OperationType)
	}
}

func TestCollabOperation_DeleteOp(t *testing.T) {
	op := domain.CollabOperation{
		ID:            uuid.New().String(),
		RoomID:        "room-2",
		SiteID:        "site-2",
		Clock:         10,
		OperationType: "delete",
		Payload:       []byte(`{"range":[0,5]}`),
	}
	if op.OperationType != "delete" {
		t.Errorf("operation_type = %q, want %q", op.OperationType, "delete")
	}
}

func TestCollabOperation_InsertOp(t *testing.T) {
	op := domain.CollabOperation{
		OperationType: "insert",
	}
	if op.OperationType != "insert" {
		t.Errorf("operation_type = %q, want %q", op.OperationType, "insert")
	}
}

func TestCollabOperation_EmptyPayload(t *testing.T) {
	op := domain.CollabOperation{
		ID:            uuid.New().String(),
		RoomID:        "room-1",
		SiteID:        "site-1",
		Clock:         1,
		OperationType: "insert",
		Payload:       nil,
	}
	data, err := json.Marshal(op)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var decoded domain.CollabOperation
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
}

func TestCollabOperation_MultipleOps(t *testing.T) {
	ops := make([]domain.CollabOperation, 5)
	for i := range ops {
		ops[i] = domain.CollabOperation{
			ID:            uuid.New().String(),
			RoomID:        "room-1",
			SiteID:        "site-1",
			Clock:         i + 1,
			OperationType: "insert",
			Payload:       []byte(`{}`),
		}
	}
	if len(ops) != 5 {
		t.Errorf("len = %d, want 5", len(ops))
	}
	for i, op := range ops {
		if op.Clock != i+1 {
			t.Errorf("ops[%d].Clock = %d, want %d", i, op.Clock, i+1)
		}
	}
}

func TestCollabOperation_LargeClock(t *testing.T) {
	op := domain.CollabOperation{
		Clock: 999999999,
	}
	if op.Clock != 999999999 {
		t.Errorf("Clock = %d, want 999999999", op.Clock)
	}
}

func TestCollabOperation_DifferentSites(t *testing.T) {
	sites := []string{"site-a", "site-b", "site-c"}
	ops := make([]domain.CollabOperation, len(sites))
	for i, site := range sites {
		ops[i] = domain.CollabOperation{
			SiteID:        site,
			Clock:         i + 1,
			OperationType: "insert",
		}
	}
	for i, op := range ops {
		if op.SiteID != sites[i] {
			t.Errorf("ops[%d].SiteID = %q, want %q", i, op.SiteID, sites[i])
		}
	}
}

// ---------------------------------------------------------------------------
// Tests: Room access control with collabRepo -- additional edge cases
// ---------------------------------------------------------------------------

func TestWSHandler_HandleConnection_MemberOfDifferentRoom(t *testing.T) {
	// User is a member of room-2 but not room-1.
	collabRepo := &mockCollabMembershipChecker{
		isMemberFn: func(_ context.Context, roomID, _ string) (bool, error) {
			return roomID == "room-2", nil
		},
	}

	h := NewWSHandler(&mockPresenceService{}, collabRepo, nil, testJWTSecret, nil)

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	req := httptest.NewRequest(http.MethodGet, "/ws?token="+token+"&room=room-1", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d for non-member of room-1", rec.Code, http.StatusForbidden)
	}
}

func TestWSHandler_HandleConnection_CorrectRoomMember(t *testing.T) {
	// User is a member of room-1 specifically.
	collabRepo := &mockCollabMembershipChecker{
		isMemberFn: func(_ context.Context, roomID, _ string) (bool, error) {
			return roomID == "room-1", nil
		},
	}

	h := NewWSHandler(&mockPresenceService{}, collabRepo, nil, testJWTSecret, nil)

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	req := httptest.NewRequest(http.MethodGet, "/ws?token="+token+"&room=room-1", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	// Should not be forbidden since the user is a member of room-1.
	if rec.Code == http.StatusForbidden {
		t.Fatal("user is member of room-1, should not be forbidden")
	}
}

func TestWSHandler_HandleConnection_AccessControlBeforeUpgrade(t *testing.T) {
	// Verify that the Forbidden response is sent before the WebSocket upgrade
	// (i.e. the response is a plain HTTP response, not a WebSocket close frame).
	collabRepo := &mockCollabMembershipChecker{
		isMemberFn: func(_ context.Context, _, _ string) (bool, error) {
			return false, nil
		},
	}

	h := NewWSHandler(&mockPresenceService{}, collabRepo, nil, testJWTSecret, nil)

	userID := uuid.New().String()
	token := generateTestWSToken(userID)

	req := httptest.NewRequest(http.MethodGet, "/ws?token="+token+"&room=room-1", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusForbidden)
	}
	// The response should be plain text (set by http.Error), not a WebSocket frame.
	contentType := rec.Header().Get("Content-Type")
	if contentType == "application/json" {
		t.Error("expected plain text error, got JSON content type")
	}
}

// ---------------------------------------------------------------------------
// Tests: CRDT persistence -- payload integrity
// ---------------------------------------------------------------------------

func TestWSHandler_HandleEdit_PersistPreservesPayload(t *testing.T) {
	var storedPayload []byte
	opsStore := &mockCollabOpsStore{
		storeFn: func(_ context.Context, op *domain.CollabOperation) error {
			storedPayload = op.Payload
			return nil
		},
	}

	presenceSvc := &mockPresenceService{}
	h := &WSHandler{
		presenceSvc: presenceSvc,
		opsRepo:     opsStore,
		jwtSecret:   testJWTSecret,
	}
	limiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)

	originalPayload := json.RawMessage(`{"encrypted":"dGhpcyBpcyBlbmNyeXB0ZWQ=","iv":"abcdef12"}`)
	editData := json.RawMessage(`{"site_id":"site-1","clock":5,"operation_type":"insert","payload":` + string(originalPayload) + `}`)
	msg := service.WSMessage{Type: "edit", Data: editData}

	h.handleEdit(context.Background(), "room-1", "user-1", msg, limiter, nil)

	if string(storedPayload) != string(originalPayload) {
		t.Errorf("payload was modified: got %q, want %q", string(storedPayload), string(originalPayload))
	}
}
