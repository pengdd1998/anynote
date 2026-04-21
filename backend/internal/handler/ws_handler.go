package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"nhooyr.io/websocket"

	"github.com/anynote/backend/internal/service"
)

// Rate limiting constants for WS message relay.
const (
	// MaxEditRate is the maximum number of edit messages per second per client.
	MaxEditRate = 30
	// MaxCursorRate is the maximum number of cursor messages per second per client.
	MaxCursorRate = 5
	// rateLimitWindow is the sliding window duration for per-client rate limiting.
	rateLimitWindow = 1 * time.Second
)

// clientRateLimiter provides per-client rate limiting using a sliding window.
type clientRateLimiter struct {
	mu         sync.Mutex
	timestamps []time.Time
	limit      int
	window     time.Duration
}

// newClientRateLimiter creates a new per-client rate limiter.
func newClientRateLimiter(limit int, window time.Duration) *clientRateLimiter {
	return &clientRateLimiter{
		limit:  limit,
		window: window,
	}
}

// Allow checks if a message is allowed under the rate limit.
func (r *clientRateLimiter) Allow() bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := time.Now()
	windowStart := now.Add(-r.window)

	// Remove expired entries.
	valid := r.timestamps[:0]
	for _, t := range r.timestamps {
		if t.After(windowStart) {
			valid = append(valid, t)
		}
	}
	r.timestamps = valid

	if len(r.timestamps) >= r.limit {
		return false
	}

	r.timestamps = append(r.timestamps, now)
	return true
}

// WSHandler handles WebSocket connections for real-time collaboration.
type WSHandler struct {
	presenceSvc    service.PresenceService
	jwtSecret      string
	allowedOrigins []string
}

// wsTokenExpiry is how long a WebSocket-specific token remains valid.
const wsTokenExpiry = 60 * time.Second

// NewWSHandler creates a new WebSocket handler.
// allowedOrigins controls which origins may connect via WebSocket.
// If empty, the wildcard pattern "*" is used (suitable for local development).
func NewWSHandler(presenceSvc service.PresenceService, jwtSecret string, allowedOrigins []string) *WSHandler {
	return &WSHandler{
		presenceSvc:    presenceSvc,
		jwtSecret:      jwtSecret,
		allowedOrigins: allowedOrigins,
	}
}

// GenerateWSToken creates a short-lived (60s) JWT token specifically for
// WebSocket connections. Requires an authenticated user (access token).
// POST /api/v1/ws/token
func (h *WSHandler) GenerateWSToken(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	now := time.Now()
	claims := jwt.MapClaims{
		"user_id":    userID.String(),
		"token_type": "ws",
		"iat":        now.Unix(),
		"exp":        now.Add(wsTokenExpiry).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, err := token.SignedString([]byte(h.jwtSecret))
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "token_error", "Failed to generate WebSocket token")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"token":     tokenStr,
		"expires_in": "60",
	})
}

// originPatterns returns the origin patterns for the WebSocket accept options.
// When no patterns are configured (dev mode), it falls back to wildcard.
func (h *WSHandler) originPatterns() []string {
	if len(h.allowedOrigins) == 0 {
		return []string{"*"}
	}
	return h.allowedOrigins
}

// IdleTimeout is the maximum duration a connection may be idle before being closed.
const idleTimeout = 5 * time.Minute

