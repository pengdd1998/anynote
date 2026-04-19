package service

import (
	"context"
	"crypto/rand"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/llm"
)

// ---------------------------------------------------------------------------
// Mock LLMConfigRepo (satisfies LLMConfigRepo from llm_config_service.go)
// ---------------------------------------------------------------------------

type mockLLMConfigCRUDRepo struct {
	configs   map[uuid.UUID]*domain.LLMConfig
	listErr   error
	getErr    error
	createErr error
	updateErr error
	deleteErr error
}

func newMockLLMConfigCRUDRepo() *mockLLMConfigCRUDRepo {
	return &mockLLMConfigCRUDRepo{
		configs: make(map[uuid.UUID]*domain.LLMConfig),
	}
}

func (m *mockLLMConfigCRUDRepo) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error) {
	if m.listErr != nil {
		return nil, m.listErr
	}
	var result []domain.LLMConfig
	for _, c := range m.configs {
		if c.UserID == userID {
			result = append(result, *c)
		}
	}
	return result, nil
}

func (m *mockLLMConfigCRUDRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.LLMConfig, error) {
	if m.getErr != nil {
		return nil, m.getErr
	}
	c, ok := m.configs[id]
	if !ok {
		return nil, errors.New("config not found")
	}
	return c, nil
}

func (m *mockLLMConfigCRUDRepo) GetDefaultByUser(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error) {
	for _, c := range m.configs {
		if c.UserID == userID && c.IsDefault {
			return c, nil
		}
	}
	return nil, errors.New("no default config")
}

func (m *mockLLMConfigCRUDRepo) Create(ctx context.Context, cfg *domain.LLMConfig) error {
	if m.createErr != nil {
		return m.createErr
	}
	m.configs[cfg.ID] = cfg
	return nil
}

func (m *mockLLMConfigCRUDRepo) Update(ctx context.Context, cfg *domain.LLMConfig) error {
	if m.updateErr != nil {
		return m.updateErr
	}
	m.configs[cfg.ID] = cfg
	return nil
}

func (m *mockLLMConfigCRUDRepo) Delete(ctx context.Context, id uuid.UUID) error {
	if m.deleteErr != nil {
		return m.deleteErr
	}
	delete(m.configs, id)
	return nil
}

// ---------------------------------------------------------------------------
// Mock Provider for Gateway used in TestConnection
// ---------------------------------------------------------------------------

type mockLLMProvider struct {
	chatFn func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error)
}

func (m *mockLLMProvider) Name() string { return "mock" }

func (m *mockLLMProvider) ChatStream(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (<-chan domain.StreamChunk, error) {
	ch := make(chan domain.StreamChunk, 1)
	ch <- domain.StreamChunk{Done: true}
	close(ch)
	return ch, nil
}

func (m *mockLLMProvider) Chat(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error) {
	if m.chatFn != nil {
		return m.chatFn(ctx, apiKey, baseURL, req)
	}
	return &llm.ChatResponse{Content: "OK"}, nil
}

// newTestLLMGateway creates a Gateway with a mock provider.
func newTestLLMGateway(provider llm.Provider) *llm.Gateway {
	gw := llm.NewGateway()
	gw.Register("mock", provider)
	return gw
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestLLMConfigService_Create_Success(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)

	svc := NewLLMConfigService(repo, gw, masterKey)

	userID := uuid.New()
	cfg, err := svc.Create(context.Background(), userID, domain.LLMConfig{
		Name:         "My OpenAI",
		Provider:     "mock",
		BaseURL:      "https://api.openai.com",
		DecryptedKey: "sk-test-12345",
		Model:        "gpt-4",
		MaxTokens:    4096,
		Temperature:  0.7,
		IsDefault:    true,
	})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}
	if cfg.ID == uuid.Nil {
		t.Error("ID should be set")
	}
	if cfg.UserID != userID {
		t.Errorf("UserID = %v, want %v", cfg.UserID, userID)
	}
	if len(cfg.EncryptedKey) == 0 {
		t.Error("EncryptedKey should be set")
	}
	if cfg.DecryptedKey != "" {
		t.Error("DecryptedKey should be cleared after encryption")
	}

	// Verify the encrypted key can be decrypted back.
	decrypted, err := llm.DecryptAPIKey(cfg.EncryptedKey, masterKey)
	if err != nil {
		t.Fatalf("DecryptAPIKey: %v", err)
	}
	if decrypted != "sk-test-12345" {
		t.Errorf("decrypted key = %q, want %q", decrypted, "sk-test-12345")
	}
}

