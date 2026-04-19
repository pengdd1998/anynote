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

// ---------------------------------------------------------------------------
// Tests: NewWSHandler
// ---------------------------------------------------------------------------

func TestNewWSHandler(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := NewWSHandler(presenceSvc, "jwt-secret")
	if h == nil {
		t.Fatal("NewWSHandler returned nil")
	}
	if h.jwtSecret != "jwt-secret" {
		t.Errorf("jwtSecret = %q, want %q", h.jwtSecret, "jwt-secret")
	}
}

// ---------------------------------------------------------------------------
// Tests: validateToken (tested via HandleConnection HTTP responses)
// ---------------------------------------------------------------------------

func TestWSHandler_HandleConnection_MissingToken(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := NewWSHandler(presenceSvc, testJWTSecret)

	req := httptest.NewRequest(http.MethodGet, "/ws?room=test-room", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnauthorized, rec.Body.String())
	}
}

func TestWSHandler_HandleConnection_InvalidToken(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := NewWSHandler(presenceSvc, testJWTSecret)

	req := httptest.NewRequest(http.MethodGet, "/ws?token=invalid-token&room=test-room", nil)
	rec := httptest.NewRecorder()

	h.HandleConnection(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusUnauthorized, rec.Body.String())
	}
}

func TestWSHandler_HandleConnection_MissingRoom(t *testing.T) {
	presenceSvc := &mockPresenceService{}
	h := NewWSHandler(presenceSvc, testJWTSecret)

	userID := uuid.New().String()
	token := generateTestToken(userID)

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
	token := generateTestToken(userID)

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
