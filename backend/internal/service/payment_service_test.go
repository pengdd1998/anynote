package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock PaymentRepo
// ---------------------------------------------------------------------------

type mockPaymentRepo struct {
	payments    map[string]*domain.Payment // keyed by stripe_session_id
	byID        map[string]*domain.Payment // keyed by id
	createErr   error
	updateErr   error
	txErr       error // error returned by CompletePaymentTx
}

func newMockPaymentRepo() *mockPaymentRepo {
	return &mockPaymentRepo{
		payments: make(map[string]*domain.Payment),
		byID:     make(map[string]*domain.Payment),
	}
}

func (m *mockPaymentRepo) CreatePayment(_ context.Context, p *domain.Payment) error {
	if m.createErr != nil {
		return m.createErr
	}
	p.ID = uuid.New().String()
	p.CreatedAt = time.Now()
	m.payments[p.StripeSessionID] = p
	m.byID[p.ID] = p
	return nil
}

func (m *mockPaymentRepo) GetByStripeSessionID(_ context.Context, sessionID string) (*domain.Payment, error) {
	p, ok := m.payments[sessionID]
	if !ok {
		return nil, fmt.Errorf("not found")
	}
	return p, nil
}

func (m *mockPaymentRepo) UpdateStatus(_ context.Context, id, status string) error {
	if m.updateErr != nil {
		return m.updateErr
	}
	p, ok := m.byID[id]
	if !ok {
		return fmt.Errorf("not found")
	}
	p.Status = status
	if status == "completed" {
		now := time.Now()
		p.CompletedAt = &now
	}
	return nil
}

func (m *mockPaymentRepo) GetPaymentsByUser(_ context.Context, userID string) ([]domain.Payment, error) {
	var result []domain.Payment
	for _, p := range m.payments {
		if p.UserID == userID {
			result = append(result, *p)
		}
	}
	return result, nil
}

func (m *mockPaymentRepo) GetLatestCompletedPayment(_ context.Context, userID string) (*domain.Payment, error) {
	var latest *domain.Payment
	for _, p := range m.payments {
		if p.UserID == userID && p.Status == "completed" {
			if latest == nil || (p.CompletedAt != nil && latest.CompletedAt != nil && p.CompletedAt.After(*latest.CompletedAt)) {
				latest = p
			}
		}
	}
	return latest, nil
}

func (m *mockPaymentRepo) CompletePaymentTx(_ context.Context, paymentID, plan string, _ uuid.UUID) error {
	if m.txErr != nil {
		return m.txErr
	}
	if m.updateErr != nil {
		return m.updateErr
	}
	p, ok := m.byID[paymentID]
	if !ok {
		return fmt.Errorf("not found")
	}
	p.Status = "completed"
	now := time.Now()
	p.CompletedAt = &now
	_ = plan
	return nil
}

func (m *mockPaymentRepo) RecordWebhookEvent(_ context.Context, _ string) (bool, error) {
	return true, nil
}

// ---------------------------------------------------------------------------
// Mock StripeClient
// ---------------------------------------------------------------------------

type mockStripeClient struct {
	sessionID  string
	sessionURL string
	err        error
}

func (m *mockStripeClient) CreateCheckoutSession(_ context.Context, _, _, _, _ string) (string, string, error) {
	return m.sessionID, m.sessionURL, m.err
}

// ---------------------------------------------------------------------------
// Tests: CreateCheckoutSession
// ---------------------------------------------------------------------------

func TestPaymentService_CreateCheckoutSession_ProPlan(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "whsecret")

	userID := uuid.New().String()
	resp, err := svc.CreateCheckoutSession(context.Background(), userID, domain.CreateCheckoutRequest{
		Plan:       "pro",
		SuccessURL: "https://app.test/success",
		CancelURL:  "https://app.test/cancel",
	})
	if err != nil {
		t.Fatalf("CreateCheckoutSession: %v", err)
	}
	if resp.SessionURL == "" {
		t.Error("SessionURL should not be empty")
	}
	if resp.SessionURL == "" {
		t.Error("SessionURL should not be empty")
	}

	// Verify payment record was stored.
	if len(paymentRepo.payments) != 1 {
		t.Fatalf("expected 1 payment, got %d", len(paymentRepo.payments))
	}
	for _, p := range paymentRepo.payments {
		if p.UserID != userID {
			t.Errorf("payment UserID = %q, want %q", p.UserID, userID)
		}
		if p.AmountCents != 499 {
			t.Errorf("AmountCents = %d, want 499", p.AmountCents)
		}
		if p.Status != "pending" {
			t.Errorf("Status = %q, want pending", p.Status)
		}
		if p.Plan != "pro" {
			t.Errorf("Plan = %q, want pro", p.Plan)
		}
	}
}

