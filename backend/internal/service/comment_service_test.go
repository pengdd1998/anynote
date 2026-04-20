package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock CommentRepository
// ---------------------------------------------------------------------------

type mockCommentRepo struct {
	createFn            func(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error)
	listBySharedNoteFn  func(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error)
	countBySharedNoteFn func(ctx context.Context, sharedNoteID string) (int, error)
	deleteFn            func(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) (int64, error)
}

func (m *mockCommentRepo) Create(ctx context.Context, sharedNoteID string, userID uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
	if m.createFn != nil {
		return m.createFn(ctx, sharedNoteID, userID, req)
	}
	return nil, errors.New("not implemented")
}

func (m *mockCommentRepo) ListBySharedNote(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error) {
	if m.listBySharedNoteFn != nil {
		return m.listBySharedNoteFn(ctx, sharedNoteID, limit, offset)
	}
	return nil, errors.New("not implemented")
}

func (m *mockCommentRepo) CountBySharedNote(ctx context.Context, sharedNoteID string) (int, error) {
	if m.countBySharedNoteFn != nil {
		return m.countBySharedNoteFn(ctx, sharedNoteID)
	}
	return 0, errors.New("not implemented")
}

func (m *mockCommentRepo) Delete(ctx context.Context, commentID uuid.UUID, userID uuid.UUID) (int64, error) {
	if m.deleteFn != nil {
		return m.deleteFn(ctx, commentID, userID)
	}
	return 0, errors.New("not implemented")
}

// ---------------------------------------------------------------------------
// Tests: CreateComment
// ---------------------------------------------------------------------------

func TestCommentService_CreateComment_Success(t *testing.T) {
	userID := uuid.New()
	commentID := uuid.New()

	repo := &mockCommentRepo{
		createFn: func(ctx context.Context, sharedNoteID string, uid uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
			if sharedNoteID != "share-abc" {
				t.Errorf("sharedNoteID = %q, want %q", sharedNoteID, "share-abc")
			}
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			if req.EncryptedContent != "enc-comment-data" {
				t.Errorf("EncryptedContent = %q, want %q", req.EncryptedContent, "enc-comment-data")
			}
			return &domain.Comment{
				ID:               commentID,
				SharedNoteID:     sharedNoteID,
				UserID:           uid,
				EncryptedContent: req.EncryptedContent,
			}, nil
		},
	}

	svc := NewCommentService(repo)

	comment, err := svc.CreateComment(context.Background(), "share-abc", userID, domain.CreateCommentRequest{
		EncryptedContent: "enc-comment-data",
	})
	if err != nil {
		t.Fatalf("CreateComment: %v", err)
	}
	if comment.ID != commentID {
		t.Errorf("ID = %v, want %v", comment.ID, commentID)
	}
	if comment.SharedNoteID != "share-abc" {
		t.Errorf("SharedNoteID = %q, want %q", comment.SharedNoteID, "share-abc")
	}
}