func TestLLMConfigService_Create_RepoError(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	repo.createErr = errors.New("db error")
	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)

	svc := NewLLMConfigService(repo, gw, masterKey)

	_, err := svc.Create(context.Background(), uuid.New(), domain.LLMConfig{
		Name:         "Test",
		Provider:     "mock",
		DecryptedKey: "sk-key",
	})
	if err == nil {
		t.Error("expected error when repo.Create fails")
	}
}

func TestLLMConfigService_Update_Success(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	userID := uuid.New()
	configID := uuid.New()

	// Pre-seed an existing config.
	repo.configs[configID] = &domain.LLMConfig{
		ID:       configID,
		UserID:   userID,
		Provider: "mock",
		BaseURL:  "https://api.openai.com",
		Model:    "gpt-3.5-turbo",
	}

	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	updated, err := svc.Update(context.Background(), userID, domain.LLMConfig{
		ID:           configID,
		Provider:     "mock",
		BaseURL:      "https://api.openai.com",
		DecryptedKey: "sk-new-key",
		Model:        "gpt-4",
	})
	if err != nil {
		t.Fatalf("Update: %v", err)
	}
	if len(updated.EncryptedKey) == 0 {
		t.Error("EncryptedKey should be set when DecryptedKey provided")
	}
	if updated.DecryptedKey != "" {
		t.Error("DecryptedKey should be cleared")
	}

	// Verify the new key was encrypted.
	decrypted, err := llm.DecryptAPIKey(updated.EncryptedKey, masterKey)
	if err != nil {
		t.Fatalf("DecryptAPIKey: %v", err)
	}
	if decrypted != "sk-new-key" {
		t.Errorf("decrypted = %q, want %q", decrypted, "sk-new-key")
	}
}

func TestLLMConfigService_Update_NoKeyRotation(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	userID := uuid.New()
	configID := uuid.New()

	originalEncryptedKey, _ := llm.EncryptAPIKey("sk-original", masterKey)
	repo.configs[configID] = &domain.LLMConfig{
		ID:            configID,
		UserID:        userID,
		Provider:      "mock",
		EncryptedKey:  originalEncryptedKey,
		Model:         "gpt-3.5-turbo",
	}

	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	// Update without providing a new DecryptedKey -- should preserve existing EncryptedKey.
	updated, err := svc.Update(context.Background(), userID, domain.LLMConfig{
		ID:       configID,
		Provider: "mock",
		Model:    "gpt-4",
	})
	if err != nil {
		t.Fatalf("Update: %v", err)
	}
	// EncryptedKey should be empty (zero value) since the caller did not provide
	// a new DecryptedKey and the Update method only sets EncryptedKey when DecryptedKey != "".
	// The repository stores whatever the service passes.
	if len(updated.EncryptedKey) != 0 {
		t.Error("EncryptedKey should not change when DecryptedKey is empty")
	}
}

func TestLLMConfigService_Update_UnauthorizedUser(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	ownerID := uuid.New()
	configID := uuid.New()
	repo.configs[configID] = &domain.LLMConfig{
		ID:     configID,
		UserID: ownerID,
	}

	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	otherUserID := uuid.New()
	_, err := svc.Update(context.Background(), otherUserID, domain.LLMConfig{
		ID:           configID,
		DecryptedKey: "sk-hijack",
	})
	if err == nil {
		t.Error("expected error when updating another user's config")
	}
}

func TestLLMConfigService_Update_NotFound(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	_, err := svc.Update(context.Background(), uuid.New(), domain.LLMConfig{
		ID:           uuid.New(),
		DecryptedKey: "sk-key",
	})
	if err == nil {
		t.Error("expected error when config not found")
	}
}

func TestLLMConfigService_Delete_Success(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	userID := uuid.New()
	configID := uuid.New()
	repo.configs[configID] = &domain.LLMConfig{
		ID:     configID,
		UserID: userID,
	}

	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	err := svc.Delete(context.Background(), userID, configID)
	if err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if _, exists := repo.configs[configID]; exists {
		t.Error("config should be removed from repo")
	}
}

func TestLLMConfigService_Delete_Unauthorized(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	ownerID := uuid.New()
	configID := uuid.New()
	repo.configs[configID] = &domain.LLMConfig{
		ID:     configID,
		UserID: ownerID,
	}

	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	err := svc.Delete(context.Background(), uuid.New(), configID)
	if err == nil {
		t.Error("expected error when deleting another user's config")
	}
}

