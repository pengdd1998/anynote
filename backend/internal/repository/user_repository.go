package repository

import (
	"context"
	"time"

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

func (r *UserRepository) Create(ctx context.Context, user *domain.User) error {
	hashedAuthKey, err := bcrypt.GenerateFromPassword(user.AuthKeyHash, bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	_, err = r.pool.Exec(ctx,
		`INSERT INTO users (id, email, username, auth_key_hash, salt, recovery_key, plan)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		user.ID, user.Email, user.Username, hashedAuthKey, user.Salt, user.RecoveryKey, user.Plan,
	)
	return err
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, email, username, auth_key_hash, salt, recovery_key, plan, created_at, updated_at
		 FROM users WHERE email = $1`, email,
	)

	var u domain.User
	err := row.Scan(&u.ID, &u.Email, &u.Username, &u.AuthKeyHash, &u.Salt, &u.RecoveryKey, &u.Plan, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, email, username, auth_key_hash, salt, recovery_key, plan, created_at, updated_at
		 FROM users WHERE id = $1`, id,
	)

	var u domain.User
	err := row.Scan(&u.ID, &u.Email, &u.Username, &u.AuthKeyHash, &u.Salt, &u.RecoveryKey, &u.Plan, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}