func TestCommentService_CreateComment_RepoError(t *testing.T) {
	repo := &mockCommentRepo{
		createFn: func(ctx context.Context, sharedNoteID string, uid uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
			return nil, errors.New("db insert failed")
		},
	}

	svc := NewCommentService(repo)

	_, err := svc.CreateComment(context.Background(), "share-abc", uuid.New(), domain.CreateCommentRequest{
		EncryptedContent: "enc-data",
	})
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: ListComments
// ---------------------------------------------------------------------------

func TestCommentService_ListComments_Success(t *testing.T) {
	now := time.Now()
	repo := &mockCommentRepo{
		listBySharedNoteFn: func(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error) {
			if sharedNoteID != "share-abc" {
				t.Errorf("sharedNoteID = %q, want %q", sharedNoteID, "share-abc")
			}
			if limit != 50 {
				t.Errorf("limit = %d, want 50", limit)
			}
			if offset != 0 {
				t.Errorf("offset = %d, want 0", offset)
			}
			return []domain.Comment{
				{ID: uuid.New(), SharedNoteID: sharedNoteID, EncryptedContent: "c1", CreatedAt: now},
				{ID: uuid.New(), SharedNoteID: sharedNoteID, EncryptedContent: "c2", CreatedAt: now},
			}, nil
		},
		countBySharedNoteFn: func(ctx context.Context, sharedNoteID string) (int, error) {
			return 2, nil
		},
	}

	svc := NewCommentService(repo)

	resp, err := svc.ListComments(context.Background(), "share-abc", 50, 0)
	if err != nil {
		t.Fatalf("ListComments: %v", err)
	}
	if resp.Total != 2 {
		t.Errorf("Total = %d, want 2", resp.Total)
	}
	if len(resp.Comments) != 2 {
		t.Errorf("Comments count = %d, want 2", len(resp.Comments))
	}
}

func TestCommentService_ListComments_EmptyResult(t *testing.T) {
	repo := &mockCommentRepo{
		listBySharedNoteFn: func(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error) {
			return nil, nil
		},
		countBySharedNoteFn: func(ctx context.Context, sharedNoteID string) (int, error) {
			return 0, nil
		},
	}

	svc := NewCommentService(repo)

	resp, err := svc.ListComments(context.Background(), "share-abc", 50, 0)
	if err != nil {
		t.Fatalf("ListComments: %v", err)
	}
	if resp.Total != 0 {
		t.Errorf("Total = %d, want 0", resp.Total)
	}
	// Service ensures nil slice is replaced with empty slice.
	if resp.Comments == nil {
		t.Error("Comments should not be nil (should be empty slice)")
	}
	if len(resp.Comments) != 0 {
		t.Errorf("Comments count = %d, want 0", len(resp.Comments))
	}
}

func TestCommentService_ListComments_ListError(t *testing.T) {
	repo := &mockCommentRepo{
		listBySharedNoteFn: func(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error) {
			return nil, errors.New("db error")
		},
	}

	svc := NewCommentService(repo)

	_, err := svc.ListComments(context.Background(), "share-abc", 50, 0)
	if err == nil {
		t.Error("expected error when list fails")
	}
}

func TestCommentService_ListComments_CountError(t *testing.T) {
	repo := &mockCommentRepo{
		listBySharedNoteFn: func(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error) {
			return []domain.Comment{}, nil
		},
		countBySharedNoteFn: func(ctx context.Context, sharedNoteID string) (int, error) {
			return 0, errors.New("count error")
		},
	}

	svc := NewCommentService(repo)

	_, err := svc.ListComments(context.Background(), "share-abc", 50, 0)
	if err == nil {
		t.Error("expected error when count fails")
	}
}

func TestCommentService_ListComments_WithPagination(t *testing.T) {
	var capturedLimit, capturedOffset int
	repo := &mockCommentRepo{
		listBySharedNoteFn: func(ctx context.Context, sharedNoteID string, limit, offset int) ([]domain.Comment, error) {
			capturedLimit = limit
			capturedOffset = offset
			return []domain.Comment{}, nil
		},
		countBySharedNoteFn: func(ctx context.Context, sharedNoteID string) (int, error) {
			return 100, nil
		},
	}

	svc := NewCommentService(repo)

	resp, err := svc.ListComments(context.Background(), "share-abc", 10, 20)
	if err != nil {
		t.Fatalf("ListComments: %v", err)
	}
	if capturedLimit != 10 {
		t.Errorf("limit = %d, want 10", capturedLimit)
	}
	if capturedOffset != 20 {
		t.Errorf("offset = %d, want 20", capturedOffset)
	}
	if resp.Total != 100 {
		t.Errorf("Total = %d, want 100", resp.Total)
	}
}

// ---------------------------------------------------------------------------
// Tests: DeleteComment
// ---------------------------------------------------------------------------

func TestCommentService_DeleteComment_Success(t *testing.T) {
	commentID := uuid.New()
	userID := uuid.New()

	repo := &mockCommentRepo{
		deleteFn: func(ctx context.Context, cid uuid.UUID, uid uuid.UUID) (int64, error) {
			if cid != commentID {
				t.Errorf("commentID = %v, want %v", cid, commentID)
			}
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			return 1, nil
		},
	}

	svc := NewCommentService(repo)

	err := svc.DeleteComment(context.Background(), commentID, userID)
	if err != nil {
		t.Fatalf("DeleteComment: %v", err)
	}
}

func TestCommentService_DeleteComment_NotAuthor(t *testing.T) {
	commentID := uuid.New()
	userID := uuid.New()

	repo := &mockCommentRepo{
		deleteFn: func(ctx context.Context, cid uuid.UUID, uid uuid.UUID) (int64, error) {
			// Simulate: comment exists but belongs to a different user.
			return 0, nil
		},
	}

	svc := NewCommentService(repo)

	err := svc.DeleteComment(context.Background(), commentID, userID)
	if err != ErrNotCommentAuthor {
		t.Errorf("error = %v, want ErrNotCommentAuthor", err)
	}
}

func TestCommentService_DeleteComment_RepoError(t *testing.T) {
	repo := &mockCommentRepo{
		deleteFn: func(ctx context.Context, cid uuid.UUID, uid uuid.UUID) (int64, error) {
			return 0, errors.New("db error")
		},
	}

	svc := NewCommentService(repo)

	err := svc.DeleteComment(context.Background(), uuid.New(), uuid.New())
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

// ---------------------------------------------------------------------------
// Mock SharedNoteRepository for comment push tests
// ---------------------------------------------------------------------------

type mockSharedNoteRepoForComments struct {
	getByIDFn func(ctx context.Context, id string) (*domain.SharedNote, error)
}

func (m *mockSharedNoteRepoForComments) Create(ctx context.Context, note *domain.SharedNote) error {
	return nil
}

func (m *mockSharedNoteRepoForComments) GetByID(ctx context.Context, id string) (*domain.SharedNote, error) {
	if m.getByIDFn != nil {
		return m.getByIDFn(ctx, id)
	}
	return nil, errors.New("not found")
}

func (m *mockSharedNoteRepoForComments) IncrementViewCount(ctx context.Context, id string) error {
	return nil
}

func (m *mockSharedNoteRepoForComments) DeleteExpired(ctx context.Context) (int64, error) {
	return 0, nil
}

func (m *mockSharedNoteRepoForComments) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.SharedNote, error) {
	return nil, nil
}

func (m *mockSharedNoteRepoForComments) ListPublic(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
	return nil, nil
}

func (m *mockSharedNoteRepoForComments) React(ctx context.Context, sharedNoteID string, userID uuid.UUID, reactionType string) (*domain.ReactResponse, error) {
	return nil, nil
}

func (m *mockSharedNoteRepoForComments) GetUserReaction(ctx context.Context, sharedNoteID string, userID uuid.UUID) (map[string]bool, error) {
	return nil, nil
}

// ---------------------------------------------------------------------------
// Mock PushService for comment push tests
// ---------------------------------------------------------------------------

type mockPushServiceForComments struct {
	calls []pushCall
}

type pushCall struct {
	userID  string
	payload PushPayload
}

func (m *mockPushServiceForComments) SendPush(ctx context.Context, userID string, payload PushPayload) error {
	m.calls = append(m.calls, pushCall{userID: userID, payload: payload})
	return nil
}

func (m *mockPushServiceForComments) RegisterDevice(ctx context.Context, userID string, token string, platform string) error {
	return nil
}

func (m *mockPushServiceForComments) UnregisterDevice(ctx context.Context, token string) error {
	return nil
}

// ---------------------------------------------------------------------------
// Tests: CreateComment push notifications
// ---------------------------------------------------------------------------

func TestCommentService_CreateComment_SendsPushToOwner(t *testing.T) {
	ownerID := uuid.New()
	commenterID := uuid.New()
	commentID := uuid.New()

	commentRepo := &mockCommentRepo{
		createFn: func(ctx context.Context, sharedNoteID string, uid uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
			return &domain.Comment{
				ID:               commentID,
				SharedNoteID:     sharedNoteID,
				UserID:           uid,
				EncryptedContent: req.EncryptedContent,
			}, nil
		},
	}

	shareRepo := &mockSharedNoteRepoForComments{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return &domain.SharedNote{
				ID:        "share-abc",
				CreatedBy: ownerID,
			}, nil
		},
	}

	pushSvc := &mockPushServiceForComments{}

	svc := NewCommentService(commentRepo,
		WithCommentPushService(pushSvc),
		WithCommentShareRepo(shareRepo),
	)

	comment, err := svc.CreateComment(context.Background(), "share-abc", commenterID, domain.CreateCommentRequest{
		EncryptedContent: "enc-comment-data",
	})
	if err != nil {
		t.Fatalf("CreateComment: %v", err)
	}
	if comment.ID != commentID {
		t.Errorf("ID = %v, want %v", comment.ID, commentID)
	}

	// Verify push was sent to the note owner.
	if len(pushSvc.calls) != 1 {
		t.Fatalf("expected 1 push notification, got %d", len(pushSvc.calls))
	}
	call := pushSvc.calls[0]
	if call.userID != ownerID.String() {
		t.Errorf("push userID = %q, want %q", call.userID, ownerID.String())
	}
	if call.payload.Title != "New Comment" {
		t.Errorf("Title = %q, want %q", call.payload.Title, "New Comment")
	}
	if call.payload.Body != "Someone commented on your shared note" {
		t.Errorf("Body = %q, want %q", call.payload.Body, "Someone commented on your shared note")
	}
	if call.payload.Data["type"] != "new_comment" {
		t.Errorf("Data[type] = %v, want %q", call.payload.Data["type"], "new_comment")
	}
	if call.payload.Data["shared_note_id"] != "share-abc" {
		t.Errorf("Data[shared_note_id] = %v, want %q", call.payload.Data["shared_note_id"], "share-abc")
	}
	if call.payload.Data["comment_id"] != commentID.String() {
		t.Errorf("Data[comment_id] = %v, want %q", call.payload.Data["comment_id"], commentID.String())
	}
}

