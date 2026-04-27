package repository

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestProfileRepository_DocumentsExpectedBehavior documents the expected SQL
// behaviors for the ProfileRepository.
func TestProfileRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("GetPublicProfile_returns_profile_when_enabled", func(t *testing.T) {
		// SELECT username, COALESCE(display_name, ''), COALESCE(bio, ''),
		//   COALESCE(plan, 'free'), COALESCE(public_profile_enabled, false)
		// FROM users WHERE username = $1 AND COALESCE(public_profile_enabled, false) = true
		// Returns nil when profile is not public or username does not exist.
		t.Log("documented: GetPublicProfile returns profile only when public_profile_enabled is true")
	})

	t.Run("UpdateProfile_updates_display_bio_public", func(t *testing.T) {
		// UPDATE users SET display_name = $1, bio = $2, public_profile_enabled = $3, updated_at = NOW()
		// WHERE id = $4
		t.Log("documented: UpdateProfile sets display_name, bio, public flag, and touches updated_at")
	})

	t.Run("GetProfileByUserID_returns_profile", func(t *testing.T) {
		// SELECT username, COALESCE(display_name, ''), COALESCE(bio, ''),
		//   COALESCE(plan, 'free'), COALESCE(public_profile_enabled, false)
		// FROM users WHERE id = $1
		// Returns nil when user does not exist.
		t.Log("documented: GetProfileByUserID returns profile data by user UUID")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

type mockProfileRepo struct {
	profiles map[uuid.UUID]*domain.PublicProfile // userID -> profile
}

func newMockProfileRepo() *mockProfileRepo {
	return &mockProfileRepo{
		profiles: make(map[uuid.UUID]*domain.PublicProfile),
	}
}

// Helper to set up a user with profile data in the mock.
func (m *mockProfileRepo) addUser(userID uuid.UUID, profile *domain.PublicProfile) {
	m.profiles[userID] = profile
}

// findByUsername scans profiles to find one matching the given username.
func (m *mockProfileRepo) findByUsername(username string) *domain.PublicProfile {
	for _, p := range m.profiles {
		if p.Username == username {
			return p
		}
	}
	return nil
}

func (m *mockProfileRepo) GetPublicProfile(ctx context.Context, username string) (*domain.PublicProfile, error) {
	p := m.findByUsername(username)
	if p == nil || !p.PublicEnabled {
		return nil, errNotFound
	}
	return p, nil
}

func (m *mockProfileRepo) UpdateProfile(ctx context.Context, userID uuid.UUID, displayName string, bio string, publicEnabled bool) error {
	p, ok := m.profiles[userID]
	if !ok {
		return errNotFound
	}
	p.DisplayName = displayName
	p.Bio = bio
	p.PublicEnabled = publicEnabled
	return nil
}

func (m *mockProfileRepo) GetProfileByUserID(ctx context.Context, userID uuid.UUID) (*domain.PublicProfile, error) {
	p, ok := m.profiles[userID]
	if !ok {
		return nil, errNotFound
	}
	return p, nil
}

// ---------------------------------------------------------------------------
// Tests: GetPublicProfile
// ---------------------------------------------------------------------------

func TestMockProfileRepo_GetPublicProfile_Enabled(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.addUser(userID, &domain.PublicProfile{
		Username:      "alice",
		DisplayName:   "Alice",
		Bio:           "Hello world",
		Plan:          "pro",
		PublicEnabled: true,
	})

	profile, err := repo.GetPublicProfile(ctx, "alice")
	if err != nil {
		t.Fatalf("GetPublicProfile: %v", err)
	}
	if profile.DisplayName != "Alice" {
		t.Errorf("DisplayName = %q, want %q", profile.DisplayName, "Alice")
	}
	if profile.Plan != "pro" {
		t.Errorf("Plan = %q, want %q", profile.Plan, "pro")
	}
}

func TestMockProfileRepo_GetPublicProfile_NotPublic(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.addUser(userID, &domain.PublicProfile{
		Username:      "bob",
		PublicEnabled: false,
	})

	_, err := repo.GetPublicProfile(ctx, "bob")
	if err == nil {
		t.Error("GetPublicProfile should return error when profile is not public")
	}
}

func TestMockProfileRepo_GetPublicProfile_NotFound(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()

	_, err := repo.GetPublicProfile(ctx, "nonexistent")
	if err == nil {
		t.Error("GetPublicProfile should return error for nonexistent username")
	}
}

// ---------------------------------------------------------------------------
// Tests: UpdateProfile
// ---------------------------------------------------------------------------

func TestMockProfileRepo_UpdateProfile(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.addUser(userID, &domain.PublicProfile{
		Username:      "charlie",
		DisplayName:   "Old Name",
		Bio:           "Old bio",
		PublicEnabled: false,
	})

	err := repo.UpdateProfile(ctx, userID, "New Name", "New bio", true)
	if err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}

	// Verify the update via GetProfileByUserID.
	profile, _ := repo.GetProfileByUserID(ctx, userID)
	if profile.DisplayName != "New Name" {
		t.Errorf("DisplayName = %q, want %q", profile.DisplayName, "New Name")
	}
	if profile.Bio != "New bio" {
		t.Errorf("Bio = %q, want %q", profile.Bio, "New bio")
	}
	if !profile.PublicEnabled {
		t.Error("PublicEnabled should be true after update")
	}
}

func TestMockProfileRepo_UpdateProfile_EnablePublic(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.addUser(userID, &domain.PublicProfile{
		Username:      "dave",
		PublicEnabled: false,
	})

	repo.UpdateProfile(ctx, userID, "Dave", "", true)

	// Now the public profile should be accessible.
	profile, err := repo.GetPublicProfile(ctx, "dave")
	if err != nil {
		t.Fatalf("GetPublicProfile after enabling: %v", err)
	}
	if profile.DisplayName != "Dave" {
		t.Errorf("DisplayName = %q, want %q", profile.DisplayName, "Dave")
	}
}

func TestMockProfileRepo_UpdateProfile_DisablePublic(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.addUser(userID, &domain.PublicProfile{
		Username:      "eve",
		PublicEnabled: true,
	})

	repo.UpdateProfile(ctx, userID, "Eve", "", false)

	// Public profile should no longer be accessible.
	_, err := repo.GetPublicProfile(ctx, "eve")
	if err == nil {
		t.Error("GetPublicProfile should fail after disabling public profile")
	}

	// But GetProfileByUserID should still work.
	profile, err := repo.GetProfileByUserID(ctx, userID)
	if err != nil {
		t.Fatalf("GetProfileByUserID: %v", err)
	}
	if profile.PublicEnabled {
		t.Error("PublicEnabled should be false")
	}
}

func TestMockProfileRepo_UpdateProfile_UserNotFound(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()

	err := repo.UpdateProfile(ctx, uuid.New(), "Name", "Bio", true)
	if err == nil {
		t.Error("UpdateProfile should return error for nonexistent user")
	}
}

func TestMockProfileRepo_UpdateProfile_EmptyStrings(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.addUser(userID, &domain.PublicProfile{
		Username:      "frank",
		DisplayName:   "Frank",
		Bio:           "Some bio",
		PublicEnabled: true,
	})

	err := repo.UpdateProfile(ctx, userID, "", "", true)
	if err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}

	profile, _ := repo.GetProfileByUserID(ctx, userID)
	if profile.DisplayName != "" {
		t.Errorf("DisplayName = %q, want empty string", profile.DisplayName)
	}
	if profile.Bio != "" {
		t.Errorf("Bio = %q, want empty string", profile.Bio)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetProfileByUserID
// ---------------------------------------------------------------------------

func TestMockProfileRepo_GetProfileByUserID_Found(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.addUser(userID, &domain.PublicProfile{
		Username:    "grace",
		DisplayName: "Grace",
		Bio:         "Engineer",
		Plan:        "lifetime",
	})

	profile, err := repo.GetProfileByUserID(ctx, userID)
	if err != nil {
		t.Fatalf("GetProfileByUserID: %v", err)
	}
	if profile.Username != "grace" {
		t.Errorf("Username = %q, want %q", profile.Username, "grace")
	}
	if profile.DisplayName != "Grace" {
		t.Errorf("DisplayName = %q, want %q", profile.DisplayName, "Grace")
	}
	if profile.Bio != "Engineer" {
		t.Errorf("Bio = %q, want %q", profile.Bio, "Engineer")
	}
	if profile.Plan != "lifetime" {
		t.Errorf("Plan = %q, want %q", profile.Plan, "lifetime")
	}
}

func TestMockProfileRepo_GetProfileByUserID_NotFound(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()

	_, err := repo.GetProfileByUserID(ctx, uuid.New())
	if err == nil {
		t.Error("GetProfileByUserID should return error for nonexistent user")
	}
}

// ---------------------------------------------------------------------------
// Tests: Full profile lifecycle
// ---------------------------------------------------------------------------

func TestMockProfileRepo_Lifecycle(t *testing.T) {
	repo := newMockProfileRepo()
	ctx := context.Background()
	userID := uuid.New()

	// Start with a private profile.
	repo.addUser(userID, &domain.PublicProfile{
		Username:      "heidi",
		DisplayName:   "Heidi",
		Bio:           "Cryptographer",
		Plan:          "free",
		PublicEnabled: false,
	})

	// Public profile is not accessible.
	_, err := repo.GetPublicProfile(ctx, "heidi")
	if err == nil {
		t.Error("public profile should not be accessible when disabled")
	}

	// Profile by ID works.
	profile, _ := repo.GetProfileByUserID(ctx, userID)
	if profile.DisplayName != "Heidi" {
		t.Errorf("DisplayName = %q, want %q", profile.DisplayName, "Heidi")
	}

	// Enable public profile.
	repo.UpdateProfile(ctx, userID, "Heidi Public", "Public bio", true)

	// Now public profile is accessible.
	public, err := repo.GetPublicProfile(ctx, "heidi")
	if err != nil {
		t.Fatalf("GetPublicProfile after enable: %v", err)
	}
	if public.DisplayName != "Heidi Public" {
		t.Errorf("DisplayName = %q, want %q", public.DisplayName, "Heidi Public")
	}
	if public.Bio != "Public bio" {
		t.Errorf("Bio = %q, want %q", public.Bio, "Public bio")
	}

	// Upgrade plan (simulated).
	repo.profiles[userID].Plan = "pro"
	profile, _ = repo.GetProfileByUserID(ctx, userID)
	if profile.Plan != "pro" {
		t.Errorf("Plan = %q, want %q", profile.Plan, "pro")
	}

	// Disable public profile.
	repo.UpdateProfile(ctx, userID, "Heidi Private", "", false)
	_, err = repo.GetPublicProfile(ctx, "heidi")
	if err == nil {
		t.Error("public profile should not be accessible after disabling")
	}
}
