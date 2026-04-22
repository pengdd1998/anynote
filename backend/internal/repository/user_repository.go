package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"github.com/anynote/backend/internal/domain"
)

type UserRepository struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

// bcryptCost is the bcrypt work factor. OWASP recommends cost 12+.
const bcryptCost = 12

func (r *UserRepository) Create(ctx context.Context, user *domain.User) error {
	hashedAuthKey, err := bcrypt.GenerateFromPassword(user.AuthKeyHash, bcryptCost)
	if err != nil {
		return err
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO users (id, email, username, auth_key_hash, salt, recovery_key, recovery_salt, plan)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		user.ID, user.Email, user.Username, hashedAuthKey, user.Salt, user.RecoveryKey, user.RecoverySalt, user.Plan,
	)
	return err
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, email, username, auth_key_hash, salt, recovery_key, recovery_salt, plan, created_at, updated_at
		 FROM users WHERE email = $1`, email,
	)

	var u domain.User
	err := row.Scan(&u.ID, &u.Email, &u.Username, &u.AuthKeyHash, &u.Salt, &u.RecoveryKey, &u.RecoverySalt, &u.Plan, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, email, username, auth_key_hash, salt, recovery_key, recovery_salt, plan, created_at, updated_at
		 FROM users WHERE id = $1`, id,
	)

	var u domain.User
	err := row.Scan(&u.ID, &u.Email, &u.Username, &u.AuthKeyHash, &u.Salt, &u.RecoveryKey, &u.RecoverySalt, &u.Plan, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// Delete removes a user by ID. Related records in tables with ON DELETE CASCADE
// foreign keys (sync_blobs, user_quotas, llm_configs, platform_connections,
// publish_logs, shared_notes, note_comments, note_reactions) are automatically
// removed by PostgreSQL.
func (r *UserRepository) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, id)
	return err
}

// GetRecoverySalt returns the recovery_salt for the given user ID.
// Returns nil slice (not NULL) for legacy users without a stored salt.
func (r *UserRepository) GetRecoverySalt(ctx context.Context, id uuid.UUID) ([]byte, error) {
	var salt []byte
	err := r.pool.QueryRow(ctx,
		`SELECT recovery_salt FROM users WHERE id = $1`, id,
	).Scan(&salt)
	if err != nil {
		return nil, err
	}
	return salt, nil
}

// GetRecoverySaltByEmail returns the recovery_salt for the given email.
// Returns nil slice (not NULL) for legacy users without a stored salt.
func (r *UserRepository) GetRecoverySaltByEmail(ctx context.Context, email string) ([]byte, error) {
	var salt []byte
	err := r.pool.QueryRow(ctx,
		`SELECT recovery_salt FROM users WHERE email = $1`, email,
	).Scan(&salt)
	if err != nil {
		return nil, err
	}
	return salt, nil
}