func TestCommentService_CreateComment_NoSelfNotify(t *testing.T) {
	// Owner comments on their own note -- should NOT trigger a push.
	ownerID := uuid.New()

	commentRepo := &mockCommentRepo{
		createFn: func(ctx context.Context, sharedNoteID string, uid uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
			return &domain.Comment{
				ID:               uuid.New(),
				SharedNoteID:     sharedNoteID,
				UserID:           uid,
				EncryptedContent: req.EncryptedContent,
			}, nil
		},
	}

	shareRepo := &mockSharedNoteRepoForComments{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return &domain.SharedNote{
				ID:        "share-abc",
				CreatedBy: ownerID,
			}, nil
		},
	}

	pushSvc := &mockPushServiceForComments{}

	svc := NewCommentService(commentRepo,
		WithCommentPushService(pushSvc),
		WithCommentShareRepo(shareRepo),
	)

	_, err := svc.CreateComment(context.Background(), "share-abc", ownerID, domain.CreateCommentRequest{
		EncryptedContent: "enc-comment-data",
	})
	if err != nil {
		t.Fatalf("CreateComment: %v", err)
	}

	// No push should be sent when the commenter is the note owner.
	if len(pushSvc.calls) != 0 {
		t.Errorf("expected 0 push notifications for self-comment, got %d", len(pushSvc.calls))
	}
}