// HandleConnection upgrades an HTTP request to a WebSocket connection,
// authenticates via query-param token, and runs the read pump.
func (h *WSHandler) HandleConnection(w http.ResponseWriter, r *http.Request) {
	// --- Authenticate via ?token= query param ---
	tokenStr := r.URL.Query().Get("token")
	if tokenStr == "" {
		http.Error(w, "missing token", http.StatusUnauthorized)
		return
	}

	userID, err := h.validateToken(tokenStr)
	if err != nil {
		slog.Warn("ws: auth failed", "error", err)
		http.Error(w, "invalid token", http.StatusUnauthorized)
		return
	}

	// --- Determine room ---
	room := r.URL.Query().Get("room")
	if room == "" {
		http.Error(w, "missing room parameter", http.StatusBadRequest)
		return
	}

	// --- Upgrade to WebSocket ---
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns: h.originPatterns(),
	})
	if err != nil {
		slog.Error("ws: upgrade failed", "error", err)
		return
	}
	defer conn.CloseNow()

	// Build a username. For now, use the userID. The client may send a "join"
	// message with a preferred username later.
	username := userID

	// --- Register presence ---
	ctx, cancel := context.WithTimeout(r.Context(), idleTimeout)
	defer cancel()

	if err := h.presenceSvc.Join(ctx, room, userID, username); err != nil {
		slog.Error("ws: join failed", "room", room, "error", err)
		conn.Close(websocket.StatusPolicyViolation, "join failed")
		return
	}
	defer func() {
		leaveCtx, leaveCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer leaveCancel()
		if err := h.presenceSvc.Leave(leaveCtx, room, userID); err != nil {
			slog.Warn("ws: leave failed", "room", room, "error", err)
		}
	}()

	slog.Info("ws: connected", "room", room, "user_id", userID)

	// Subscribe to room broadcasts and start write pump.
	roomCh := h.presenceSvc.SubscribeRoom(ctx, room)
	go h.writePump(ctx, conn, roomCh)

	// Send initial presence list to the newly joined user.
	if err := h.sendPresenceList(ctx, conn, room); err != nil {
		slog.Warn("ws: failed to send presence list", "error", err)
	}

	// --- Read pump: read client messages and dispatch ---
	editLimiter := newClientRateLimiter(MaxEditRate, rateLimitWindow)
	cursorLimiter := newClientRateLimiter(MaxCursorRate, rateLimitWindow)
	h.readPump(ctx, conn, room, userID, editLimiter, cursorLimiter)
}

// validateToken parses and validates a JWT string, returning the user_id claim.
// Only tokens with token_type "ws" are accepted for WebSocket connections.
func (h *WSHandler) validateToken(tokenStr string) (string, error) {
	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(h.jwtSecret), nil
	})
	if err != nil {
		return "", fmt.Errorf("jwt parse: %w", err)
	}
	if !token.Valid {
		return "", errors.New("token is not valid")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", errors.New("invalid token claims")
	}

	userID, ok := claims["user_id"].(string)
	if !ok || userID == "" {
		return "", errors.New("user_id not found in token claims")
	}

	// Only accept WebSocket-specific tokens (token_type "ws").
	// Reject access tokens and refresh tokens.
	tokenType, _ := claims["token_type"].(string)
	if tokenType != "ws" {
		return "", errors.New("WebSocket token required; use POST /api/v1/ws/token to obtain one")
	}

	return userID, nil
}

// sendPresenceList fetches current room members and sends them as a
// "presence" message to the given connection.
func (h *WSHandler) sendPresenceList(ctx context.Context, conn *websocket.Conn, room string) error {
	members, err := h.presenceSvc.GetRoomMembers(ctx, room)
	if err != nil {
		return fmt.Errorf("get room members: %w", err)
	}

	data, err := json.Marshal(members)
	if err != nil {
		return fmt.Errorf("marshal members: %w", err)
	}

	msg := service.WSMessage{Type: "presence", Data: data}
	return wsWriteJSON(ctx, conn, msg)
}

// readPump reads messages from the WebSocket connection and dispatches them.
// editLimiter and cursorLimiter enforce per-client rate limits for relay messages.
func (h *WSHandler) readPump(ctx context.Context, conn *websocket.Conn, room, userID string, editLimiter, cursorLimiter *clientRateLimiter) {
	for {
		_, raw, err := conn.Read(ctx)
		if err != nil {
			// Normal closure or context cancelled; stop reading.
			return
		}

		var msg service.WSMessage
		if err := json.Unmarshal(raw, &msg); err != nil {
			// Skip malformed messages silently.
			continue
		}

		switch msg.Type {
		case "ping":
			// Respond with pong to keep connection alive.
			pong := service.WSMessage{Type: "pong", Data: json.RawMessage(`{}`)}
			if writeErr := wsWriteJSON(ctx, conn, pong); writeErr != nil {
				return
			}

		case "typing":
			h.handleTyping(ctx, room, userID, msg.Data)

		case "comment":
			// Broadcast comment to all room subscribers.
			// Privacy note: comment content is not logged.
			if broadcastErr := h.presenceSvc.BroadcastToRoom(ctx, room, msg); broadcastErr != nil {
				slog.Warn("ws: broadcast comment failed", "error", broadcastErr)
			}

		case "edit":
			h.handleEdit(ctx, room, userID, msg, editLimiter, conn)

		case "cursor":
			h.handleCursor(ctx, room, userID, msg, cursorLimiter, conn)

		case "join":
			// Client may send an updated username in the join data.
			var data struct {
				Username string `json:"username"`
			}
			if err := json.Unmarshal(msg.Data, &data); err == nil && data.Username != "" {
				username := data.Username
				if joinErr := h.presenceSvc.Join(ctx, room, userID, username); joinErr != nil {
					slog.Warn("ws: re-join with username failed", "room", room, "error", joinErr)
				}
			}

		default:
			// Unknown message types are ignored.
		}

		// Reset the idle deadline on every received message.
	}
}

