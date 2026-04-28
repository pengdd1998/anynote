package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock CollabService
// ---------------------------------------------------------------------------

type mockCollabService struct {
	createRoomFn    func(ctx context.Context, userID string, req domain.CreateRoomRequest) (*domain.CollabRoom, error)
	joinRoomFn      func(ctx context.Context, userID string, req domain.JoinRoomRequest) (*domain.CollabRoom, error)
	leaveRoomFn     func(ctx context.Context, userID, roomID string) error
	getMembersFn    func(ctx context.Context, userID, roomID string) ([]domain.CollabRoomMember, error)
	getUserRoomsFn  func(ctx context.Context, userID string) ([]domain.CollabRoom, error)
}

func (m *mockCollabService) CreateRoom(ctx context.Context, userID string, req domain.CreateRoomRequest) (*domain.CollabRoom, error) {
	if m.createRoomFn != nil {
		return m.createRoomFn(ctx, userID, req)
	}
	return nil, nil
}

func (m *mockCollabService) JoinRoom(ctx context.Context, userID string, req domain.JoinRoomRequest) (*domain.CollabRoom, error) {
	if m.joinRoomFn != nil {
		return m.joinRoomFn(ctx, userID, req)
	}
	return nil, nil
}

func (m *mockCollabService) LeaveRoom(ctx context.Context, userID, roomID string) error {
	if m.leaveRoomFn != nil {
		return m.leaveRoomFn(ctx, userID, roomID)
	}
	return nil
}

func (m *mockCollabService) GetRoomMembers(ctx context.Context, userID, roomID string) ([]domain.CollabRoomMember, error) {
	if m.getMembersFn != nil {
		return m.getMembersFn(ctx, userID, roomID)
	}
	return nil, nil
}

func (m *mockCollabService) GetUserRooms(ctx context.Context, userID string) ([]domain.CollabRoom, error) {
	if m.getUserRoomsFn != nil {
		return m.getUserRoomsFn(ctx, userID)
	}
	return nil, nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// testUserID is a valid UUID used as the authenticated user across tests.
const testUserID = "00000000-0000-0000-0000-000000000001"

// setupCollabRouter creates a chi.Router with auth middleware that injects
// testUserID into the context, plus the collab routes.
func setupCollabRouter(svc service.CollabService) *chi.Mux {
	h := NewCollabHandler(svc)
	r := chi.NewRouter()

	// Middleware that injects a known user ID.
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := context.WithValue(r.Context(), contextKey("user_id"), testUserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	})

	r.Route("/collab/rooms", func(r chi.Router) {
		r.Post("/", h.CreateRoom)
		r.Post("/join", h.JoinRoom)
		r.Get("/", h.GetUserRooms)
		r.Route("/{roomId}", func(r chi.Router) {
			r.Post("/leave", h.LeaveRoom)
			r.Get("/members", h.GetRoomMembers)
		})
	})

	return r
}

// decodeErrorResponse extracts the error code and message from a JSON error response.
func decodeErrorResponse(t *testing.T, body []byte) (code string, message string) {
	t.Helper()
	var errResp domain.ErrorResponse
	if jsonErr := json.Unmarshal(body, &errResp); jsonErr != nil {
		t.Fatalf("failed to decode error response: %v", jsonErr)
	}
	return errResp.Error.Code, errResp.Error.Message
}

// ---------------------------------------------------------------------------
// Tests: CreateRoom handler
// ---------------------------------------------------------------------------

func TestCollabHandler_CreateRoom_Success(t *testing.T) {
	mock := &mockCollabService{
		createRoomFn: func(_ context.Context, uid string, req domain.CreateRoomRequest) (*domain.CollabRoom, error) {
			if uid != testUserID {
				t.Errorf("userID = %q, want %q", uid, testUserID)
			}
			return &domain.CollabRoom{
				ID:          "room-1",
				CreatorID:   uid,
				InviteCode:  "ABC12345",
				RoomName:    req.RoomName,
				MaxMembers:  req.MaxMembers,
				CreatedAt:   time.Now(),
				IsActive:    true,
				MemberCount: 1,
			}, nil
		},
	}

	router := setupCollabRouter(mock)
	body := `{"room_name":"Test Room","max_members":5}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("status = %d, want %d", w.Code, http.StatusCreated)
	}

	var room domain.CollabRoom
	if err := json.NewDecoder(w.Body).Decode(&room); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if room.InviteCode != "ABC12345" {
		t.Errorf("invite_code = %q, want %q", room.InviteCode, "ABC12345")
	}
}

func TestCollabHandler_CreateRoom_DefaultMaxMembers(t *testing.T) {
	mock := &mockCollabService{
		createRoomFn: func(_ context.Context, _ string, req domain.CreateRoomRequest) (*domain.CollabRoom, error) {
			if req.MaxMembers != 10 {
				t.Errorf("max_members = %d, want 10 (default)", req.MaxMembers)
			}
			return &domain.CollabRoom{ID: "r1", MaxMembers: req.MaxMembers}, nil
		},
	}

	router := setupCollabRouter(mock)
	body := `{"room_name":"Test"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("status = %d, want %d", w.Code, http.StatusCreated)
	}
}

