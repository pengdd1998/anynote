package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock CommentService
// ---------------------------------------------------------------------------

type mockCommentService struct {
	createCommentFn func(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error)
	listCommentsFn  func(ctx context.Context, sharedNoteID string, limit, offset int) (*domain.ListCommentsResponse, error)
	deleteCommentFn func(ctx context.Context, commentID, userID uuid.UUID) error
}

func (m *mockCommentService) CreateComment(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
	if m.createCommentFn != nil {
		return m.createCommentFn(ctx, sharedNoteID, userID, req)
	}
	return nil, errors.New("not implemented")
}

func (m *mockCommentService) ListComments(ctx context.Context, sharedNoteID string, limit, offset int) (*domain.ListCommentsResponse, error) {
	if m.listCommentsFn != nil {
		return m.listCommentsFn(ctx, sharedNoteID, limit, offset)
	}
	return nil, errors.New("not implemented")
}

func (m *mockCommentService) DeleteComment(ctx context.Context, commentID, userID uuid.UUID) error {
	if m.deleteCommentFn != nil {
		return m.deleteCommentFn(ctx, commentID, userID)
	}
	return errors.New("not implemented")
}

// ---------------------------------------------------------------------------
// Router setup helper
// ---------------------------------------------------------------------------

// setupCommentRouter creates a chi Mux with comment routes wired, matching
// the real route layout from router.go.
func setupCommentRouter(svc *mockCommentService) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestLogger)

	h := &CommentHandler{commentService: svc}

	// List comments is public (no auth required per router.go).
	r.Get("/api/v1/share/{id}/comments", h.ListComments)

	// Authenticated routes.
	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		r.Post("/api/v1/share/{id}/comments", h.CreateComment)
		r.Delete("/api/v1/comments/{id}", h.DeleteComment)
	})

	return r
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/share/{id}/comments (CreateComment)
// ---------------------------------------------------------------------------

