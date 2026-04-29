package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// Payment-related sentinel errors.
var (
	ErrPaymentNotFound    = errors.New("payment not found")
	ErrInvalidStripeSig   = errors.New("invalid Stripe webhook signature")
	ErrPaymentAlreadyDone = errors.New("payment already completed")
	ErrCheckoutFailed     = errors.New("failed to create checkout session")
	ErrInvalidPaymentPlan = errors.New("invalid plan for payment")
)

// StripeClient abstracts Stripe checkout session creation for testability.
type StripeClient interface {
	CreateCheckoutSession(ctx context.Context, userID, plan, successURL, cancelURL string) (sessionID, sessionURL string, err error)
}

// PaymentRepo defines the data access interface for payment operations.
type PaymentRepo interface {
	CreatePayment(ctx context.Context, payment *domain.Payment) error
	GetByStripeSessionID(ctx context.Context, sessionID string) (*domain.Payment, error)
	UpdateStatus(ctx context.Context, id, status string) error
	GetPaymentsByUser(ctx context.Context, userID string) ([]domain.Payment, error)
	GetLatestCompletedPayment(ctx context.Context, userID string) (*domain.Payment, error)
	CompletePaymentTx(ctx context.Context, paymentID, plan string, userID uuid.UUID) error
	RecordWebhookEvent(ctx context.Context, eventID string) (bool, error)
}

// PaymentService provides payment verification and checkout business logic.
type PaymentService interface {
	CreateCheckoutSession(ctx context.Context, userID string, req domain.CreateCheckoutRequest) (*domain.CheckoutResponse, error)
	HandleWebhook(ctx context.Context, payload []byte, sig string) error
	GetPaymentHistory(ctx context.Context, userID string) ([]domain.Payment, error)
}

type paymentService struct {
	paymentRepo   PaymentRepo
	planRepo      PlanRepo
	stripe        StripeClient
	webhookSecret string
	testMode      bool
}

// NewPaymentService creates a new payment service.
// If stripeClient is nil, the service operates in test mode (no real Stripe calls).
func NewPaymentService(
	paymentRepo PaymentRepo,
	planRepo PlanRepo,
	stripeClient StripeClient,
	webhookSecret string,
) PaymentService {
	testMode := stripeClient == nil
	if testMode {
		slog.Info("payment service running in test mode (no Stripe key configured)")
	}
	return &paymentService{
		paymentRepo:   paymentRepo,
		planRepo:      planRepo,
		stripe:        stripeClient,
		webhookSecret: webhookSecret,
		testMode:      testMode,
	}
}

// planAmounts maps plan names to their price in cents.
var planAmounts = map[string]int{
	"pro":      499,  // $4.99/month
	"lifetime": 4999, // $49.99 one-time
}

// CreateCheckoutSession creates a Stripe checkout session and stores a pending
// payment record. In test mode, returns a mock URL without calling Stripe.
func (s *paymentService) CreateCheckoutSession(ctx context.Context, userID string, req domain.CreateCheckoutRequest) (*domain.CheckoutResponse, error) {
	amount, ok := planAmounts[req.Plan]
	if !ok {
		return nil, ErrInvalidPaymentPlan
	}

	var sessionID, sessionURL string
	var err error

	if s.testMode {
		// In test mode, generate a deterministic session ID and a mock URL.
		sessionID = fmt.Sprintf("cs_test_%s_%s", userID[:8], req.Plan)
		sessionURL = fmt.Sprintf("https://checkout.stripe.test/%s", sessionID)
	} else {
		sessionID, sessionURL, err = s.stripe.CreateCheckoutSession(ctx, userID, req.Plan, req.SuccessURL, req.CancelURL)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrCheckoutFailed, err)
		}
	}

	payment := &domain.Payment{
		UserID:          userID,
		StripeSessionID: sessionID,
		AmountCents:     amount,
		Currency:        "usd",
		Status:          "pending",
		Plan:            req.Plan,
	}

	if err := s.paymentRepo.CreatePayment(ctx, payment); err != nil {
		return nil, fmt.Errorf("store payment record: %w", err)
	}

	return &domain.CheckoutResponse{SessionURL: sessionURL}, nil
}

