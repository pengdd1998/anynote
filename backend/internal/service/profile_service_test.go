package service

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock ProfileRepo
// ---------------------------------------------------------------------------

type mockProfileRepo struct {
	getPublicFn  func(ctx context.Context, username string) (*domain.PublicProfile, error)
	updateFn     func(ctx context.Context, userID uuid.UUID, displayName string, bio string, publicEnabled bool) error
	getByUserFn  func(ctx context.Context, userID uuid.UUID) (*domain.PublicProfile, error)
}

func (m *mockProfileRepo) GetPublicProfile(ctx context.Context, username string) (*domain.PublicProfile, error) {
	if m.getPublicFn != nil {
		return m.getPublicFn(ctx, username)
	}
	return nil, nil
}

func (m *mockProfileRepo) UpdateProfile(ctx context.Context, userID uuid.UUID, displayName string, bio string, publicEnabled bool) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, userID, displayName, bio, publicEnabled)
	}
	return nil
}

func (m *mockProfileRepo) GetProfileByUserID(ctx context.Context, userID uuid.UUID) (*domain.PublicProfile, error) {
	if m.getByUserFn != nil {
		return m.getByUserFn(ctx, userID)
	}
	return nil, nil
}

// ---------------------------------------------------------------------------
// Tests: GetPublicProfile
// ---------------------------------------------------------------------------

func TestProfileService_GetPublicProfile_Success(t *testing.T) {
	repo := &mockProfileRepo{
		getPublicFn: func(_ context.Context, username string) (*domain.PublicProfile, error) {
			if username != "alice" {
				t.Errorf("username = %q, want %q", username, "alice")
			}
			return &domain.PublicProfile{
				Username:      "alice",
				DisplayName:   "Alice",
				Bio:           "Hello world",
				Plan:          "pro",
				PublicEnabled: true,
			}, nil
		},
	}

	svc := NewProfileService(repo)
	profile, err := svc.GetPublicProfile(context.Background(), "alice")
	if err != nil {
		t.Fatalf("GetPublicProfile: %v", err)
	}
	if profile.Username != "alice" {
		t.Errorf("Username = %q, want %q", profile.Username, "alice")
	}
	if profile.DisplayName != "Alice" {
		t.Errorf("DisplayName = %q, want %q", profile.DisplayName, "Alice")
	}
	if profile.Bio != "Hello world" {
		t.Errorf("Bio = %q, want %q", profile.Bio, "Hello world")
	}
	if profile.Plan != "pro" {
		t.Errorf("Plan = %q, want %q", profile.Plan, "pro")
	}
	if !profile.PublicEnabled {
		t.Error("PublicEnabled = false, want true")
	}
}

func TestProfileService_GetPublicProfile_NotFound(t *testing.T) {
	repo := &mockProfileRepo{
		getPublicFn: func(_ context.Context, _ string) (*domain.PublicProfile, error) {
			return nil, errors.New("not found")
		},
	}

	svc := NewProfileService(repo)
	_, err := svc.GetPublicProfile(context.Background(), "nonexistent")
	if !errors.Is(err, ErrProfileNotFound) {
		t.Errorf("GetPublicProfile error = %v, want ErrProfileNotFound", err)
	}
}

