package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// CollabHandler handles HTTP requests for collaboration room management.
type CollabHandler struct {
	collabSvc service.CollabService
}

// NewCollabHandler creates a new CollabHandler.
func NewCollabHandler(svc service.CollabService) *CollabHandler {
	return &CollabHandler{collabSvc: svc}
}

// CreateRoom handles POST /api/v1/collab/rooms.
// Creates a new collab room and returns the room with its invite code.
func (h *CollabHandler) CreateRoom(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.CreateRoomRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	// Apply defaults for zero values.
	if req.MaxMembers == 0 {
		req.MaxMembers = 10
	}

	room, err := h.collabSvc.CreateRoom(r.Context(), userID.String(), req)
	if err != nil {
		switch err {
		case service.ErrRoomNameTooLong:
			writeError(w, r, http.StatusBadRequest, "validation_error", "room_name must be at most 255 characters")
		case service.ErrMaxMembersRange:
			writeError(w, r, http.StatusBadRequest, "validation_error", "max_members must be between 1 and 100")
		default:
			writeError(w, r, http.StatusInternalServerError, "create_room_error", "Failed to create room")
		}
		return
	}

	writeJSON(w, http.StatusCreated, room)
}

// JoinRoom handles POST /api/v1/collab/rooms/join.
// Joins a room using an invite code.
func (h *CollabHandler) JoinRoom(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.JoinRoomRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.InviteCode == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "invite_code is required")
		return
	}

	room, err := h.collabSvc.JoinRoom(r.Context(), userID.String(), req)
	if err != nil {
		switch err {
		case service.ErrRoomNotFound, service.ErrInvalidInvite:
			writeError(w, r, http.StatusNotFound, "not_found", "Room not found")
		case service.ErrRoomInactive:
			writeError(w, r, http.StatusGone, "room_inactive", "Room is no longer active")
		case service.ErrRoomExpired:
			writeError(w, r, http.StatusGone, "room_expired", "Room has expired")
		case service.ErrRoomFull:
			writeError(w, r, http.StatusForbidden, "room_full", "Room has reached maximum members")
		case service.ErrAlreadyMember:
			writeError(w, r, http.StatusConflict, "already_member", "You are already a member of this room")
		default:
			writeError(w, r, http.StatusInternalServerError, "join_room_error", "Failed to join room")
		}
		return
	}

	writeJSON(w, http.StatusOK, room)
}

// LeaveRoom handles POST /api/v1/collab/rooms/{roomId}/leave.
// Removes the authenticated user from the room. If the user is the owner, the
// room is deactivated.
func (h *CollabHandler) LeaveRoom(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	roomID := chi.URLParam(r, "roomId")
	if roomID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_room_id", "Room ID is required")
		return
	}

	if err := h.collabSvc.LeaveRoom(r.Context(), userID.String(), roomID); err != nil {
		switch err {
		case service.ErrNotMember:
			writeError(w, r, http.StatusForbidden, "not_member", "You are not a member of this room")
		case service.ErrRoomNotFound:
			writeError(w, r, http.StatusNotFound, "not_found", "Room not found")
		default:
			writeError(w, r, http.StatusInternalServerError, "leave_room_error", "Failed to leave room")
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "left"})
}

// GetRoomMembers handles GET /api/v1/collab/rooms/{roomId}/members.
// Returns all members of a room (requires membership).
func (h *CollabHandler) GetRoomMembers(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	roomID := chi.URLParam(r, "roomId")
	if roomID == "" {
		writeError(w, r, http.StatusBadRequest, "missing_room_id", "Room ID is required")
		return
	}

	members, err := h.collabSvc.GetRoomMembers(r.Context(), userID.String(), roomID)
	if err != nil {
		switch err {
		case service.ErrNotMember:
			writeError(w, r, http.StatusForbidden, "not_member", "You are not a member of this room")
		default:
			writeError(w, r, http.StatusInternalServerError, "members_error", "Failed to get room members")
		}
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"members": members,
	})
}

// GetUserRooms handles GET /api/v1/collab/rooms.
// Returns all rooms the authenticated user is a member of.
func (h *CollabHandler) GetUserRooms(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	rooms, err := h.collabSvc.GetUserRooms(r.Context(), userID.String())
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "rooms_error", "Failed to get rooms")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"rooms": rooms,
	})
}