func TestPaymentService_CreateCheckoutSession_LifetimePlan(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "whsecret")

	userID := uuid.New().String()
	resp, err := svc.CreateCheckoutSession(context.Background(), userID, domain.CreateCheckoutRequest{
		Plan: "lifetime",
	})
	if err != nil {
		t.Fatalf("CreateCheckoutSession: %v", err)
	}
	if resp.SessionURL == "" {
		t.Error("SessionURL should not be empty")
	}

	for _, p := range paymentRepo.payments {
		if p.AmountCents != 4999 {
			t.Errorf("AmountCents = %d, want 4999", p.AmountCents)
		}
	}
}

func TestPaymentService_CreateCheckoutSession_InvalidPlan(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "whsecret")

	_, err := svc.CreateCheckoutSession(context.Background(), uuid.New().String(), domain.CreateCheckoutRequest{
		Plan: "enterprise",
	})
	if !errors.Is(err, ErrInvalidPaymentPlan) {
		t.Errorf("expected ErrInvalidPaymentPlan, got %v", err)
	}
}

func TestPaymentService_CreateCheckoutSession_EmptyPlan(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "whsecret")

	_, err := svc.CreateCheckoutSession(context.Background(), uuid.New().String(), domain.CreateCheckoutRequest{
		Plan: "",
	})
	if !errors.Is(err, ErrInvalidPaymentPlan) {
		t.Errorf("expected ErrInvalidPaymentPlan, got %v", err)
	}
}

func TestPaymentService_CreateCheckoutSession_RepoError(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	paymentRepo.createErr = errors.New("db error")
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "whsecret")

	_, err := svc.CreateCheckoutSession(context.Background(), uuid.New().String(), domain.CreateCheckoutRequest{
		Plan: "pro",
	})
	if err == nil {
		t.Error("expected error when repo fails")
	}
}

func TestPaymentService_CreateCheckoutSession_WithStripeClient(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	stripe := &mockStripeClient{
		sessionID:  "cs_live_abc123",
		sessionURL: "https://checkout.stripe.com/cs/live/abc123",
	}
	svc := NewPaymentService(paymentRepo, planRepo, stripe, "whsecret")

	resp, err := svc.CreateCheckoutSession(context.Background(), uuid.New().String(), domain.CreateCheckoutRequest{
		Plan: "pro",
	})
	if err != nil {
		t.Fatalf("CreateCheckoutSession: %v", err)
	}
	if resp.SessionURL != "https://checkout.stripe.com/cs/live/abc123" {
		t.Errorf("SessionURL = %q, want https://checkout.stripe.com/cs/live/abc123", resp.SessionURL)
	}

	for _, p := range paymentRepo.payments {
		if p.StripeSessionID != "cs_live_abc123" {
			t.Errorf("StripeSessionID = %q, want cs_live_abc123", p.StripeSessionID)
		}
	}
}

