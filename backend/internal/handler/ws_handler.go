package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"nhooyr.io/websocket"

	"github.com/anynote/backend/internal/service"
)

// WSHandler handles WebSocket connections for real-time collaboration.
type WSHandler struct {
	presenceSvc service.PresenceService
	jwtSecret   string
}

// NewWSHandler creates a new WebSocket handler.
func NewWSHandler(presenceSvc service.PresenceService, jwtSecret string) *WSHandler {
	return &WSHandler{
		presenceSvc: presenceSvc,
		jwtSecret:   jwtSecret,
	}
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
		OriginPatterns: []string{"*"},
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
	h.readPump(ctx, conn, room, userID)
}

// validateToken parses and validates a JWT string, returning the user_id claim.
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
func (h *WSHandler) readPump(ctx context.Context, conn *websocket.Conn, room, userID string) {
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

		case "join":
			// Client may send an updated username in the join data.
			var data struct {
				Username string `json:"username"`
			}
			if err := json.Unmarshal(msg.Data, &data); err == nil && data.Username != "" {
				username := data.Username
				_ = h.presenceSvc.Join(ctx, room, userID, username)
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