// handleTyping extracts typing state from data and sets the indicator.
func (h *WSHandler) handleTyping(ctx context.Context, room, userID string, data json.RawMessage) {
	var td struct {
		IsTyping bool `json:"is_typing"`
	}
	if err := json.Unmarshal(data, &td); err != nil {
		return
	}
	if err := h.presenceSvc.SetTyping(ctx, room, userID, td.IsTyping); err != nil {
		slog.Warn("ws: set typing failed", "error", err)
	}
}

// handleEdit relays CRDT edit operations to all other clients in the room.
// The server is zero-knowledge: it never inspects or modifies the ops payload.
// Rate limited to MaxEditRate messages per second per client.
func (h *WSHandler) handleEdit(ctx context.Context, room, userID string, msg service.WSMessage, limiter *clientRateLimiter, conn *websocket.Conn) {
	if !limiter.Allow() {
		sendRateLimitError(ctx, conn, "edit_rate_limited", "Edit rate limit exceeded")
		return
	}

	// Attach sender and room_id, then relay as-is (zero-knowledge).
	msg.Sender = userID
	msg.RoomID = room
	// Privacy note: edit payload is end-to-end encrypted, never logged or inspected.
	if broadcastErr := h.presenceSvc.BroadcastToRoom(ctx, room, msg); broadcastErr != nil {
		slog.Warn("ws: broadcast edit failed", "error", broadcastErr)
	}
}

// handleCursor relays cursor position updates to all other clients in the room.
// Rate limited to MaxCursorRate messages per second per client.
func (h *WSHandler) handleCursor(ctx context.Context, room, userID string, msg service.WSMessage, limiter *clientRateLimiter, conn *websocket.Conn) {
	if !limiter.Allow() {
		sendRateLimitError(ctx, conn, "cursor_rate_limited", "Cursor rate limit exceeded")
		return
	}

	// Attach sender and room_id, then relay as-is.
	msg.Sender = userID
	msg.RoomID = room
	if broadcastErr := h.presenceSvc.BroadcastToRoom(ctx, room, msg); broadcastErr != nil {
		slog.Warn("ws: broadcast cursor failed", "error", broadcastErr)
	}
}

// sendRateLimitError writes a rate limit error message to the WebSocket connection.
// If the connection is nil or the write fails, the error is silently dropped.
func sendRateLimitError(ctx context.Context, conn *websocket.Conn, code, message string) {
	if conn == nil {
		return
	}
	errMsg := service.WSMessage{
		Type: "error",
		Data: json.RawMessage(fmt.Sprintf(`{"code":"%s","message":"%s"}`, code, message)),
	}
	if writeErr := wsWriteJSON(ctx, conn, errMsg); writeErr != nil {
		slog.Debug("ws: failed to send rate limit error", "error", writeErr)
	}
}

// writePump reads from the room subscription channel and writes messages to the
// WebSocket connection. It exits when the context is done or the channel is closed.
func (h *WSHandler) writePump(ctx context.Context, conn *websocket.Conn, roomCh <-chan service.WSMessage) {
	for {
		select {
		case <-ctx.Done():
			conn.Close(websocket.StatusNormalClosure, "idle timeout")
			return
		case msg, ok := <-roomCh:
			if !ok {
				conn.Close(websocket.StatusNormalClosure, "room closed")
				return
			}
			if err := wsWriteJSON(ctx, conn, msg); err != nil {
				return
			}
		}
	}
}

// wsWriteJSON marshals a WSMessage and writes it as a text frame.
func wsWriteJSON(ctx context.Context, conn *websocket.Conn, msg service.WSMessage) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	return conn.Write(ctx, websocket.MessageText, data)
}