func TestPaymentService_CreateCheckoutSession_StripeError(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	stripe := &mockStripeClient{err: errors.New("stripe api error")}
	svc := NewPaymentService(paymentRepo, planRepo, stripe, "whsecret")

	_, err := svc.CreateCheckoutSession(context.Background(), uuid.New().String(), domain.CreateCheckoutRequest{
		Plan: "pro",
	})
	if !errors.Is(err, ErrCheckoutFailed) {
		t.Errorf("expected ErrCheckoutFailed, got %v", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: HandleWebhook
// ---------------------------------------------------------------------------

func TestPaymentService_HandleWebhook_TestMode_CompletesPayment(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	userID := uuid.New()
	// Pre-create a payment.
	payment := &domain.Payment{
		UserID:          userID.String(),
		StripeSessionID: "cs_test_" + userID.String()[:8] + "_pro",
		AmountCents:     499,
		Currency:        "usd",
		Status:          "pending",
		Plan:            "pro",
	}
	if err := paymentRepo.CreatePayment(context.Background(), payment); err != nil {
		t.Fatalf("setup: %v", err)
	}

	payload, _ := json.Marshal(stripeWebhookEvent{
		Type: "checkout.session.completed",
	})
	// Manually set the session ID in the event data.
	var raw map[string]interface{}
	json.Unmarshal(payload, &raw)
	raw["data"] = map[string]interface{}{
		"object": map[string]interface{}{
			"id": payment.StripeSessionID,
		},
	}
	payload, _ = json.Marshal(raw)

	err := svc.HandleWebhook(context.Background(), payload, "")
	if err != nil {
		t.Fatalf("HandleWebhook: %v", err)
	}

	// Verify payment status updated (transactional upgrade also marks this).
	p, _ := paymentRepo.GetByStripeSessionID(context.Background(), payment.StripeSessionID)
	if p.Status != "completed" {
		t.Errorf("payment status = %q, want completed", p.Status)
	}
	if p.CompletedAt == nil {
		t.Error("payment CompletedAt should be set")
	}
}

func TestPaymentService_HandleWebhook_TestMode_IgnoresNonCompletion(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	payload, _ := json.Marshal(map[string]interface{}{
		"type": "account.updated",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "acct_123"},
		},
	})

	err := svc.HandleWebhook(context.Background(), payload, "")
	if err != nil {
		t.Fatalf("HandleWebhook should not error for unhandled events: %v", err)
	}
}

func TestPaymentService_HandleWebhook_TestMode_MissingSessionID(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	payload, _ := json.Marshal(map[string]interface{}{
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{},
		},
	})

	err := svc.HandleWebhook(context.Background(), payload, "")
	if err == nil {
		t.Error("expected error when session ID is missing")
	}
}

func TestPaymentService_HandleWebhook_TestMode_PaymentNotFound(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	payload, _ := json.Marshal(map[string]interface{}{
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "cs_nonexistent"},
		},
	})

	err := svc.HandleWebhook(context.Background(), payload, "")
	if err == nil {
		t.Error("expected error for nonexistent payment")
	}
}

func TestPaymentService_HandleWebhook_TestMode_AlreadyCompleted(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	payment := &domain.Payment{
		UserID:          uuid.New().String(),
		StripeSessionID: "cs_test_already_done",
		AmountCents:     499,
		Currency:        "usd",
		Status:          "completed",
		Plan:            "pro",
	}
	paymentRepo.CreatePayment(context.Background(), payment)

	payload, _ := json.Marshal(map[string]interface{}{
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "cs_test_already_done"},
		},
	})

	err := svc.HandleWebhook(context.Background(), payload, "")
	if !errors.Is(err, ErrPaymentAlreadyDone) {
		t.Errorf("expected ErrPaymentAlreadyDone, got %v", err)
	}
}

func TestPaymentService_HandleWebhook_TestMode_InvalidJSON(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	err := svc.HandleWebhook(context.Background(), []byte("invalid json"), "")
	if err == nil {
		t.Error("expected error for invalid JSON")
	}
}

func TestPaymentService_HandleWebhook_WithSignatureVerification(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	webhookSecret := "whsec_test_secret_1234567890"
	stripe := &mockStripeClient{}
	svc := NewPaymentService(paymentRepo, planRepo, stripe, webhookSecret)

	userID := uuid.New()
	payment := &domain.Payment{
		UserID:          userID.String(),
		StripeSessionID: "cs_live_sig_test",
		AmountCents:     499,
		Currency:        "usd",
		Status:          "pending",
		Plan:            "pro",
	}
	paymentRepo.CreatePayment(context.Background(), payment)

	eventPayload, _ := json.Marshal(map[string]interface{}{
		"id":   "evt_sig_test_001",
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "cs_live_sig_test"},
		},
	})

	// Create a valid signature header.
	timestamp := fmt.Sprintf("%d", time.Now().Unix())
	signedPayload := timestamp + "." + string(eventPayload)
	mac := hmac.New(sha256.New, []byte(webhookSecret))
	mac.Write([]byte(signedPayload))
	sig := hex.EncodeToString(mac.Sum(nil))
	sigHeader := fmt.Sprintf("t=%s,v1=%s", timestamp, sig)

	err := svc.HandleWebhook(context.Background(), eventPayload, sigHeader)
	if err != nil {
		t.Fatalf("HandleWebhook with valid signature: %v", err)
	}

	p, _ := paymentRepo.GetByStripeSessionID(context.Background(), "cs_live_sig_test")
	if p.Status != "completed" {
		t.Errorf("payment status = %q, want completed", p.Status)
	}
}

