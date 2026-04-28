package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
	"github.com/anynote/backend/internal/testutil"
)

// ---------------------------------------------------------------------------
// Mock PaymentService
// ---------------------------------------------------------------------------

type mockPaymentService struct {
	checkoutFn func(ctx context.Context, userID string, req domain.CreateCheckoutRequest) (*domain.CheckoutResponse, error)
	webhookFn  func(ctx context.Context, payload []byte, sig string) error
	historyFn  func(ctx context.Context, userID string) ([]domain.Payment, error)
}

func (m *mockPaymentService) CreateCheckoutSession(ctx context.Context, userID string, req domain.CreateCheckoutRequest) (*domain.CheckoutResponse, error) {
	if m.checkoutFn != nil {
		return m.checkoutFn(ctx, userID, req)
	}
	return &domain.CheckoutResponse{SessionURL: "https://checkout.test/session123"}, nil
}

func (m *mockPaymentService) HandleWebhook(ctx context.Context, payload []byte, sig string) error {
	if m.webhookFn != nil {
		return m.webhookFn(ctx, payload, sig)
	}
	return nil
}

func (m *mockPaymentService) GetPaymentHistory(ctx context.Context, userID string) ([]domain.Payment, error) {
	if m.historyFn != nil {
		return m.historyFn(ctx, userID)
	}
	return []domain.Payment{}, nil
}

// ---------------------------------------------------------------------------
// Router setup helper
// ---------------------------------------------------------------------------

func setupPaymentRouter(svc service.PaymentService) *chi.Mux {
	r := chi.NewRouter()
	h := NewPaymentHandler(svc)
	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testutil.DefaultTestJWTSecret))
		r.Post("/api/v1/payments/checkout", h.CreateCheckout)
		r.Get("/api/v1/payments", h.GetPaymentHistory)
	})
	r.Post("/api/v1/payments/webhook", h.HandleWebhook)
	return r
}

// ---------------------------------------------------------------------------
// Tests: CreateCheckout
// ---------------------------------------------------------------------------

func TestPaymentHandler_CreateCheckout_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	body, _ := json.Marshal(domain.CreateCheckoutRequest{
		Plan:       "pro",
		SuccessURL: "https://app.test/success",
		CancelURL:  "https://app.test/cancel",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/checkout", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var resp domain.CheckoutResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.SessionURL == "" {
		t.Error("SessionURL should not be empty")
	}
}

