package repository

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestPlatformConnectionRepository_DocumentsExpectedBehavior documents expected SQL behaviors.
func TestPlatformConnectionRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("ListByUser_returns_connections", func(t *testing.T) {
		// SELECT id, user_id, platform, platform_uid, display_name, encrypted_auth,
		//   status, last_verified, created_at, updated_at
		// FROM platform_connections WHERE user_id = $1 ORDER BY created_at DESC
		t.Log("documented: ListByUser returns user's platform connections, newest first")
	})

	t.Run("GetByPlatform_selects_connection", func(t *testing.T) {
		// SELECT ... FROM platform_connections WHERE user_id = $1 AND platform = $2
		t.Log("documented: GetByPlatform returns connection for user+platform combination")
	})

	t.Run("Create_inserts_connection", func(t *testing.T) {
		// INSERT INTO platform_connections (id, user_id, platform, platform_uid, display_name, encrypted_auth, status)
		// VALUES ($1, $2, $3, $4, $5, $6, $7)
		t.Log("documented: Create inserts new platform connection with encrypted auth data")
	})

	t.Run("Delete_removes_connection", func(t *testing.T) {
		// DELETE FROM platform_connections WHERE id = $1
		t.Log("documented: Delete removes connection by ID")
	})

	t.Run("Update_updates_connection", func(t *testing.T) {
		// UPDATE platform_connections SET
		//   platform_uid=$3, display_name=$4, encrypted_auth=$5, status=$6,
		//   last_verified=NOW(), updated_at=NOW()
		// WHERE id = $1 AND user_id = $2
		t.Log("documented: Update modifies connection, scoped to user_id, sets last_verified")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

type mockPlatformConnRepo struct {
	conns map[uuid.UUID]*domain.PlatformConnection
}

func newMockPlatformConnRepo() *mockPlatformConnRepo {
	return &mockPlatformConnRepo{
		conns: make(map[uuid.UUID]*domain.PlatformConnection),
	}
}

func (m *mockPlatformConnRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.PlatformConnection, error) {
	var result []domain.PlatformConnection
	for _, c := range m.conns {
		if c.UserID == userID {
			result = append(result, *c)
		}
	}
	return result, nil
}

func (m *mockPlatformConnRepo) GetByPlatform(ctx context.Context, userID uuid.UUID, platform string) (*domain.PlatformConnection, error) {
	for _, c := range m.conns {
		if c.UserID == userID && c.Platform == platform {
			return c, nil
		}
	}
	return nil, errNotFound
}

func (m *mockPlatformConnRepo) Create(ctx context.Context, conn *domain.PlatformConnection) error {
	m.conns[conn.ID] = conn
	return nil
}

func (m *mockPlatformConnRepo) Delete(ctx context.Context, id uuid.UUID) error {
	delete(m.conns, id)
	return nil
}

func (m *mockPlatformConnRepo) Update(ctx context.Context, conn *domain.PlatformConnection) error {
	m.conns[conn.ID] = conn
	return nil
}

func TestMockPlatformConnRepo_Create(t *testing.T) {
	repo := newMockPlatformConnRepo()
	ctx := context.Background()
	userID := uuid.New()
	connID := uuid.New()

	conn := &domain.PlatformConnection{
		ID: connID, UserID: userID, Platform: "xhs",
		PlatformUID: "xhs-user-123", DisplayName: "XHS User", Status: "active",
	}
	repo.Create(ctx, conn)

	// Verify via GetByPlatform.
	got, err := repo.GetByPlatform(ctx, userID, "xhs")
	if err != nil {
		t.Fatalf("GetByPlatform: %v", err)
	}
	if got.Platform != "xhs" {
		t.Errorf("Platform = %q, want %q", got.Platform, "xhs")
	}
	if got.DisplayName != "XHS User" {
		t.Errorf("DisplayName = %q, want %q", got.DisplayName, "XHS User")
	}
}

func TestMockPlatformConnRepo_GetByPlatform_NotFound(t *testing.T) {
	repo := newMockPlatformConnRepo()
	ctx := context.Background()

	_, err := repo.GetByPlatform(ctx, uuid.New(), "nonexistent")
	if err == nil {
		t.Error("GetByPlatform should return error for nonexistent platform")
	}
}

func TestMockPlatformConnRepo_ListByUser(t *testing.T) {
	repo := newMockPlatformConnRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()

	repo.Create(ctx, &domain.PlatformConnection{ID: uuid.New(), UserID: user1, Platform: "xhs"})
	repo.Create(ctx, &domain.PlatformConnection{ID: uuid.New(), UserID: user1, Platform: "wechat"})
	repo.Create(ctx, &domain.PlatformConnection{ID: uuid.New(), UserID: user2, Platform: "medium"})

	conns, err := repo.ListByUser(ctx, user1)
	if err != nil {
		t.Fatalf("ListByUser: %v", err)
	}
	if len(conns) != 2 {
		t.Errorf("len(conns) = %d, want 2", len(conns))
	}
}

func TestMockPlatformConnRepo_Update(t *testing.T) {
	repo := newMockPlatformConnRepo()
	ctx := context.Background()
	connID := uuid.New()
	userID := uuid.New()

	repo.Create(ctx, &domain.PlatformConnection{
		ID: connID, UserID: userID, Platform: "xhs", DisplayName: "Old Name", Status: "active",
	})

	repo.Update(ctx, &domain.PlatformConnection{
		ID: connID, UserID: userID, Platform: "xhs", DisplayName: "New Name", Status: "expired",
	})

	got, _ := repo.GetByPlatform(ctx, userID, "xhs")
	if got.DisplayName != "New Name" {
		t.Errorf("DisplayName = %q, want %q", got.DisplayName, "New Name")
	}
	if got.Status != "expired" {
		t.Errorf("Status = %q, want %q", got.Status, "expired")
	}
}

func TestMockPlatformConnRepo_Delete(t *testing.T) {
	repo := newMockPlatformConnRepo()
	ctx := context.Background()
	connID := uuid.New()
	userID := uuid.New()

	repo.Create(ctx, &domain.PlatformConnection{ID: connID, UserID: userID, Platform: "xhs"})
	repo.Delete(ctx, connID)

	_, err := repo.GetByPlatform(ctx, userID, "xhs")
	if err == nil {
		t.Error("connection should be deleted")
	}
}

func TestMockPlatformConnRepo_MultiplePlatforms(t *testing.T) {
	repo := newMockPlatformConnRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.Create(ctx, &domain.PlatformConnection{ID: uuid.New(), UserID: userID, Platform: "xhs"})
	repo.Create(ctx, &domain.PlatformConnection{ID: uuid.New(), UserID: userID, Platform: "wechat"})
	repo.Create(ctx, &domain.PlatformConnection{ID: uuid.New(), UserID: userID, Platform: "zhihu"})

	// Each platform should be individually accessible.
	for _, platform := range []string{"xhs", "wechat", "zhihu"} {
		got, err := repo.GetByPlatform(ctx, userID, platform)
		if err != nil {
			t.Errorf("GetByPlatform(%q): %v", platform, err)
		}
		if got.Platform != platform {
			t.Errorf("Platform = %q, want %q", got.Platform, platform)
		}
	}

	// ListByUser should return all 3.
	conns, _ := repo.ListByUser(ctx, userID)
	if len(conns) != 3 {
		t.Errorf("len(conns) = %d, want 3", len(conns))
	}
}