func TestProfileService_GetPublicProfile_DBError(t *testing.T) {
	repo := &mockProfileRepo{
		getPublicFn: func(_ context.Context, _ string) (*domain.PublicProfile, error) {
			return nil, errors.New("connection refused")
		},
	}

	svc := NewProfileService(repo)
	_, err := svc.GetPublicProfile(context.Background(), "alice")
	if !errors.Is(err, ErrProfileNotFound) {
		t.Errorf("GetPublicProfile error = %v, want ErrProfileNotFound (wrapped)", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: UpdateProfile
// ---------------------------------------------------------------------------

func TestProfileService_UpdateProfile_Success(t *testing.T) {
	userID := uuid.New()
	var capturedDisplayName, capturedBio string
	var capturedPublic bool

	repo := &mockProfileRepo{
		updateFn: func(_ context.Context, uid uuid.UUID, displayName string, bio string, publicEnabled bool) error {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			capturedDisplayName = displayName
			capturedBio = bio
			capturedPublic = publicEnabled
			return nil
		},
	}

	svc := NewProfileService(repo)
	err := svc.UpdateProfile(context.Background(), userID, "Bob", "New bio", true)
	if err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}
	if capturedDisplayName != "Bob" {
		t.Errorf("displayName = %q, want %q", capturedDisplayName, "Bob")
	}
	if capturedBio != "New bio" {
		t.Errorf("bio = %q, want %q", capturedBio, "New bio")
	}
	if !capturedPublic {
		t.Error("publicEnabled = false, want true")
	}
}

func TestProfileService_UpdateProfile_DisablePublic(t *testing.T) {
	userID := uuid.New()
	var capturedPublic bool

	repo := &mockProfileRepo{
		updateFn: func(_ context.Context, _ uuid.UUID, _ string, _ string, publicEnabled bool) error {
			capturedPublic = publicEnabled
			return nil
		},
	}

	svc := NewProfileService(repo)
	err := svc.UpdateProfile(context.Background(), userID, "Alice", "", false)
	if err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}
	if capturedPublic {
		t.Error("publicEnabled = true, want false")
	}
}

func TestProfileService_UpdateProfile_RepoError(t *testing.T) {
	repo := &mockProfileRepo{
		updateFn: func(_ context.Context, _ uuid.UUID, _ string, _ string, _ bool) error {
			return errors.New("write failed")
		},
	}

	svc := NewProfileService(repo)
	err := svc.UpdateProfile(context.Background(), uuid.New(), "name", "bio", true)
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

func TestProfileService_UpdateProfile_EmptyFields(t *testing.T) {
	userID := uuid.New()
	var capturedDisplayName, capturedBio string

	repo := &mockProfileRepo{
		updateFn: func(_ context.Context, _ uuid.UUID, displayName string, bio string, _ bool) error {
			capturedDisplayName = displayName
			capturedBio = bio
			return nil
		},
	}

	svc := NewProfileService(repo)
	err := svc.UpdateProfile(context.Background(), userID, "", "", true)
	if err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}
	if capturedDisplayName != "" {
		t.Errorf("displayName = %q, want empty", capturedDisplayName)
	}
	if capturedBio != "" {
		t.Errorf("bio = %q, want empty", capturedBio)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetOwnProfile
// ---------------------------------------------------------------------------

func TestProfileService_GetOwnProfile_Success(t *testing.T) {
	userID := uuid.New()

	repo := &mockProfileRepo{
		getByUserFn: func(_ context.Context, uid uuid.UUID) (*domain.PublicProfile, error) {
			if uid != userID {
				t.Errorf("userID = %v, want %v", uid, userID)
			}
			return &domain.PublicProfile{
				Username:      "alice",
				DisplayName:   "Alice",
				Bio:           "My bio",
				Plan:          "free",
				PublicEnabled: false,
			}, nil
		},
	}

	svc := NewProfileService(repo)
	profile, err := svc.GetOwnProfile(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetOwnProfile: %v", err)
	}
	if profile.Username != "alice" {
		t.Errorf("Username = %q, want %q", profile.Username, "alice")
	}
	if profile.PublicEnabled {
		t.Error("PublicEnabled should be false")
	}
}

func TestProfileService_GetOwnProfile_NotFound(t *testing.T) {
	repo := &mockProfileRepo{
		getByUserFn: func(_ context.Context, _ uuid.UUID) (*domain.PublicProfile, error) {
			return nil, errors.New("no profile for user")
		},
	}

	svc := NewProfileService(repo)
	_, err := svc.GetOwnProfile(context.Background(), uuid.New())
	if err == nil {
		t.Error("expected error when user has no profile")
	}
}

func TestProfileService_GetOwnProfile_DBError(t *testing.T) {
	repo := &mockProfileRepo{
		getByUserFn: func(_ context.Context, _ uuid.UUID) (*domain.PublicProfile, error) {
			return nil, errors.New("connection refused")
		},
	}

	svc := NewProfileService(repo)
	_, err := svc.GetOwnProfile(context.Background(), uuid.New())
	if err == nil {
		t.Error("expected error when repo fails")
	}
}