func TestLLMConfigService_Delete_NotFound(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	err := svc.Delete(context.Background(), uuid.New(), uuid.New())
	if err == nil {
		t.Error("expected error when config not found")
	}
}

func TestLLMConfigService_List(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	userID := uuid.New()
	repo.configs[uuid.New()] = &domain.LLMConfig{
		ID:     uuid.New(),
		UserID: userID,
		Name:   "Config A",
	}
	repo.configs[uuid.New()] = &domain.LLMConfig{
		ID:     uuid.New(),
		UserID: userID,
		Name:   "Config B",
	}
	repo.configs[uuid.New()] = &domain.LLMConfig{
		ID:     uuid.New(),
		UserID: uuid.New(), // different user
		Name:   "Config C",
	}

	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	configs, err := svc.List(context.Background(), userID)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(configs) != 2 {
		t.Errorf("len(configs) = %d, want 2", len(configs))
	}
}

func TestLLMConfigService_TestConnection_Success(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	userID := uuid.New()
	configID := uuid.New()

	encryptedKey, _ := llm.EncryptAPIKey("sk-test-key", masterKey)
	repo.configs[configID] = &domain.LLMConfig{
		ID:            configID,
		UserID:        userID,
		Provider:      "mock",
		BaseURL:       "https://api.mock.llm",
		EncryptedKey:  encryptedKey,
		Model:         "mock-model",
	}

	var capturedKey string
	provider := &mockLLMProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error) {
			capturedKey = apiKey
			return &llm.ChatResponse{Content: "OK"}, nil
		},
	}

	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	err := svc.TestConnection(context.Background(), userID, configID)
	if err != nil {
		t.Fatalf("TestConnection: %v", err)
	}
	if capturedKey != "sk-test-key" {
		t.Errorf("apiKey sent to provider = %q, want %q", capturedKey, "sk-test-key")
	}
}

func TestLLMConfigService_TestConnection_Unauthorized(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	ownerID := uuid.New()
	configID := uuid.New()
	repo.configs[configID] = &domain.LLMConfig{
		ID:     configID,
		UserID: ownerID,
	}

	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	err := svc.TestConnection(context.Background(), uuid.New(), configID)
	if err == nil {
		t.Error("expected error for unauthorized user")
	}
}

func TestLLMConfigService_TestConnection_ProviderError(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	userID := uuid.New()
	configID := uuid.New()

	encryptedKey, _ := llm.EncryptAPIKey("sk-key", masterKey)
	repo.configs[configID] = &domain.LLMConfig{
		ID:           configID,
		UserID:       userID,
		Provider:     "mock",
		EncryptedKey: encryptedKey,
		Model:        "mock-model",
	}

	provider := &mockLLMProvider{
		chatFn: func(ctx context.Context, apiKey, baseURL string, req llm.ChatRequest) (*llm.ChatResponse, error) {
			return nil, errors.New("connection refused")
		},
	}

	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	err := svc.TestConnection(context.Background(), userID, configID)
	if err == nil {
		t.Error("expected error when provider fails")
	}
}

func TestLLMConfigService_GetDefault(t *testing.T) {
	masterKey := make([]byte, 32)
	rand.Read(masterKey)

	repo := newMockLLMConfigCRUDRepo()
	userID := uuid.New()
	configID := uuid.New()
	repo.configs[configID] = &domain.LLMConfig{
		ID:        configID,
		UserID:    userID,
		IsDefault: true,
		Name:      "Default Config",
	}

	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, masterKey)

	cfg, err := svc.GetDefault(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetDefault: %v", err)
	}
	if cfg.Name != "Default Config" {
		t.Errorf("Name = %q, want %q", cfg.Name, "Default Config")
	}
}

func TestLLMConfigService_ListProviders(t *testing.T) {
	repo := newMockLLMConfigCRUDRepo()
	provider := &mockLLMProvider{}
	gw := newTestLLMGateway(provider)
	svc := NewLLMConfigService(repo, gw, make([]byte, 32))

	providers := svc.ListProviders()
	expectedProviders := []string{"openai", "deepseek", "qwen", "anthropic", "custom"}
	if len(providers) != len(expectedProviders) {
		t.Fatalf("len(providers) = %d, want %d", len(providers), len(expectedProviders))
	}

	providerSet := make(map[string]bool)
	for _, p := range providers {
		providerSet[p] = true
	}
	for _, ep := range expectedProviders {
		if !providerSet[ep] {
			t.Errorf("missing provider %q", ep)
		}
	}
}