func TestPaymentService_HandleWebhook_InvalidSignature(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	webhookSecret := "whsec_test_secret_1234567890"
	stripe := &mockStripeClient{}
	svc := NewPaymentService(paymentRepo, planRepo, stripe, webhookSecret)

	payload, _ := json.Marshal(map[string]interface{}{
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "cs_live_any"},
		},
	})

	err := svc.HandleWebhook(context.Background(), payload, "t=123,v1=badsignature")
	if !errors.Is(err, ErrInvalidStripeSig) {
		t.Errorf("expected ErrInvalidStripeSig, got %v", err)
	}
}

func TestPaymentService_HandleWebhook_MissingSignatureHeader(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	webhookSecret := "whsec_test_secret_1234567890"
	stripe := &mockStripeClient{}
	svc := NewPaymentService(paymentRepo, planRepo, stripe, webhookSecret)

	payload, _ := json.Marshal(map[string]interface{}{
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "cs_live_any"},
		},
	})

	err := svc.HandleWebhook(context.Background(), payload, "")
	if !errors.Is(err, ErrInvalidStripeSig) {
		t.Errorf("expected ErrInvalidStripeSig, got %v", err)
	}
}

// ---------------------------------------------------------------------------
// Tests: GetPaymentHistory
// ---------------------------------------------------------------------------

func TestPaymentService_GetPaymentHistory_Empty(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	payments, err := svc.GetPaymentHistory(context.Background(), uuid.New().String())
	if err != nil {
		t.Fatalf("GetPaymentHistory: %v", err)
	}
	if len(payments) != 0 {
		t.Errorf("expected 0 payments, got %d", len(payments))
	}
}

func TestPaymentService_GetPaymentHistory_WithPayments(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	userID := uuid.New().String()
	p1 := &domain.Payment{
		UserID: userID, StripeSessionID: "cs_1", AmountCents: 499,
		Currency: "usd", Status: "completed", Plan: "pro",
	}
	p2 := &domain.Payment{
		UserID: userID, StripeSessionID: "cs_2", AmountCents: 4999,
		Currency: "usd", Status: "pending", Plan: "lifetime",
	}
	paymentRepo.CreatePayment(context.Background(), p1)
	paymentRepo.CreatePayment(context.Background(), p2)

	payments, err := svc.GetPaymentHistory(context.Background(), userID)
	if err != nil {
		t.Fatalf("GetPaymentHistory: %v", err)
	}
	if len(payments) != 2 {
		t.Errorf("expected 2 payments, got %d", len(payments))
	}
}

func TestPaymentService_GetPaymentHistory_OtherUser(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	userA := uuid.New().String()
	userB := uuid.New().String()
	p1 := &domain.Payment{
		UserID: userA, StripeSessionID: "cs_a1", AmountCents: 499,
		Currency: "usd", Status: "completed", Plan: "pro",
	}
	paymentRepo.CreatePayment(context.Background(), p1)

	payments, err := svc.GetPaymentHistory(context.Background(), userB)
	if err != nil {
		t.Fatalf("GetPaymentHistory: %v", err)
	}
	if len(payments) != 0 {
		t.Errorf("expected 0 payments for user B, got %d", len(payments))
	}
}

// ---------------------------------------------------------------------------
// Tests: VerifyStripeSignature
// ---------------------------------------------------------------------------

func TestVerifyStripeSignature_ValidSignature(t *testing.T) {
	secret := "whsec_abcdef1234567890"
	timestamp := fmt.Sprintf("%d", time.Now().Unix())
	payload := []byte(`{"type":"test","data":{}}`)

	signedPayload := timestamp + "." + string(payload)
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(signedPayload))
	sig := hex.EncodeToString(mac.Sum(nil))

	sigHeader := fmt.Sprintf("t=%s,v1=%s", timestamp, sig)

	if err := VerifyStripeSignature(payload, sigHeader, secret); err != nil {
		t.Errorf("expected valid signature, got error: %v", err)
	}
}

func TestVerifyStripeSignature_InvalidSignature(t *testing.T) {
	secret := "whsec_abcdef1234567890"
	sigHeader := "t=1234567890,v1=deadbeef"

	if err := VerifyStripeSignature([]byte("payload"), sigHeader, secret); err == nil {
		t.Error("expected error for invalid signature")
	}
}