func TestPaymentHandler_CreateCheckout_InvalidPlan(t *testing.T) {
	userID := uuid.New()
	svc := &mockPaymentService{
		checkoutFn: func(_ context.Context, _ string, _ domain.CreateCheckoutRequest) (*domain.CheckoutResponse, error) {
			return nil, service.ErrInvalidPaymentPlan
		},
	}
	router := setupPaymentRouter(svc)

	body, _ := json.Marshal(domain.CreateCheckoutRequest{Plan: "enterprise"})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/checkout", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestPaymentHandler_CreateCheckout_EmptyPlan(t *testing.T) {
	userID := uuid.New()
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	body, _ := json.Marshal(domain.CreateCheckoutRequest{Plan: ""})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/checkout", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestPaymentHandler_CreateCheckout_InvalidJSON(t *testing.T) {
	userID := uuid.New()
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/checkout", bytes.NewReader([]byte("invalid")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestPaymentHandler_CreateCheckout_Unauthorized(t *testing.T) {
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	body, _ := json.Marshal(domain.CreateCheckoutRequest{Plan: "pro"})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/checkout", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	// No Authorization header.
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestPaymentHandler_CreateCheckout_ServiceError(t *testing.T) {
	userID := uuid.New()
	svc := &mockPaymentService{
		checkoutFn: func(_ context.Context, _ string, _ domain.CreateCheckoutRequest) (*domain.CheckoutResponse, error) {
			return nil, errors.New("internal error")
		},
	}
	router := setupPaymentRouter(svc)

	body, _ := json.Marshal(domain.CreateCheckoutRequest{Plan: "pro"})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/checkout", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: HandleWebhook
// ---------------------------------------------------------------------------

func TestPaymentHandler_HandleWebhook_Success(t *testing.T) {
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	payload, _ := json.Marshal(map[string]interface{}{
		"type": "checkout.session.completed",
		"data": map[string]interface{}{
			"object": map[string]interface{}{"id": "cs_test_123"},
		},
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/webhook", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Stripe-Signature", "t=123,v1=abc")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestPaymentHandler_HandleWebhook_MissingSignature(t *testing.T) {
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/webhook", bytes.NewReader([]byte(`{}`)))
	req.Header.Set("Content-Type", "application/json")
	// No Stripe-Signature header.
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestPaymentHandler_HandleWebhook_InvalidSignature(t *testing.T) {
	svc := &mockPaymentService{
		webhookFn: func(_ context.Context, _ []byte, _ string) error {
			return service.ErrInvalidStripeSig
		},
	}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/webhook", bytes.NewReader([]byte(`{}`)))
	req.Header.Set("Stripe-Signature", "t=1,v1=bad")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestPaymentHandler_HandleWebhook_PaymentNotFound(t *testing.T) {
	svc := &mockPaymentService{
		webhookFn: func(_ context.Context, _ []byte, _ string) error {
			return service.ErrPaymentNotFound
		},
	}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/webhook", bytes.NewReader([]byte(`{}`)))
	req.Header.Set("Stripe-Signature", "t=1,v1=abc")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestPaymentHandler_HandleWebhook_AlreadyProcessed(t *testing.T) {
	svc := &mockPaymentService{
		webhookFn: func(_ context.Context, _ []byte, _ string) error {
			return service.ErrPaymentAlreadyDone
		},
	}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/webhook", bytes.NewReader([]byte(`{}`)))
	req.Header.Set("Stripe-Signature", "t=1,v1=abc")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for already processed, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

func TestPaymentHandler_HandleWebhook_InternalError(t *testing.T) {
	svc := &mockPaymentService{
		webhookFn: func(_ context.Context, _ []byte, _ string) error {
			return errors.New("internal error")
		},
	}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/webhook", bytes.NewReader([]byte(`{}`)))
	req.Header.Set("Stripe-Signature", "t=1,v1=abc")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GetPaymentHistory
// ---------------------------------------------------------------------------

func TestPaymentHandler_GetPaymentHistory_Success(t *testing.T) {
	userID := uuid.New()
	svc := &mockPaymentService{
		historyFn: func(_ context.Context, uid string) ([]domain.Payment, error) {
			return []domain.Payment{
				{ID: "p1", UserID: uid, AmountCents: 499, Status: "completed", Plan: "pro"},
			}, nil
		},
	}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/payments", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]interface{}
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	payments, ok := resp["payments"].([]interface{})
	if !ok || len(payments) != 1 {
		t.Errorf("expected 1 payment, got %v", resp["payments"])
	}
}

func TestPaymentHandler_GetPaymentHistory_Empty(t *testing.T) {
	userID := uuid.New()
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/payments", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]interface{}
	json.NewDecoder(rec.Body).Decode(&resp)
	payments, ok := resp["payments"].([]interface{})
	if !ok || len(payments) != 0 {
		t.Errorf("expected 0 payments, got %v", resp["payments"])
	}
}

func TestPaymentHandler_GetPaymentHistory_Unauthorized(t *testing.T) {
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/payments", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

func TestPaymentHandler_GetPaymentHistory_ServiceError(t *testing.T) {
	userID := uuid.New()
	svc := &mockPaymentService{
		historyFn: func(_ context.Context, _ string) ([]domain.Payment, error) {
			return nil, errors.New("db error")
		},
	}
	router := setupPaymentRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/payments", nil)
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: Webhook requires no auth
// ---------------------------------------------------------------------------

func TestPaymentHandler_Webhook_NoAuthRequired(t *testing.T) {
	svc := &mockPaymentService{}
	router := setupPaymentRouter(svc)

	payload := []byte(`{"type":"checkout.session.completed","data":{"object":{"id":"cs_123"}}}`)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/webhook", bytes.NewReader(payload))
	req.Header.Set("Stripe-Signature", "t=1,v1=abc")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	// Should not be 401 (unauthorized) -- webhook is public.
	if rec.Code == http.StatusUnauthorized {
		t.Error("webhook endpoint should not require authentication")
	}
}

// ---------------------------------------------------------------------------
// Tests: Checkout passes correct userID
// ---------------------------------------------------------------------------

func TestPaymentHandler_CreateCheckout_PassesUserID(t *testing.T) {
	userID := uuid.New()
	var capturedUserID string
	svc := &mockPaymentService{
		checkoutFn: func(_ context.Context, uid string, _ domain.CreateCheckoutRequest) (*domain.CheckoutResponse, error) {
			capturedUserID = uid
			return &domain.CheckoutResponse{SessionURL: "https://checkout.test/123"}, nil
		},
	}
	router := setupPaymentRouter(svc)

	body, _ := json.Marshal(domain.CreateCheckoutRequest{Plan: "pro"})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/payments/checkout", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+testutil.GenerateAccessToken(t, userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if capturedUserID != userID.String() {
		t.Errorf("service received userID = %q, want %q", capturedUserID, userID.String())
	}
}
