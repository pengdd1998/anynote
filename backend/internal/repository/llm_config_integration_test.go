//go:build integration

package repository

import (
	"context"
	"crypto/rand"
	"fmt"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/testutil"
)

// testMasterKey is a fixed 32-byte AES key used for integration test encryption.
// Generated once and reused across tests for determinism.
var testMasterKey = mustGenerateTestKey()

func mustGenerateTestKey() []byte {
	key := make([]byte, 32)
	// Use a deterministic key for tests so results are repeatable.
	// In production, this comes from config/environment.
	copy(key, []byte("test-master-key-32-bytes-padding!"))
	return key
}

// llmConfigTestRepo returns an LLMConfigRepository backed by the shared
// integration pool. It truncates dependent tables before each test.
func llmConfigTestRepo(t *testing.T) *LLMConfigRepository {
	t.Helper()
	pool := ensurePool(t)
	testutil.CleanTable(t, pool, "llm_configs", "users")
	return NewLLMConfigRepository(pool)
}

// seedLLMUser creates a test user and returns the UUID.
func seedLLMUser(t *testing.T) uuid.UUID {
	t.Helper()
	pool := ensurePool(t)
	id := uuid.New()
	email := fmt.Sprintf("llm-%s@example.com", id.String()[:8])
	username := fmt.Sprintf("llmuser_%s", id.String()[:8])
	testutil.SeedUser(t, pool, id.String(), email, username)
	return id
}

// makeTestLLMConfig creates a domain.LLMConfig with an encrypted API key.
func makeTestLLMConfig(userID uuid.UUID, name, apiKey string, isDefault bool) (*domain.LLMConfig, error) {
	encryptedKey, err := llm.EncryptAPIKey(apiKey, testMasterKey)
	if err != nil {
		return nil, fmt.Errorf("encrypt api key: %w", err)
	}
	return &domain.LLMConfig{
		ID:           uuid.New(),
		UserID:       userID,
		Name:         name,
		Provider:     "openai",
		BaseURL:      "https://api.openai.com/v1",
		EncryptedKey: encryptedKey,
		DecryptedKey: apiKey,
		Model:        "gpt-4o",
		IsDefault:    isDefault,
		MaxTokens:    4096,
		Temperature:  0.7,
	}, nil
}

// ---------------------------------------------------------------------------
// Tests: Create + GetByID
// ---------------------------------------------------------------------------

func TestLLMConfig_CreateAndGet(t *testing.T) {
	repo := llmConfigTestRepo(t)
	ctx := context.Background()
	userID := seedLLMUser(t)

	cfg, err := makeTestLLMConfig(userID, "My GPT Config", "sk-test-api-key-12345", false)
	if err != nil {
		t.Fatalf("makeTestLLMConfig: %v", err)
	}

	// Create config.
	if err := repo.Create(ctx, cfg); err != nil {
		t.Fatalf("Create: %v", err)
	}

	// Fetch by ID.
	got, err := repo.GetByID(ctx, cfg.ID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}

	if got.ID != cfg.ID {
		t.Errorf("ID = %v, want %v", got.ID, cfg.ID)
	}
	if got.UserID != cfg.UserID {
		t.Errorf("UserID = %v, want %v", got.UserID, cfg.UserID)
	}
	if got.Name != cfg.Name {
		t.Errorf("Name = %q, want %q", got.Name, cfg.Name)
	}
	if got.Provider != cfg.Provider {
		t.Errorf("Provider = %q, want %q", got.Provider, cfg.Provider)
	}
	if got.BaseURL != cfg.BaseURL {
		t.Errorf("BaseURL = %q, want %q", got.BaseURL, cfg.BaseURL)
	}
	if got.Model != cfg.Model {
		t.Errorf("Model = %q, want %q", got.Model, cfg.Model)
	}
	if got.IsDefault != cfg.IsDefault {
		t.Errorf("IsDefault = %v, want %v", got.IsDefault, cfg.IsDefault)
	}
	if got.MaxTokens != cfg.MaxTokens {
		t.Errorf("MaxTokens = %d, want %d", got.MaxTokens, cfg.MaxTokens)
	}
	if got.Temperature != cfg.Temperature {
		t.Errorf("Temperature = %f, want %f", got.Temperature, cfg.Temperature)
	}
	if got.CreatedAt.IsZero() {
		t.Error("CreatedAt should not be zero")
	}

	// Verify the encrypted key can be decrypted back to the original API key.
	decrypted, err := llm.DecryptAPIKey(got.EncryptedKey, testMasterKey)
	if err != nil {
		t.Fatalf("DecryptAPIKey: %v", err)
	}
	if decrypted != "sk-test-api-key-12345" {
		t.Errorf("decrypted API key = %q, want %q", decrypted, "sk-test-api-key-12345")
	}
}

// ---------------------------------------------------------------------------
// Tests: Encryption round-trip
// ---------------------------------------------------------------------------

func TestLLMConfig_EncryptedKeyRoundTrip(t *testing.T) {
	repo := llmConfigTestRepo(t)
	ctx := context.Background()
	userID := seedLLMUser(t)

	// Use a variety of API key formats to ensure robustness.
	testKeys := []string{
		"sk-simple-key",
		"sk-proj-abcdefghijklmnopqrstuvwxyz0123456789ABCDEF",
		"key-with-special-chars!@#$%^&*()_+-=[]{}|;':\",./<>?",
		"", // empty key (edge case)
	}

	for i, apiKey := range testKeys {
		cfg, err := makeTestLLMConfig(userID, fmt.Sprintf("config-%d", i), apiKey, false)
		if err != nil {
			t.Fatalf("[%d] makeTestLLMConfig: %v", i, err)
		}

		if err := repo.Create(ctx, cfg); err != nil {
			t.Fatalf("[%d] Create: %v", i, err)
		}

		got, err := repo.GetByID(ctx, cfg.ID)
		if err != nil {
			t.Fatalf("[%d] GetByID: %v", i, err)
		}

		decrypted, err := llm.DecryptAPIKey(got.EncryptedKey, testMasterKey)
		if err != nil {
			t.Fatalf("[%d] DecryptAPIKey: %v", i, err)
		}
		if decrypted != apiKey {
			t.Errorf("[%d] round-trip failed: got %q, want %q", i, decrypted, apiKey)
		}
	}
}