func TestCommentService_CreateComment_NoPushWithoutDeps(t *testing.T) {
	// Without push service or share repo, comment creation should succeed without errors.
	commentRepo := &mockCommentRepo{
		createFn: func(ctx context.Context, sharedNoteID string, uid uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
			return &domain.Comment{
				ID:               uuid.New(),
				SharedNoteID:     sharedNoteID,
				UserID:           uid,
				EncryptedContent: req.EncryptedContent,
			}, nil
		},
	}

	svc := NewCommentService(commentRepo)

	_, err := svc.CreateComment(context.Background(), "share-abc", uuid.New(), domain.CreateCommentRequest{
		EncryptedContent: "enc-comment-data",
	})
	if err != nil {
		t.Fatalf("CreateComment without push deps: %v", err)
	}
}

func TestCommentService_CreateComment_ShareRepoErrorNoFailure(t *testing.T) {
	// If the shared note lookup fails, the comment is still created successfully.
	commentRepo := &mockCommentRepo{
		createFn: func(ctx context.Context, sharedNoteID string, uid uuid.UUID, req domain.CreateCommentRequest) (*domain.Comment, error) {
			return &domain.Comment{
				ID:               uuid.New(),
				SharedNoteID:     sharedNoteID,
				UserID:           uid,
				EncryptedContent: req.EncryptedContent,
			}, nil
		},
	}

	shareRepo := &mockSharedNoteRepoForComments{
		getByIDFn: func(ctx context.Context, id string) (*domain.SharedNote, error) {
			return nil, errors.New("db error")
		},
	}

	pushSvc := &mockPushServiceForComments{}

	svc := NewCommentService(commentRepo,
		WithCommentPushService(pushSvc),
		WithCommentShareRepo(shareRepo),
	)

	_, err := svc.CreateComment(context.Background(), "share-abc", uuid.New(), domain.CreateCommentRequest{
		EncryptedContent: "enc-data",
	})
	if err != nil {
		t.Fatalf("CreateComment should succeed even when share lookup fails: %v", err)
	}

	// No push should be sent if the share lookup failed.
	if len(pushSvc.calls) != 0 {
		t.Errorf("expected 0 push notifications when share lookup fails, got %d", len(pushSvc.calls))
	}
}
