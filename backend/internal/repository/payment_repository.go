package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/domain"
)

// PaymentRepository manages payment records in PostgreSQL.
type PaymentRepository struct {
	pool *pgxpool.Pool
}

// NewPaymentRepository creates a new PaymentRepository.
func NewPaymentRepository(pool *pgxpool.Pool) *PaymentRepository {
	return &PaymentRepository{pool: pool}
}

// CreatePayment inserts a new payment record.
func (r *PaymentRepository) CreatePayment(ctx context.Context, payment *domain.Payment) error {
	return r.pool.QueryRow(ctx,
		`INSERT INTO payments (user_id, stripe_session_id, amount_cents, currency, status, plan)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 RETURNING id, created_at`,
		payment.UserID, payment.StripeSessionID, payment.AmountCents,
		payment.Currency, payment.Status, payment.Plan,
	).Scan(&payment.ID, &payment.CreatedAt)
}

// GetByStripeSessionID returns a payment by its Stripe checkout session ID.
func (r *PaymentRepository) GetByStripeSessionID(ctx context.Context, sessionID string) (*domain.Payment, error) {
	var p domain.Payment
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, stripe_session_id, amount_cents, currency, status, plan, created_at, completed_at
		 FROM payments WHERE stripe_session_id = $1`,
		sessionID,
	).Scan(&p.ID, &p.UserID, &p.StripeSessionID, &p.AmountCents,
		&p.Currency, &p.Status, &p.Plan, &p.CreatedAt, &p.CompletedAt)
	if err != nil {
		return nil, fmt.Errorf("get payment by stripe session: %w", err)
	}
	return &p, nil
}

// UpdateStatus updates the status of a payment and sets completed_at when
// the status is "completed".
func (r *PaymentRepository) UpdateStatus(ctx context.Context, id, status string) error {
	var completedAt *time.Time
	if status == "completed" {
		now := time.Now()
		completedAt = &now
	}
	tag, err := r.pool.Exec(ctx,
		`UPDATE payments SET status = $1, completed_at = COALESCE($2, completed_at) WHERE id = $3`,
		status, completedAt, id,
	)
	if err != nil {
		return fmt.Errorf("update payment status: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("update payment status: payment not found")
	}
	return nil
}

// GetPaymentsByUser returns all payments for a user, ordered by created_at descending.
func (r *PaymentRepository) GetPaymentsByUser(ctx context.Context, userID string) ([]domain.Payment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, stripe_session_id, amount_cents, currency, status, plan, created_at, completed_at
		 FROM payments WHERE user_id = $1 ORDER BY created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("get payments by user: %w", err)
	}
	defer rows.Close()

	var payments []domain.Payment
	for rows.Next() {
		var p domain.Payment
		if err := rows.Scan(&p.ID, &p.UserID, &p.StripeSessionID, &p.AmountCents,
			&p.Currency, &p.Status, &p.Plan, &p.CreatedAt, &p.CompletedAt); err != nil {
			return nil, fmt.Errorf("scan payment: %w", err)
		}
		payments = append(payments, p)
	}
	return payments, rows.Err()
}

// GetLatestCompletedPayment returns the most recent completed payment for a user,
// or nil if none exists.
func (r *PaymentRepository) GetLatestCompletedPayment(ctx context.Context, userID string) (*domain.Payment, error) {
	var p domain.Payment
	err := r.pool.QueryRow(ctx,
		`SELECT id, user_id, stripe_session_id, amount_cents, currency, status, plan, created_at, completed_at
		 FROM payments
		 WHERE user_id = $1 AND status = 'completed'
		 ORDER BY completed_at DESC
		 LIMIT 1`,
		userID,
	).Scan(&p.ID, &p.UserID, &p.StripeSessionID, &p.AmountCents,
		&p.Currency, &p.Status, &p.Plan, &p.CreatedAt, &p.CompletedAt)
	if err != nil {
		return nil, nil //nolint:nilerr // no completed payment is not an error
	}
	return &p, nil
}