// HandleWebhook verifies the Stripe webhook signature, checks idempotency, and
// routes the event to the appropriate handler based on event type.
func (s *paymentService) HandleWebhook(ctx context.Context, payload []byte, sig string) error {
	if s.testMode {
		return s.handleTestWebhook(ctx, payload)
	}

	if err := VerifyStripeSignature(payload, sig, s.webhookSecret); err != nil {
		return ErrInvalidStripeSig
	}

	var event stripeWebhookEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		return fmt.Errorf("parse webhook payload: %w", err)
	}

	if event.ID == "" {
		return fmt.Errorf("webhook event missing ID")
	}

	// Idempotency check
	isNew, err := s.paymentRepo.RecordWebhookEvent(ctx, event.ID)
	if err != nil {
		return fmt.Errorf("webhook idempotency check: %w", err)
	}
	if !isNew {
		slog.Info("webhook event already processed, skipping", "event_id", event.ID)
		return nil
	}

	switch event.Type {
	case "checkout.session.completed":
		return s.handleCheckoutCompleted(ctx, event)
	case "customer.subscription.deleted":
		return s.handleSubscriptionDeleted(ctx, event)
	case "invoice.payment_failed":
		return s.handleInvoicePaymentFailed(ctx, event)
	case "checkout.session.expired":
		return s.handleCheckoutExpired(ctx, event)
	case "charge.refunded":
		return s.handleChargeRefunded(ctx, event)
	default:
		slog.Info("ignoring unhandled webhook event", "type", event.Type, "event_id", event.ID)
		return nil
	}
}

// handleTestWebhook processes webhooks in test mode without signature verification.
func (s *paymentService) handleTestWebhook(ctx context.Context, payload []byte) error {
	var event stripeWebhookEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		return fmt.Errorf("parse test webhook payload: %w", err)
	}

	// Idempotency check (best-effort in test mode)
	if event.ID != "" {
		isNew, err := s.paymentRepo.RecordWebhookEvent(ctx, event.ID)
		if err == nil && !isNew {
			slog.Info("test webhook event already processed, skipping", "event_id", event.ID)
			return nil
		}
	}

	switch event.Type {
	case "checkout.session.completed":
		sessionID := event.Data.Object.ID
		if sessionID == "" {
			return fmt.Errorf("test webhook event missing session ID")
		}
		return s.completePayment(ctx, sessionID)
	case "customer.subscription.deleted":
		return s.handleSubscriptionDeleted(ctx, event)
	case "invoice.payment_failed":
		return s.handleInvoicePaymentFailed(ctx, event)
	case "checkout.session.expired":
		return s.handleCheckoutExpired(ctx, event)
	case "charge.refunded":
		return s.handleChargeRefunded(ctx, event)
	default:
		return nil
	}
}

// completePayment marks a payment as completed and upgrades the user's plan
// atomically within a single database transaction.
func (s *paymentService) completePayment(ctx context.Context, sessionID string) error {
	payment, err := s.paymentRepo.GetByStripeSessionID(ctx, sessionID)
	if err != nil {
		return fmt.Errorf("lookup payment by session: %w", err)
	}
	if payment == nil {
		return ErrPaymentNotFound
	}

	if payment.Status == "completed" {
		return ErrPaymentAlreadyDone
	}

	userID, parseErr := uuid.Parse(payment.UserID)
	if parseErr != nil {
		return fmt.Errorf("parse user ID: %w", parseErr)
	}

	if err := s.paymentRepo.CompletePaymentTx(ctx, payment.ID, payment.Plan, userID); err != nil {
		return fmt.Errorf("complete payment transaction: %w", err)
	}

	slog.Info("payment completed, plan upgraded",
		"user_id", payment.UserID,
		"plan", payment.Plan,
		"session_id", sessionID,
	)
	return nil
}

// handleCheckoutCompleted handles checkout.session.completed events.
func (s *paymentService) handleCheckoutCompleted(ctx context.Context, event stripeWebhookEvent) error {
	sessionID := event.Data.Object.ID
	if sessionID == "" {
		return fmt.Errorf("checkout.session.completed event missing session ID")
	}
	return s.completePayment(ctx, sessionID)
}

// handleSubscriptionDeleted handles customer.subscription.deleted events.
// Downgrades the user to the free plan.
func (s *paymentService) handleSubscriptionDeleted(ctx context.Context, event stripeWebhookEvent) error {
	userID := event.Data.Object.ClientReferenceID
	if userID == "" {
		return fmt.Errorf("subscription.deleted event missing client_reference_id")
	}
	uid, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("parse user ID from client_reference_id: %w", err)
	}
	if err := s.planRepo.SetPlan(ctx, uid, "free"); err != nil {
		return fmt.Errorf("downgrade plan on subscription deleted: %w", err)
	}
	slog.Info("subscription deleted, plan downgraded to free", "user_id", userID)
	return nil
}

// handleInvoicePaymentFailed handles invoice.payment_failed events.
// Logs the failure; Stripe will retry automatically.
func (s *paymentService) handleInvoicePaymentFailed(_ context.Context, event stripeWebhookEvent) error {
	slog.Warn("invoice payment failed", "event_id", event.ID)
	return nil
}

