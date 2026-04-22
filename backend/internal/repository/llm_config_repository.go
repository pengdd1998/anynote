package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

type LLMConfigRepository struct {
	pool *pgxpool.Pool
}

func NewLLMConfigRepository(pool *pgxpool.Pool) *LLMConfigRepository {
	return &LLMConfigRepository{pool: pool}
}

func (r *LLMConfigRepository) ListByUser(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, name, provider, base_url, encrypted_key, model, is_default, max_tokens, temperature, created_at, updated_at
		 FROM llm_configs WHERE user_id = $1 ORDER BY created_at DESC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var configs []domain.LLMConfig
	for rows.Next() {
		var c domain.LLMConfig
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.Provider, &c.BaseURL, &c.EncryptedKey, &c.Model, &c.IsDefault, &c.MaxTokens, &c.Temperature, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		configs = append(configs, c)
	}
	return configs, rows.Err()
}

func (r *LLMConfigRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.LLMConfig, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, user_id, name, provider, base_url, encrypted_key, model, is_default, max_tokens, temperature, created_at, updated_at
		 FROM llm_configs WHERE id = $1`, id,
	)

	var c domain.LLMConfig
	err := row.Scan(&c.ID, &c.UserID, &c.Name, &c.Provider, &c.BaseURL, &c.EncryptedKey, &c.Model, &c.IsDefault, &c.MaxTokens, &c.Temperature, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *LLMConfigRepository) GetDefaultByUser(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, user_id, name, provider, base_url, encrypted_key, model, is_default, max_tokens, temperature, created_at, updated_at
		 FROM llm_configs WHERE user_id = $1 AND is_default = true LIMIT 1`, userID,
	)

	var c domain.LLMConfig
	err := row.Scan(&c.ID, &c.UserID, &c.Name, &c.Provider, &c.BaseURL, &c.EncryptedKey, &c.Model, &c.IsDefault, &c.MaxTokens, &c.Temperature, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *LLMConfigRepository) Create(ctx context.Context, cfg *domain.LLMConfig) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO llm_configs (id, user_id, name, provider, base_url, encrypted_key, model, is_default, max_tokens, temperature)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		cfg.ID, cfg.UserID, cfg.Name, cfg.Provider, cfg.BaseURL, cfg.EncryptedKey, cfg.Model, cfg.IsDefault, cfg.MaxTokens, cfg.Temperature,
	)
	return err
}

func (r *LLMConfigRepository) Update(ctx context.Context, cfg *domain.LLMConfig) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE llm_configs SET
		     name = $3, provider = $4, base_url = $5, encrypted_key = $6,
		     model = $7, is_default = $8, max_tokens = $9, temperature = $10, updated_at = NOW()
		 WHERE id = $1 AND user_id = $2`,
		cfg.ID, cfg.UserID, cfg.Name, cfg.Provider, cfg.BaseURL, cfg.EncryptedKey, cfg.Model, cfg.IsDefault, cfg.MaxTokens, cfg.Temperature,
	)
	return err
}

func (r *LLMConfigRepository) Delete(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM llm_configs WHERE id = $1 AND user_id = $2`, id, userID)
	return err
}