func TestCommentHandler_CreateComment_Success(t *testing.T) {
	userID := uuid.New()
	commentID := uuid.New()
	sharedNoteID := "share-abc-123"

	svc := &mockCommentService{
		createCommentFn: func(ctx context.Context, sid string, uid uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
			if sid != sharedNoteID {
				t.Errorf("sharedNoteID = %q, want %q", sid, sharedNoteID)
			}
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if req.EncryptedContent != "enc-comment-blob" {
				t.Errorf("EncryptedContent = %q, want %q", req.EncryptedContent, "enc-comment-blob")
			}
			return &domain.Comment{
				ID:               commentID,
				SharedNoteID:     sid,
				UserID:           uid,
				EncryptedContent: req.EncryptedContent,
			}, nil
		},
	}

	router := setupCommentRouter(svc)

	body, _ := json.Marshal(domain.CreateCommentRequest{
		EncryptedContent: "enc-comment-blob",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/"+sharedNoteID+"/comments", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusCreated, rec.Body.String())
	}

	var resp domain.Comment
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.ID != commentID {
		t.Errorf("ID = %v, want %v", resp.ID, commentID)
	}
}

func TestCommentHandler_CreateComment_Unauthorized(t *testing.T) {
	svc := &mockCommentService{}
	router := setupCommentRouter(svc)

	body, _ := json.Marshal(domain.CreateCommentRequest{
		EncryptedContent: "data",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/abc/comments", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestCommentHandler_CreateComment_InvalidBody(t *testing.T) {
	svc := &mockCommentService{}
	router := setupCommentRouter(svc)

	userID := uuid.New()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/abc/comments", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "invalid_request" {
		t.Errorf("error type = %q, want %q", errResp.Error, "invalid_request")
	}
}

func TestCommentHandler_CreateComment_MissingEncryptedContent(t *testing.T) {
	svc := &mockCommentService{}
	router := setupCommentRouter(svc)

	userID := uuid.New()
	body, _ := json.Marshal(domain.CreateCommentRequest{
		EncryptedContent: "",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/abc/comments", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error, "validation_error")
	}
}

func TestCommentHandler_CreateComment_ServiceError(t *testing.T) {
	svc := &mockCommentService{
		createCommentFn: func(ctx context.Context, sid string, uid uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
			return nil, errors.New("db error")
		},
	}

	router := setupCommentRouter(svc)
	userID := uuid.New()

	body, _ := json.Marshal(domain.CreateCommentRequest{
		EncryptedContent: "data",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/share/abc/comments", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/share/{id}/comments (ListComments)
// ---------------------------------------------------------------------------

func TestCommentHandler_ListComments_Success(t *testing.T) {
	sharedNoteID := "share-abc-123"
	commentID := uuid.New()
	userID := uuid.New()

	svc := &mockCommentService{
		listCommentsFn: func(ctx context.Context, sid string, limit, offset int) (*domain.ListCommentsResponse, error) {
			if sid != sharedNoteID {
				t.Errorf("sharedNoteID = %q, want %q", sid, sharedNoteID)
			}
			return &domain.ListCommentsResponse{
				Comments: []domain.Comment{
					{ID: commentID, SharedNoteID: sid, UserID: userID, EncryptedContent: "c1"},
				},
				Total: 1,
			}, nil
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/"+sharedNoteID+"/comments", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.ListCommentsResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Total != 1 {
		t.Errorf("Total = %d, want 1", resp.Total)
	}
	if len(resp.Comments) != 1 {
		t.Fatalf("Comments count = %d, want 1", len(resp.Comments))
	}
	if resp.Comments[0].ID != commentID {
		t.Errorf("Comment ID = %v, want %v", resp.Comments[0].ID, commentID)
	}
}

func TestCommentHandler_ListComments_EmptyResult(t *testing.T) {
	svc := &mockCommentService{
		listCommentsFn: func(ctx context.Context, sid string, limit, offset int) (*domain.ListCommentsResponse, error) {
			return &domain.ListCommentsResponse{
				Comments: []domain.Comment{},
				Total:    0,
			}, nil
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/abc/comments", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var resp domain.ListCommentsResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Total != 0 {
		t.Errorf("Total = %d, want 0", resp.Total)
	}
}

func TestCommentHandler_ListComments_WithPagination(t *testing.T) {
	var capturedLimit, capturedOffset int
	svc := &mockCommentService{
		listCommentsFn: func(ctx context.Context, sid string, limit, offset int) (*domain.ListCommentsResponse, error) {
			capturedLimit = limit
			capturedOffset = offset
			return &domain.ListCommentsResponse{
				Comments: []domain.Comment{},
				Total:    100,
			}, nil
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/abc/comments?limit=10&offset=20", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if capturedLimit != 10 {
		t.Errorf("limit = %d, want 10", capturedLimit)
	}
	if capturedOffset != 20 {
		t.Errorf("offset = %d, want 20", capturedOffset)
	}
}

func TestCommentHandler_ListComments_LimitCappedAt100(t *testing.T) {
	var capturedLimit int
	svc := &mockCommentService{
		listCommentsFn: func(ctx context.Context, sid string, limit, offset int) (*domain.ListCommentsResponse, error) {
			capturedLimit = limit
			return &domain.ListCommentsResponse{Comments: []domain.Comment{}, Total: 0}, nil
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/abc/comments?limit=200", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedLimit != 100 {
		t.Errorf("limit = %d, want 100 (capped)", capturedLimit)
	}
}

func TestCommentHandler_ListComments_DefaultPagination(t *testing.T) {
	var capturedLimit, capturedOffset int
	svc := &mockCommentService{
		listCommentsFn: func(ctx context.Context, sid string, limit, offset int) (*domain.ListCommentsResponse, error) {
			capturedLimit = limit
			capturedOffset = offset
			return &domain.ListCommentsResponse{Comments: []domain.Comment{}, Total: 0}, nil
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/abc/comments", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedLimit != 50 {
		t.Errorf("default limit = %d, want 50", capturedLimit)
	}
	if capturedOffset != 0 {
		t.Errorf("default offset = %d, want 0", capturedOffset)
	}
}

func TestCommentHandler_ListComments_ServiceError(t *testing.T) {
	svc := &mockCommentService{
		listCommentsFn: func(ctx context.Context, sid string, limit, offset int) (*domain.ListCommentsResponse, error) {
			return nil, errors.New("db error")
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/abc/comments", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

func TestCommentHandler_ListComments_NoAuthRequired(t *testing.T) {
	// Verify that listing comments does not require authentication.
	svc := &mockCommentService{
		listCommentsFn: func(ctx context.Context, sid string, limit, offset int) (*domain.ListCommentsResponse, error) {
			return &domain.ListCommentsResponse{Comments: []domain.Comment{}, Total: 0}, nil
		},
	}

	router := setupCommentRouter(svc)

	// No Authorization header.
	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/abc/comments", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d (no auth required)", rec.Code, http.StatusOK)
	}
}

// ---------------------------------------------------------------------------
// Tests: DELETE /api/v1/comments/{id} (DeleteComment)
// ---------------------------------------------------------------------------

func TestCommentHandler_DeleteComment_Success(t *testing.T) {
	commentID := uuid.New()
	userID := uuid.New()

	svc := &mockCommentService{
		deleteCommentFn: func(ctx context.Context, cid, uid uuid.UUID) error {
			if cid != commentID {
				t.Errorf("commentID = %v, want %v", cid, commentID)
			}
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			return nil
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/comments/"+commentID.String(), nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusNoContent, rec.Body.String())
	}
}

func TestCommentHandler_DeleteComment_Unauthorized(t *testing.T) {
	svc := &mockCommentService{}
	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/comments/"+uuid.New().String(), nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestCommentHandler_DeleteComment_NotAuthor(t *testing.T) {
	commentID := uuid.New()
	userID := uuid.New()

	svc := &mockCommentService{
		deleteCommentFn: func(ctx context.Context, cid, uid uuid.UUID) error {
			return service.ErrNotCommentAuthor
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/comments/"+commentID.String(), nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusForbidden, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "forbidden" {
		t.Errorf("error type = %q, want %q", errResp.Error, "forbidden")
	}
}

func TestCommentHandler_DeleteComment_CommentNotFound(t *testing.T) {
	// The current implementation maps rowsAffected==0 to ErrNotCommentAuthor,
	// not ErrCommentNotFound. This test verifies that the sentinel mapping
	// works for ErrCommentNotFound as well (in case the service layer is
	// updated to distinguish these cases).
	commentID := uuid.New()
	userID := uuid.New()

	svc := &mockCommentService{
		deleteCommentFn: func(ctx context.Context, cid, uid uuid.UUID) error {
			return service.ErrCommentNotFound
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/comments/"+commentID.String(), nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusNotFound, rec.Body.String())
	}
}

func TestCommentHandler_DeleteComment_InvalidUUID(t *testing.T) {
	svc := &mockCommentService{}
	router := setupCommentRouter(svc)

	userID := uuid.New()
	req := httptest.NewRequest(http.MethodDelete, "/api/v1/comments/not-a-uuid", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "invalid_id" {
		t.Errorf("error type = %q, want %q", errResp.Error, "invalid_id")
	}
}

func TestCommentHandler_DeleteComment_InternalError(t *testing.T) {
	commentID := uuid.New()
	userID := uuid.New()

	svc := &mockCommentService{
		deleteCommentFn: func(ctx context.Context, cid, uid uuid.UUID) error {
			return errors.New("unexpected db error")
		},
	}

	router := setupCommentRouter(svc)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/comments/"+commentID.String(), nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}
