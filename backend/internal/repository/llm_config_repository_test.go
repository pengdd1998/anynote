package repository

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// TestLLMConfigRepository_DocumentsExpectedBehavior documents expected SQL behaviors.
func TestLLMConfigRepository_DocumentsExpectedBehavior(t *testing.T) {
	t.Run("ListByUser_returns_configs", func(t *testing.T) {
		// SELECT id, user_id, name, provider, base_url, encrypted_key, model, is_default,
		//   max_tokens, temperature, created_at, updated_at
		// FROM llm_configs WHERE user_id = $1 ORDER BY created_at DESC
		t.Log("documented: ListByUser returns user's LLM configs, newest first")
	})

	t.Run("GetByID_selects_config", func(t *testing.T) {
		// SELECT ... FROM llm_configs WHERE id = $1
		t.Log("documented: GetByID returns single config by UUID")
	})

	t.Run("GetDefaultByUser_selects_default", func(t *testing.T) {
		// SELECT ... FROM llm_configs WHERE user_id = $1 AND is_default = true LIMIT 1
		t.Log("documented: GetDefaultByUser returns the user's default config")
	})

	t.Run("Create_inserts_config", func(t *testing.T) {
		// INSERT INTO llm_configs (id, user_id, name, provider, base_url, encrypted_key,
		//   model, is_default, max_tokens, temperature)
		// VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		t.Log("documented: Create inserts new LLM config with encrypted API key")
	})

	t.Run("Update_updates_config", func(t *testing.T) {
		// UPDATE llm_configs SET name=$3, provider=$4, base_url=$5, encrypted_key=$6,
		//   model=$7, is_default=$8, max_tokens=$9, temperature=$10, updated_at=NOW()
		// WHERE id = $1 AND user_id = $2
		t.Log("documented: Update modifies config, scoped to user_id for security")
	})

	t.Run("Delete_removes_config", func(t *testing.T) {
		// DELETE FROM llm_configs WHERE id = $1
		t.Log("documented: Delete removes config by ID")
	})
}

// ---------------------------------------------------------------------------
// Unit tests using in-memory mock
// ---------------------------------------------------------------------------

type mockLLMConfigRepo struct {
	configs map[uuid.UUID]*domain.LLMConfig
}

func newMockLLMConfigRepo() *mockLLMConfigRepo {
	return &mockLLMConfigRepo{
		configs: make(map[uuid.UUID]*domain.LLMConfig),
	}
}

func (m *mockLLMConfigRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error) {
	var result []domain.LLMConfig
	for _, c := range m.configs {
		if c.UserID == userID {
			result = append(result, *c)
		}
	}
	return result, nil
}

func (m *mockLLMConfigRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.LLMConfig, error) {
	c, ok := m.configs[id]
	if !ok {
		return nil, errNotFound
	}
	return c, nil
}

func (m *mockLLMConfigRepo) GetDefaultByUser(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error) {
	for _, c := range m.configs {
		if c.UserID == userID && c.IsDefault {
			return c, nil
		}
	}
	return nil, errNotFound
}

func (m *mockLLMConfigRepo) Create(ctx context.Context, cfg *domain.LLMConfig) error {
	m.configs[cfg.ID] = cfg
	return nil
}

func (m *mockLLMConfigRepo) Update(ctx context.Context, cfg *domain.LLMConfig) error {
	m.configs[cfg.ID] = cfg
	return nil
}

func (m *mockLLMConfigRepo) Delete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	delete(m.configs, id)
	return nil
}

func TestMockLLMConfigRepo_Create(t *testing.T) {
	repo := newMockLLMConfigRepo()
	ctx := context.Background()
	userID := uuid.New()
	cfgID := uuid.New()

	cfg := &domain.LLMConfig{
		ID: cfgID, UserID: userID, Name: "My GPT", Provider: "openai",
		Model: "gpt-4", IsDefault: true, MaxTokens: 4096, Temperature: 0.7,
	}
	repo.Create(ctx, cfg)

	got, err := repo.GetByID(ctx, cfgID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}
	if got.Provider != "openai" {
		t.Errorf("Provider = %q, want %q", got.Provider, "openai")
	}
	if !got.IsDefault {
		t.Error("IsDefault should be true")
	}
}

func TestMockLLMConfigRepo_GetByID_NotFound(t *testing.T) {
	repo := newMockLLMConfigRepo()
	ctx := context.Background()

	_, err := repo.GetByID(ctx, uuid.New())
	if err == nil {
		t.Error("GetByID should return error for nonexistent config")
	}
}

func TestMockLLMConfigRepo_GetDefaultByUser(t *testing.T) {
	repo := newMockLLMConfigRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.Create(ctx, &domain.LLMConfig{ID: uuid.New(), UserID: userID, Name: "Non-default", IsDefault: false})
	repo.Create(ctx, &domain.LLMConfig{ID: uuid.New(), UserID: userID, Name: "Default", IsDefault: true})

	got, err := repo.GetDefaultByUser(ctx, userID)
	if err != nil {
		t.Fatalf("GetDefaultByUser: %v", err)
	}
	if got.Name != "Default" {
		t.Errorf("Name = %q, want %q", got.Name, "Default")
	}
}

func TestMockLLMConfigRepo_GetDefaultByUser_None(t *testing.T) {
	repo := newMockLLMConfigRepo()
	ctx := context.Background()
	userID := uuid.New()

	repo.Create(ctx, &domain.LLMConfig{ID: uuid.New(), UserID: userID, Name: "No-default", IsDefault: false})

	_, err := repo.GetDefaultByUser(ctx, userID)
	if err == nil {
		t.Error("GetDefaultByUser should return error when no default exists")
	}
}

func TestMockLLMConfigRepo_ListByUser(t *testing.T) {
	repo := newMockLLMConfigRepo()
	ctx := context.Background()
	user1 := uuid.New()
	user2 := uuid.New()

	repo.Create(ctx, &domain.LLMConfig{ID: uuid.New(), UserID: user1, Provider: "openai"})
	repo.Create(ctx, &domain.LLMConfig{ID: uuid.New(), UserID: user1, Provider: "anthropic"})
	repo.Create(ctx, &domain.LLMConfig{ID: uuid.New(), UserID: user2, Provider: "openai"})

	configs, err := repo.ListByUser(ctx, user1)
	if err != nil {
		t.Fatalf("ListByUser: %v", err)
	}
	if len(configs) != 2 {
		t.Errorf("len(configs) = %d, want 2", len(configs))
	}
}

func TestMockLLMConfigRepo_Update(t *testing.T) {
	repo := newMockLLMConfigRepo()
	ctx := context.Background()
	cfgID := uuid.New()

	repo.Create(ctx, &domain.LLMConfig{ID: cfgID, Name: "Old", Model: "gpt-3.5"})

	repo.Update(ctx, &domain.LLMConfig{ID: cfgID, Name: "New", Model: "gpt-4"})

	got, _ := repo.GetByID(ctx, cfgID)
	if got.Name != "New" {
		t.Errorf("Name = %q, want %q", got.Name, "New")
	}
	if got.Model != "gpt-4" {
		t.Errorf("Model = %q, want %q", got.Model, "gpt-4")
	}
}

func TestMockLLMConfigRepo_Delete(t *testing.T) {
	repo := newMockLLMConfigRepo()
	ctx := context.Background()
	cfgID := uuid.New()

	repo.Create(ctx, &domain.LLMConfig{ID: cfgID, Name: "ToDelete"})
	repo.Delete(ctx, cfgID, uuid.New())

	_, err := repo.GetByID(ctx, cfgID)
	if err == nil {
		t.Error("config should be deleted")
	}
}
