package handler

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// PaymentHandler handles payment-related HTTP endpoints.
type PaymentHandler struct {
	paymentSvc service.PaymentService
}

// NewPaymentHandler creates a new PaymentHandler.
func NewPaymentHandler(paymentSvc service.PaymentService) *PaymentHandler {
	return &PaymentHandler{paymentSvc: paymentSvc}
}

// CreateCheckout handles POST /api/v1/payments/checkout.
// Creates a Stripe checkout session and returns the session URL.
func (h *PaymentHandler) CreateCheckout(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	var req domain.CreateCheckoutRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid_request", "Failed to parse request body")
		return
	}

	if req.Plan == "" {
		writeError(w, r, http.StatusBadRequest, "validation_error", "plan is required")
		return
	}

	resp, err := h.paymentSvc.CreateCheckoutSession(r.Context(), userID.String(), req)
	if err != nil {
		if err == service.ErrInvalidPaymentPlan {
			writeError(w, r, http.StatusBadRequest, "invalid_plan", "Plan must be one of: pro, lifetime")
			return
		}
		slog.Error("checkout creation failed", "error", err, "user_id", userID)
		writeError(w, r, http.StatusInternalServerError, "checkout_error", "Failed to create checkout session")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

// HandleWebhook handles POST /api/v1/payments/webhook.
// Processes Stripe webhook events. This endpoint does NOT require authentication
// because Stripe calls it directly.
func (h *PaymentHandler) HandleWebhook(w http.ResponseWriter, r *http.Request) {
	payload, err := io.ReadAll(r.Body)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "read_error", "Failed to read request body")
		return
	}
	defer r.Body.Close()

	sig := r.Header.Get("Stripe-Signature")
	if sig == "" {
		writeError(w, r, http.StatusBadRequest, "missing_signature", "Stripe-Signature header required")
		return
	}

	if err := h.paymentSvc.HandleWebhook(r.Context(), payload, sig); err != nil {
		if err == service.ErrInvalidStripeSig {
			writeError(w, r, http.StatusBadRequest, "invalid_signature", "Invalid webhook signature")
			return
		}
		if err == service.ErrPaymentNotFound {
			writeError(w, r, http.StatusNotFound, "not_found", "Payment not found")
			return
		}
		if err == service.ErrPaymentAlreadyDone {
			// Idempotent: return 200 for already-processed webhooks.
			writeJSON(w, http.StatusOK, map[string]string{"status": "already_processed"})
			return
		}
		slog.Error("webhook processing failed", "error", err)
		writeError(w, r, http.StatusInternalServerError, "webhook_error", "Webhook processing failed")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "processed"})
}

// GetPaymentHistory handles GET /api/v1/payments.
// Returns the payment history for the authenticated user.
func (h *PaymentHandler) GetPaymentHistory(w http.ResponseWriter, r *http.Request) {
	userID, err := parseUserID(r)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "")
		return
	}

	payments, err := h.paymentSvc.GetPaymentHistory(r.Context(), userID.String())
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "history_error", "Failed to get payment history")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"payments": payments,
	})
}