// handleCheckoutExpired handles checkout.session.expired events.
// Marks the corresponding payment as expired if it is still pending.
func (s *paymentService) handleCheckoutExpired(ctx context.Context, event stripeWebhookEvent) error {
	sessionID := event.Data.Object.ID
	if sessionID == "" {
		return fmt.Errorf("checkout.session.expired event missing session ID")
	}
	payment, err := s.paymentRepo.GetByStripeSessionID(ctx, sessionID)
	if err != nil {
		return fmt.Errorf("lookup payment for expired session: %w", err)
	}
	if payment == nil {
		return ErrPaymentNotFound
	}
	if payment.Status != "pending" {
		return nil // already processed
	}
	if err := s.paymentRepo.UpdateStatus(ctx, payment.ID, "expired"); err != nil {
		return fmt.Errorf("mark payment expired: %w", err)
	}
	slog.Info("checkout session expired", "session_id", sessionID)
	return nil
}

// handleChargeRefunded handles charge.refunded events.
// Marks the payment as refunded and downgrades the user to the free plan.
func (s *paymentService) handleChargeRefunded(ctx context.Context, event stripeWebhookEvent) error {
	sessionID := event.Data.Object.ID
	if sessionID == "" {
		return fmt.Errorf("charge.refunded event missing session ID")
	}
	payment, err := s.paymentRepo.GetByStripeSessionID(ctx, sessionID)
	if err != nil {
		return fmt.Errorf("lookup payment for refunded charge: %w", err)
	}
	if payment == nil {
		return ErrPaymentNotFound
	}
	if err := s.paymentRepo.UpdateStatus(ctx, payment.ID, "refunded"); err != nil {
		return fmt.Errorf("mark payment refunded: %w", err)
	}
	uid, parseErr := uuid.Parse(payment.UserID)
	if parseErr == nil {
		if err := s.planRepo.SetPlan(ctx, uid, "free"); err != nil {
			slog.Error("failed to downgrade plan after refund", "user_id", payment.UserID, "error", err)
		}
	}
	slog.Info("payment refunded, plan downgraded", "user_id", payment.UserID, "session_id", sessionID)
	return nil
}

// GetPaymentHistory returns all payments for a user.
func (s *paymentService) GetPaymentHistory(ctx context.Context, userID string) ([]domain.Payment, error) {
	payments, err := s.paymentRepo.GetPaymentsByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	if payments == nil {
		return []domain.Payment{}, nil
	}
	return payments, nil
}

// stripeWebhookEvent represents the top-level structure of a Stripe webhook event.
type stripeWebhookEvent struct {
	ID   string `json:"id"`
	Type string `json:"type"`
	Data struct {
		Object struct {
			ID                string `json:"id"`
			ClientReferenceID string `json:"client_reference_id"`
			AmountTotal       int64  `json:"amount_total"`
			Subscription      string `json:"subscription"`
			PaymentIntent     string `json:"payment_intent"`
		} `json:"object"`
	} `json:"data"`
}

// VerifyStripeSignature verifies the Stripe webhook signature using HMAC-SHA256.
// The signature header format is "t=timestamp,v1=signature".
// Exported for use in tests.
func VerifyStripeSignature(payload []byte, sigHeader, secret string) error {
	if secret == "" {
		return fmt.Errorf("stripe webhook secret not configured")
	}

	// Parse the signature header: "t=timestamp,v1=signature"
	parts := parseStripeSignatureHeader(sigHeader)
	timestamp, ok1 := parts["t"]
	signature, ok2 := parts["v1"]
	if !ok1 || !ok2 {
		return fmt.Errorf("malformed signature header")
	}

	// Construct the signed payload: timestamp.payload
	signedPayload := fmt.Sprintf("%s.%s", timestamp, string(payload))

	// Compute HMAC-SHA256.
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(signedPayload))
	expectedSig := hex.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(signature), []byte(expectedSig)) {
		return fmt.Errorf("signature mismatch")
	}

	// Check timestamp freshness (5 minute tolerance).
	ts, err := strconv.ParseInt(timestamp, 10, 64)
	if err == nil {
		tolerance := int64(300) // 5 minutes
		now := time.Now().Unix()
		if now-ts > tolerance {
			return fmt.Errorf("webhook timestamp too old")
		}
	}

	return nil
}

// parseStripeSignatureHeader parses a Stripe signature header into key-value pairs.
func parseStripeSignatureHeader(header string) map[string]string {
	result := make(map[string]string)
	for _, pair := range strings.Split(header, ",") {
		pair = strings.TrimSpace(pair)
		if idx := strings.Index(pair, "="); idx > 0 {
			result[strings.TrimSpace(pair[:idx])] = strings.TrimSpace(pair[idx+1:])
		}
	}
	return result
}