func TestVerifyStripeSignature_MalformedHeader(t *testing.T) {
	secret := "whsec_abcdef1234567890"

	if err := VerifyStripeSignature([]byte("payload"), "malformed", secret); err == nil {
		t.Error("expected error for malformed header")
	}
}

func TestVerifyStripeSignature_EmptySecret(t *testing.T) {
	if err := VerifyStripeSignature([]byte("payload"), "t=1,v1=abc", ""); err == nil {
		t.Error("expected error for empty secret")
	}
}

func TestVerifyStripeSignature_TimestampTooOld(t *testing.T) {
	secret := "whsec_abcdef1234567890"
	// Timestamp 10 minutes ago.
	timestamp := fmt.Sprintf("%d", time.Now().Add(-10*time.Minute).Unix())
	payload := []byte(`{"type":"test"}`)

	signedPayload := timestamp + "." + string(payload)
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(signedPayload))
	sig := hex.EncodeToString(mac.Sum(nil))

	sigHeader := fmt.Sprintf("t=%s,v1=%s", timestamp, sig)

	if err := VerifyStripeSignature(payload, sigHeader, secret); err == nil {
		t.Error("expected error for old timestamp")
	}
}

// ---------------------------------------------------------------------------
// Tests: parseStripeSignatureHeader
// ---------------------------------------------------------------------------

func TestParseStripeSignatureHeader(t *testing.T) {
	tests := []struct {
		name    string
		header  string
		wantT   string
		wantV1  string
	}{
		{"standard", "t=1234567890,v1=abcdef", "1234567890", "abcdef"},
		{"with_spaces", "t=1234567890, v1=abcdef", "1234567890", "abcdef"},
		{"extra_fields", "t=123,v1=sig,v0=old", "123", "sig"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			parts := parseStripeSignatureHeader(tc.header)
			if parts["t"] != tc.wantT {
				t.Errorf("t = %q, want %q", parts["t"], tc.wantT)
			}
			if parts["v1"] != tc.wantV1 {
				t.Errorf("v1 = %q, want %q", parts["v1"], tc.wantV1)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Tests: completePayment edge cases
// ---------------------------------------------------------------------------

func TestPaymentService_CompletePayment_UpdateStatusError(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	paymentRepo.updateErr = errors.New("update failed")
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	userID := uuid.New()
	payment := &domain.Payment{
		UserID:          userID.String(),
		StripeSessionID: "cs_update_err",
		AmountCents:     499,
		Currency:        "usd",
		Status:          "pending",
		Plan:            "pro",
	}
	paymentRepo.CreatePayment(context.Background(), payment)

	event := map[string]interface{}{
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "cs_update_err"},
		},
	}
	payload, _ := json.Marshal(event)

	err := svc.HandleWebhook(context.Background(), payload, "")
	if err == nil {
		t.Error("expected error when UpdateStatus fails")
	}
}

func TestPaymentService_CompletePayment_TransactionError(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	paymentRepo.txErr = errors.New("transaction failed")
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "")

	userID := uuid.New()
	payment := &domain.Payment{
		UserID:          userID.String(),
		StripeSessionID: "cs_tx_err",
		AmountCents:     499,
		Currency:        "usd",
		Status:          "pending",
		Plan:            "pro",
	}
	paymentRepo.CreatePayment(context.Background(), payment)

	event := map[string]interface{}{
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "cs_tx_err"},
		},
	}
	payload, _ := json.Marshal(event)

	err := svc.HandleWebhook(context.Background(), payload, "")
	if err == nil {
		t.Error("expected error when CompletePaymentTx fails")
	}
}

// ---------------------------------------------------------------------------
// Tests: TestMode flag
// ---------------------------------------------------------------------------

func TestPaymentService_TestMode_WhenNoStripeClient(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	svc := NewPaymentService(paymentRepo, planRepo, nil, "whsecret")

	ps := svc.(*paymentService)
	if !ps.testMode {
		t.Error("expected testMode = true when stripeClient is nil")
	}
}

func TestPaymentService_TestMode_WhenStripeClientProvided(t *testing.T) {
	paymentRepo := newMockPaymentRepo()
	planRepo := &mockPlanRepo{plan: "free"}
	stripe := &mockStripeClient{}
	svc := NewPaymentService(paymentRepo, planRepo, stripe, "whsecret")

	ps := svc.(*paymentService)
	if ps.testMode {
		t.Error("expected testMode = false when stripeClient is provided")
	}
}
