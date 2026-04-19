package service

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/llm"
)

type LLMConfigService interface {
	List(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error)
	Create(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error)
	Update(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error)
	Delete(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error
	TestConnection(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error
	GetDefault(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error)
	ListProviders() []string
}

type LLMConfigRepo interface {
	ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error)
	GetByID(ctx context.Context, id uuid.UUID) (*domain.LLMConfig, error)
	GetDefaultByUser(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error)
	Create(ctx context.Context, cfg *domain.LLMConfig) error
	Update(ctx context.Context, cfg *domain.LLMConfig) error
	Delete(ctx context.Context, id uuid.UUID) error
}

type llmConfigService struct {
	repo      LLMConfigRepo
	gateway   *llm.Gateway
	masterKey []byte
}

func NewLLMConfigService(repo LLMConfigRepo, gateway *llm.Gateway, masterKey []byte) LLMConfigService {
	return &llmConfigService{repo: repo, gateway: gateway, masterKey: masterKey}
}

func (s *llmConfigService) List(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error) {
	return s.repo.ListByUser(ctx, userID)
}

func (s *llmConfigService) Create(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
	cfg.ID = uuid.New()
	cfg.UserID = userID

	// Encrypt API key before storage
	encryptedKey, err := llm.EncryptAPIKey(cfg.DecryptedKey, s.masterKey)
	if err != nil {
		return nil, fmt.Errorf("encrypt api key: %w", err)
	}
	// Store encrypted key, clear plaintext
	cfg.EncryptedKey = encryptedKey
	cfg.DecryptedKey = ""
	if err := s.repo.Create(ctx, &cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}

func (s *llmConfigService) Update(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
	existing, err := s.repo.GetByID(ctx, cfg.ID)
	if err != nil {
		return nil, fmt.Errorf("config not found")
	}
	if existing.UserID != userID {
		return nil, fmt.Errorf("unauthorized")
	}

	if cfg.DecryptedKey != "" {
		encryptedKey, err := llm.EncryptAPIKey(cfg.DecryptedKey, s.masterKey)
		if err != nil {
			return nil, fmt.Errorf("encrypt api key: %w", err)
		}
		cfg.EncryptedKey = encryptedKey
		cfg.DecryptedKey = ""
	}

	if err := s.repo.Update(ctx, &cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}

func (s *llmConfigService) Delete(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error {
	existing, err := s.repo.GetByID(ctx, configID)
	if err != nil {
		return err
	}
	if existing.UserID != userID {
		return fmt.Errorf("unauthorized")
	}

	return s.repo.Delete(ctx, configID)
}

func (s *llmConfigService) TestConnection(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error {
	cfg, err := s.repo.GetByID(ctx, configID)
	if err != nil {
		return err
	}
	if cfg.UserID != userID {
		return fmt.Errorf("unauthorized")
	}

	// Decrypt the stored API key for testing
	decryptedKey, err := llm.DecryptAPIKey(cfg.EncryptedKey, s.masterKey)
	if err != nil {
		return fmt.Errorf("decrypt api key: %w", err)
	}

	gwCfg := llm.GatewayConfig{
		Provider: cfg.Provider,
		BaseURL:  cfg.BaseURL,
		APIKey:   decryptedKey,
		Model:    cfg.Model,
	}

	chatReq := llm.ChatRequest{
		Model: cfg.Model,
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hello, this is a test. Reply with OK."},
		},
		MaxTokens: intPtr(10),
		Stream:    false,
	}

	_, err = s.gateway.Chat(ctx, gwCfg, chatReq)
	return err
}

func (s *llmConfigService) GetDefault(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error) {
	return s.repo.GetDefaultByUser(ctx, userID)
}

func (s *llmConfigService) ListProviders() []string {
	return []string{"openai", "deepseek", "qwen", "anthropic", "custom"}
}

func intPtr(i int) *int { return &i }
