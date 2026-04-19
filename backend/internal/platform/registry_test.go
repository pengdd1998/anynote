package platform

import (
	"context"
	"testing"
)

// ---------------------------------------------------------------------------
// Mock Adapter
// ---------------------------------------------------------------------------

type mockAdapter struct {
	name string
}

func (m *mockAdapter) Name() string { return m.name }

func (m *mockAdapter) StartAuth(ctx context.Context, masterKey []byte) (*AuthSession, []byte, error) {
	return nil, nil, nil
}

func (m *mockAdapter) PollAuth(ctx context.Context, session *AuthSession, masterKey []byte) ([]byte, error) {
	return nil, nil
}

func (m *mockAdapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params PublishParams) (*PublishResult, error) {
	return nil, nil
}

func (m *mockAdapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	return "", nil
}

func (m *mockAdapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	return nil
}

// ---------------------------------------------------------------------------
// Tests: NewRegistry
// ---------------------------------------------------------------------------

func TestNewRegistry(t *testing.T) {
	r := NewRegistry()
	if r == nil {
		t.Fatal("NewRegistry returned nil")
	}
	if r.adapters == nil {
		t.Error("adapters map should be initialized")
	}
}

// ---------------------------------------------------------------------------
// Tests: Register + Get
// ---------------------------------------------------------------------------

func TestRegistry_RegisterAndGet(t *testing.T) {
	r := NewRegistry()
	adapter := &mockAdapter{name: "test-platform"}
	r.Register("test-platform", adapter)

	got, err := r.Get("test-platform")
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if got.Name() != "test-platform" {
		t.Errorf("Name() = %q, want %q", got.Name(), "test-platform")
	}
}

func TestRegistry_Get_NotFound(t *testing.T) {
	r := NewRegistry()

	_, err := r.Get("nonexistent")
	if err == nil {
		t.Error("expected error for unregistered platform")
	}
}

// ---------------------------------------------------------------------------
// Tests: List
// ---------------------------------------------------------------------------

func TestRegistry_List_Empty(t *testing.T) {
	r := NewRegistry()
	names := r.List()
	if len(names) != 0 {
		t.Errorf("List() = %v, want empty slice", names)
	}
}

func TestRegistry_List_Multiple(t *testing.T) {
	r := NewRegistry()
	r.Register("xiaohongshu", &mockAdapter{name: "xiaohongshu"})
	r.Register("medium", &mockAdapter{name: "medium"})
	r.Register("wordpress", &mockAdapter{name: "wordpress"})

	names := r.List()
	if len(names) != 3 {
		t.Fatalf("List() count = %d, want 3", len(names))
	}

	// Convert to set for order-independent check.
	nameSet := make(map[string]bool)
	for _, n := range names {
		nameSet[n] = true
	}
	for _, expected := range []string{"xiaohongshu", "medium", "wordpress"} {
		if !nameSet[expected] {
			t.Errorf("expected %q in List() results", expected)
		}
	}
}

// ---------------------------------------------------------------------------
// Tests: Register overwrites
// ---------------------------------------------------------------------------

func TestRegistry_Register_Overwrite(t *testing.T) {
	r := NewRegistry()
	r.Register("test", &mockAdapter{name: "first"})
	r.Register("test", &mockAdapter{name: "second"})

	got, err := r.Get("test")
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if got.Name() != "second" {
		t.Errorf("Name() = %q, want %q (should be overwritten)", got.Name(), "second")
	}
}