func TestCollabHandler_CreateRoom_InvalidJSON(t *testing.T) {
	mock := &mockCollabService{}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader("{invalid"))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
	code, _ := decodeErrorResponse(t, w.Body.Bytes())
	if code != "invalid_request" {
		t.Errorf("error code = %q, want %q", code, "invalid_request")
	}
}

func TestCollabHandler_CreateRoom_NameTooLong(t *testing.T) {
	mock := &mockCollabService{
		createRoomFn: func(_ context.Context, _ string, _ domain.CreateRoomRequest) (*domain.CollabRoom, error) {
			return nil, service.ErrRoomNameTooLong
		},
	}
	router := setupCollabRouter(mock)

	body := `{"room_name":"` + strings.Repeat("x", 256) + `","max_members":5}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
	code, _ := decodeErrorResponse(t, w.Body.Bytes())
	if code != "validation_error" {
		t.Errorf("error code = %q, want %q", code, "validation_error")
	}
}

func TestCollabHandler_CreateRoom_MaxMembersOutOfRange(t *testing.T) {
	mock := &mockCollabService{
		createRoomFn: func(_ context.Context, _ string, _ domain.CreateRoomRequest) (*domain.CollabRoom, error) {
			return nil, service.ErrMaxMembersRange
		},
	}
	router := setupCollabRouter(mock)

	body := `{"room_name":"Test","max_members":200}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestCollabHandler_CreateRoom_InternalError(t *testing.T) {
	mock := &mockCollabService{
		createRoomFn: func(_ context.Context, _ string, _ domain.CreateRoomRequest) (*domain.CollabRoom, error) {
			return nil, errors.New("database error")
		},
	}
	router := setupCollabRouter(mock)

	body := `{"room_name":"Test","max_members":5}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status = %d, want %d", w.Code, http.StatusInternalServerError)
	}
}

// ---------------------------------------------------------------------------
// Tests: JoinRoom handler
// ---------------------------------------------------------------------------

func TestCollabHandler_JoinRoom_Success(t *testing.T) {
	mock := &mockCollabService{
		joinRoomFn: func(_ context.Context, uid string, req domain.JoinRoomRequest) (*domain.CollabRoom, error) {
			if req.InviteCode != "VALID01" {
				t.Errorf("invite_code = %q, want %q", req.InviteCode, "VALID01")
			}
			return &domain.CollabRoom{ID: "room-1", InviteCode: "VALID01", MemberCount: 2}, nil
		},
	}
	router := setupCollabRouter(mock)

	body := `{"invite_code":"VALID01"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
	}
}

func TestCollabHandler_JoinRoom_MissingInviteCode(t *testing.T) {
	mock := &mockCollabService{}
	router := setupCollabRouter(mock)

	body := `{"invite_code":""}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
	code, _ := decodeErrorResponse(t, w.Body.Bytes())
	if code != "validation_error" {
		t.Errorf("error code = %q, want %q", code, "validation_error")
	}
}

func TestCollabHandler_JoinRoom_InvalidJSON(t *testing.T) {
	mock := &mockCollabService{}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader("not json"))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestCollabHandler_JoinRoom_NotFound(t *testing.T) {
	mock := &mockCollabService{
		joinRoomFn: func(_ context.Context, _ string, _ domain.JoinRoomRequest) (*domain.CollabRoom, error) {
			return nil, service.ErrRoomNotFound
		},
	}
	router := setupCollabRouter(mock)

	body := `{"invite_code":"INVALID"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want %d", w.Code, http.StatusNotFound)
	}
}

func TestCollabHandler_JoinRoom_RoomInactive(t *testing.T) {
	mock := &mockCollabService{
		joinRoomFn: func(_ context.Context, _ string, _ domain.JoinRoomRequest) (*domain.CollabRoom, error) {
			return nil, service.ErrRoomInactive
		},
	}
	router := setupCollabRouter(mock)

	body := `{"invite_code":"INACTIV"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusGone {
		t.Errorf("status = %d, want %d", w.Code, http.StatusGone)
	}
}

func TestCollabHandler_JoinRoom_RoomExpired(t *testing.T) {
	mock := &mockCollabService{
		joinRoomFn: func(_ context.Context, _ string, _ domain.JoinRoomRequest) (*domain.CollabRoom, error) {
			return nil, service.ErrRoomExpired
		},
	}
	router := setupCollabRouter(mock)

	body := `{"invite_code":"EXPIRED"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusGone {
		t.Errorf("status = %d, want %d", w.Code, http.StatusGone)
	}
}

func TestCollabHandler_JoinRoom_RoomFull(t *testing.T) {
	mock := &mockCollabService{
		joinRoomFn: func(_ context.Context, _ string, _ domain.JoinRoomRequest) (*domain.CollabRoom, error) {
			return nil, service.ErrRoomFull
		},
	}
	router := setupCollabRouter(mock)

	body := `{"invite_code":"FULLROOM"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("status = %d, want %d", w.Code, http.StatusForbidden)
	}
	code, _ := decodeErrorResponse(t, w.Body.Bytes())
	if code != "room_full" {
		t.Errorf("error code = %q, want %q", code, "room_full")
	}
}

func TestCollabHandler_JoinRoom_AlreadyMember(t *testing.T) {
	mock := &mockCollabService{
		joinRoomFn: func(_ context.Context, _ string, _ domain.JoinRoomRequest) (*domain.CollabRoom, error) {
			return nil, service.ErrAlreadyMember
		},
	}
	router := setupCollabRouter(mock)

	body := `{"invite_code":"ALREADY"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Errorf("status = %d, want %d", w.Code, http.StatusConflict)
	}
}

func TestCollabHandler_JoinRoom_InternalError(t *testing.T) {
	mock := &mockCollabService{
		joinRoomFn: func(_ context.Context, _ string, _ domain.JoinRoomRequest) (*domain.CollabRoom, error) {
			return nil, errors.New("unexpected error")
		},
	}
	router := setupCollabRouter(mock)

	body := `{"invite_code":"ERROR01"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status = %d, want %d", w.Code, http.StatusInternalServerError)
	}
}

// ---------------------------------------------------------------------------
// Tests: LeaveRoom handler
// ---------------------------------------------------------------------------

func TestCollabHandler_LeaveRoom_Success(t *testing.T) {
	mock := &mockCollabService{
		leaveRoomFn: func(_ context.Context, uid, roomID string) error {
			if uid != testUserID {
				t.Errorf("userID = %q, want %q", uid, testUserID)
			}
			if roomID != "room-1" {
				t.Errorf("roomID = %q, want %q", roomID, "room-1")
			}
			return nil
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/room-1/leave", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
	}

	var resp map[string]string
	json.NewDecoder(w.Body).Decode(&resp)
	if resp["status"] != "left" {
		t.Errorf("status = %q, want %q", resp["status"], "left")
	}
}

func TestCollabHandler_LeaveRoom_NotMember(t *testing.T) {
	mock := &mockCollabService{
		leaveRoomFn: func(_ context.Context, _ string, _ string) error {
			return service.ErrNotMember
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/room-1/leave", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("status = %d, want %d", w.Code, http.StatusForbidden)
	}
}

func TestCollabHandler_LeaveRoom_RoomNotFound(t *testing.T) {
	mock := &mockCollabService{
		leaveRoomFn: func(_ context.Context, _ string, _ string) error {
			return service.ErrRoomNotFound
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/nonexistent/leave", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want %d", w.Code, http.StatusNotFound)
	}
}

func TestCollabHandler_LeaveRoom_InternalError(t *testing.T) {
	mock := &mockCollabService{
		leaveRoomFn: func(_ context.Context, _ string, _ string) error {
			return errors.New("db error")
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/room-1/leave", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status = %d, want %d", w.Code, http.StatusInternalServerError)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetRoomMembers handler
// ---------------------------------------------------------------------------

func TestCollabHandler_GetRoomMembers_Success(t *testing.T) {
	mock := &mockCollabService{
		getMembersFn: func(_ context.Context, uid, roomID string) ([]domain.CollabRoomMember, error) {
			return []domain.CollabRoomMember{
				{ID: "m1", RoomID: roomID, UserID: uid, Role: "owner", JoinedAt: time.Now()},
				{ID: "m2", RoomID: roomID, UserID: "other", Role: "member", JoinedAt: time.Now()},
			}, nil
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms/room-1/members", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
	}

	var resp map[string]json.RawMessage
	json.NewDecoder(w.Body).Decode(&resp)
	if _, ok := resp["members"]; !ok {
		t.Error("response missing 'members' field")
	}
}

func TestCollabHandler_GetRoomMembers_NotMember(t *testing.T) {
	mock := &mockCollabService{
		getMembersFn: func(_ context.Context, _ string, _ string) ([]domain.CollabRoomMember, error) {
			return nil, service.ErrNotMember
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms/room-1/members", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("status = %d, want %d", w.Code, http.StatusForbidden)
	}
}

func TestCollabHandler_GetRoomMembers_InternalError(t *testing.T) {
	mock := &mockCollabService{
		getMembersFn: func(_ context.Context, _ string, _ string) ([]domain.CollabRoomMember, error) {
			return nil, errors.New("db error")
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms/room-1/members", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status = %d, want %d", w.Code, http.StatusInternalServerError)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetUserRooms handler
// ---------------------------------------------------------------------------

func TestCollabHandler_GetUserRooms_Success(t *testing.T) {
	mock := &mockCollabService{
		getUserRoomsFn: func(_ context.Context, uid string) ([]domain.CollabRoom, error) {
			return []domain.CollabRoom{
				{ID: "r1", CreatorID: uid, InviteCode: "ABC12345", RoomName: "Room 1", MaxMembers: 10, IsActive: true, MemberCount: 2},
			}, nil
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
	}

	var resp map[string]json.RawMessage
	json.NewDecoder(w.Body).Decode(&resp)
	if _, ok := resp["rooms"]; !ok {
		t.Error("response missing 'rooms' field")
	}
}

func TestCollabHandler_GetUserRooms_Empty(t *testing.T) {
	mock := &mockCollabService{
		getUserRoomsFn: func(_ context.Context, _ string) ([]domain.CollabRoom, error) {
			return []domain.CollabRoom{}, nil
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
	}

	var resp map[string]json.RawMessage
	json.NewDecoder(w.Body).Decode(&resp)

	var rooms []domain.CollabRoom
	json.Unmarshal(resp["rooms"], &rooms)
	if len(rooms) != 0 {
		t.Errorf("rooms count = %d, want 0", len(rooms))
	}
}

func TestCollabHandler_GetUserRooms_InternalError(t *testing.T) {
	mock := &mockCollabService{
		getUserRoomsFn: func(_ context.Context, _ string) ([]domain.CollabRoom, error) {
			return nil, errors.New("db error")
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status = %d, want %d", w.Code, http.StatusInternalServerError)
	}
}

// ---------------------------------------------------------------------------
// Tests: Auth (no user in context)
// ---------------------------------------------------------------------------

func TestCollabHandler_CreateRoom_Unauthorized(t *testing.T) {
	// Router without auth middleware (no user_id in context).
	h := NewCollabHandler(&mockCollabService{})
	r := chi.NewRouter()
	r.Post("/collab/rooms", h.CreateRoom)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader(`{}`))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

func TestCollabHandler_JoinRoom_Unauthorized(t *testing.T) {
	h := NewCollabHandler(&mockCollabService{})
	r := chi.NewRouter()
	r.Post("/collab/rooms/join", h.JoinRoom)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(`{}`))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

func TestCollabHandler_LeaveRoom_Unauthorized(t *testing.T) {
	h := NewCollabHandler(&mockCollabService{})
	r := chi.NewRouter()
	r.Post("/collab/rooms/{roomId}/leave", h.LeaveRoom)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/room-1/leave", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

func TestCollabHandler_GetRoomMembers_Unauthorized(t *testing.T) {
	h := NewCollabHandler(&mockCollabService{})
	r := chi.NewRouter()
	r.Get("/collab/rooms/{roomId}/members", h.GetRoomMembers)

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms/room-1/members", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

func TestCollabHandler_GetUserRooms_Unauthorized(t *testing.T) {
	h := NewCollabHandler(&mockCollabService{})
	r := chi.NewRouter()
	r.Get("/collab/rooms", h.GetUserRooms)

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

// ---------------------------------------------------------------------------
// Tests: Request body edge cases
// ---------------------------------------------------------------------------

func TestCollabHandler_CreateRoom_UnknownFields(t *testing.T) {
	mock := &mockCollabService{}
	router := setupCollabRouter(mock)

	body := `{"room_name":"Test","max_members":5,"unknown_field":true}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	// DisallowUnknownFields should reject this.
	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestCollabHandler_JoinRoom_UnknownFields(t *testing.T) {
	mock := &mockCollabService{}
	router := setupCollabRouter(mock)

	body := `{"invite_code":"TEST123","extra":"data"}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/join", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestCollabHandler_CreateRoom_EmptyBody(t *testing.T) {
	mock := &mockCollabService{
		createRoomFn: func(_ context.Context, _ string, req domain.CreateRoomRequest) (*domain.CollabRoom, error) {
			return &domain.CollabRoom{ID: "r1", MaxMembers: 10}, nil
		},
	}
	router := setupCollabRouter(mock)

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", strings.NewReader(`{}`))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("status = %d, want %d", w.Code, http.StatusCreated)
	}
}

func TestCollabHandler_LeaveRoom_MissingRoomID(t *testing.T) {
	// When roomId is empty (chi returns empty string for missing param).
	mock := &mockCollabService{}
	h := NewCollabHandler(mock)

	// Standalone handler without chi routing (roomId will be empty).
	r := chi.NewRouter()
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := context.WithValue(r.Context(), contextKey("user_id"), testUserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	})
	r.Post("/collab/rooms/leave", h.LeaveRoom) // no {roomId}

	req := httptest.NewRequest(http.MethodPost, "/collab/rooms/leave", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestCollabHandler_GetRoomMembers_MissingRoomID(t *testing.T) {
	mock := &mockCollabService{}
	h := NewCollabHandler(mock)

	r := chi.NewRouter()
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := context.WithValue(r.Context(), contextKey("user_id"), testUserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	})
	r.Get("/collab/rooms/members", h.GetRoomMembers) // no {roomId}

	req := httptest.NewRequest(http.MethodGet, "/collab/rooms/members", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

// ---------------------------------------------------------------------------
// Tests: Response format verification
// ---------------------------------------------------------------------------

func TestCollabHandler_CreateRoom_ResponseFields(t *testing.T) {
	now := time.Now()
	mock := &mockCollabService{
		createRoomFn: func(_ context.Context, _ string, _ domain.CreateRoomRequest) (*domain.CollabRoom, error) {
			return &domain.CollabRoom{
				ID:          "room-abc",
				CreatorID:   testUserID,
				InviteCode:  "XYZ98765",
				RoomName:    "My Room",
				MaxMembers:  15,
				CreatedAt:   now,
				IsActive:    true,
				MemberCount: 1,
			}, nil
		},
	}
	router := setupCollabRouter(mock)

	body := `{"room_name":"My Room","max_members":15}`
	req := httptest.NewRequest(http.MethodPost, "/collab/rooms", bytes.NewReader([]byte(body)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d", w.Code, http.StatusCreated)
	}

	var room domain.CollabRoom
	if err := json.NewDecoder(w.Body).Decode(&room); err != nil {
		t.Fatalf("decode: %v", err)
	}

	if room.ID != "room-abc" {
		t.Errorf("ID = %q, want %q", room.ID, "room-abc")
	}
	if room.InviteCode != "XYZ98765" {
		t.Errorf("InviteCode = %q, want %q", room.InviteCode, "XYZ98765")
	}
	if room.RoomName != "My Room" {
		t.Errorf("RoomName = %q, want %q", room.RoomName, "My Room")
	}
	if room.MaxMembers != 15 {
		t.Errorf("MaxMembers = %d, want 15", room.MaxMembers)
	}
	if !room.IsActive {
		t.Error("IsActive should be true")
	}
	if room.MemberCount != 1 {
		t.Errorf("MemberCount = %d, want 1", room.MemberCount)
	}
}