// ---------------------------------------------------------------------------
// Tests: SetDefault (via Update)
// ---------------------------------------------------------------------------

func TestLLMConfig_SetDefault(t *testing.T) {
	repo := llmConfigTestRepo(t)
	ctx := context.Background()
	userID := seedLLMUser(t)

	cfg1, err := makeTestLLMConfig(userID, "Config One", "sk-key-one", true)
	if err != nil {
		t.Fatalf("makeTestLLMConfig cfg1: %v", err)
	}
	cfg2, err := makeTestLLMConfig(userID, "Config Two", "sk-key-two", false)
	if err != nil {
		t.Fatalf("makeTestLLMConfig cfg2: %v", err)
	}

	if err := repo.Create(ctx, cfg1); err != nil {
		t.Fatalf("Create cfg1: %v", err)
	}
	if err := repo.Create(ctx, cfg2); err != nil {
		t.Fatalf("Create cfg2: %v", err)
	}

	// cfg1 is default. Set cfg2 as default instead.
	cfg1.IsDefault = false
	if err := repo.Update(ctx, cfg1); err != nil {
		t.Fatalf("Update cfg1 (unset default): %v", err)
	}
	cfg2.IsDefault = true
	if err := repo.Update(ctx, cfg2); err != nil {
		t.Fatalf("Update cfg2 (set default): %v", err)
	}

	// Verify only cfg2 is default via GetDefaultByUser.
	def, err := repo.GetDefaultByUser(ctx, userID)
	if err != nil {
		t.Fatalf("GetDefaultByUser: %v", err)
	}
	if def.ID != cfg2.ID {
		t.Errorf("default config ID = %v, want %v", def.ID, cfg2.ID)
	}

	// Double-check cfg1 is no longer default.
	got1, err := repo.GetByID(ctx, cfg1.ID)
	if err != nil {
		t.Fatalf("GetByID cfg1: %v", err)
	}
	if got1.IsDefault {
		t.Error("cfg1 should no longer be default")
	}
}

// ---------------------------------------------------------------------------
// Tests: Delete
// ---------------------------------------------------------------------------

func TestLLMConfig_Delete(t *testing.T) {
	repo := llmConfigTestRepo(t)
	ctx := context.Background()
	userID := seedLLMUser(t)

	cfg, err := makeTestLLMConfig(userID, "To Delete", "sk-delete-me", false)
	if err != nil {
		t.Fatalf("makeTestLLMConfig: %v", err)
	}

	if err := repo.Create(ctx, cfg); err != nil {
		t.Fatalf("Create: %v", err)
	}

	// Delete the config.
	if err := repo.Delete(ctx, cfg.ID, cfg.UserID); err != nil {
		t.Fatalf("Delete: %v", err)
	}

	// Verify it is gone.
	_, err = repo.GetByID(ctx, cfg.ID)
	if err == nil {
		t.Error("expected error when fetching deleted config, got nil")
	}
}

// ---------------------------------------------------------------------------
// Tests: ListByUser
// ---------------------------------------------------------------------------

func TestLLMConfig_ListByUser(t *testing.T) {
	repo := llmConfigTestRepo(t)
	ctx := context.Background()
	userID := seedLLMUser(t)

	// Create 3 configs for the same user.
	var cfgIDs []uuid.UUID
	for i := 0; i < 3; i++ {
		cfg, err := makeTestLLMConfig(userID, fmt.Sprintf("Config %d", i), fmt.Sprintf("sk-key-%d", i), i == 0)
		if err != nil {
			t.Fatalf("makeTestLLMConfig[%d]: %v", i, err)
		}
		if err := repo.Create(ctx, cfg); err != nil {
			t.Fatalf("Create[%d]: %v", i, err)
		}
		cfgIDs = append(cfgIDs, cfg.ID)
	}

	// List all configs for this user.
	configs, err := repo.ListByUser(ctx, userID)
	if err != nil {
		t.Fatalf("ListByUser: %v", err)
	}

	if len(configs) != 3 {
		t.Fatalf("len(configs) = %d, want 3", len(configs))
	}

	// Verify all IDs are present.
	found := map[uuid.UUID]bool{}
	for _, c := range configs {
		found[c.ID] = true
	}
	for _, id := range cfgIDs {
		if !found[id] {
			t.Errorf("config ID %v not found in ListByUser results", id)
		}
	}

	// Verify results are ordered by created_at DESC (most recent first).
	for i := 1; i < len(configs); i++ {
		if configs[i].CreatedAt.After(configs[i-1].CreatedAt) {
			t.Errorf("configs[%d].CreatedAt (%v) after configs[%d].CreatedAt (%v), want DESC order",
				i, configs[i].CreatedAt, i-1, configs[i-1].CreatedAt)
		}
	}
}

func init() {
	// Ensure rand is seeded for any random operations in tests.
	// The testMasterKey is deterministic, but encryption uses random nonces.
	_ = rand.Reader
}
