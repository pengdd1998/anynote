package domain

import (
	"encoding/json"
	"testing"
	"time"
)

// ---------------------------------------------------------------------------
// Payment JSON round-trip tests
// ---------------------------------------------------------------------------

func TestPayment_JSONRoundTrip(t *testing.T) {
	now := time.Now().Truncate(time.Millisecond)
	completedAt := now.Add(5 * time.Minute)
	p := Payment{
		ID:              "pay-123",
		UserID:          "user-456",
		StripeSessionID: "cs_test_abc",
		AmountCents:     499,
		Currency:        "usd",
		Status:          "completed",
		Plan:            "pro",
		CreatedAt:       now,
		CompletedAt:     &completedAt,
	}

	data, err := json.Marshal(p)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var decoded Payment
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if decoded.ID != p.ID {
		t.Errorf("ID = %q, want %q", decoded.ID, p.ID)
	}
	if decoded.UserID != p.UserID {
		t.Errorf("UserID = %q, want %q", decoded.UserID, p.UserID)
	}
	if decoded.StripeSessionID != p.StripeSessionID {
		t.Errorf("StripeSessionID = %q, want %q", decoded.StripeSessionID, p.StripeSessionID)
	}
	if decoded.AmountCents != p.AmountCents {
		t.Errorf("AmountCents = %d, want %d", decoded.AmountCents, p.AmountCents)
	}
	if decoded.Currency != p.Currency {
		t.Errorf("Currency = %q, want %q", decoded.Currency, p.Currency)
	}
	if decoded.Status != p.Status {
		t.Errorf("Status = %q, want %q", decoded.Status, p.Status)
	}
	if decoded.Plan != p.Plan {
		t.Errorf("Plan = %q, want %q", decoded.Plan, p.Plan)
	}
	if decoded.CompletedAt == nil {
		t.Error("CompletedAt should not be nil")
	}
}

func TestPayment_NilCompletedAt_Omitted(t *testing.T) {
	p := Payment{
		ID:        "pay-789",
		UserID:    "user-abc",
		Status:    "pending",
		CreatedAt: time.Now(),
	}

	data, err := json.Marshal(p)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	// "completed_at" should be omitted when nil (omitempty).
	var raw map[string]interface{}
	json.Unmarshal(data, &raw)
	if _, ok := raw["completed_at"]; ok {
		t.Error("completed_at should be omitted when nil")
	}
}

func TestPayment_ZeroAmountCents(t *testing.T) {
	p := Payment{AmountCents: 0}
	data, _ := json.Marshal(p)
	var decoded Payment
	json.Unmarshal(data, &decoded)
	if decoded.AmountCents != 0 {
		t.Errorf("AmountCents = %d, want 0", decoded.AmountCents)
	}
}

// ---------------------------------------------------------------------------
// CreateCheckoutRequest JSON tests
// ---------------------------------------------------------------------------

func TestCreateCheckoutRequest_JSONRoundTrip(t *testing.T) {
	req := CreateCheckoutRequest{
		Plan:       "pro",
		SuccessURL: "https://app.test/success",
		CancelURL:  "https://app.test/cancel",
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var decoded CreateCheckoutRequest
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if decoded.Plan != req.Plan {
		t.Errorf("Plan = %q, want %q", decoded.Plan, req.Plan)
	}
	if decoded.SuccessURL != req.SuccessURL {
		t.Errorf("SuccessURL = %q, want %q", decoded.SuccessURL, req.SuccessURL)
	}
	if decoded.CancelURL != req.CancelURL {
		t.Errorf("CancelURL = %q, want %q", decoded.CancelURL, req.CancelURL)
	}
}

// ---------------------------------------------------------------------------
// CheckoutResponse JSON tests
// ---------------------------------------------------------------------------

func TestCheckoutResponse_JSONRoundTrip(t *testing.T) {
	resp := CheckoutResponse{SessionURL: "https://checkout.stripe.com/abc"}
	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var decoded CheckoutResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if decoded.SessionURL != resp.SessionURL {
		t.Errorf("SessionURL = %q, want %q", decoded.SessionURL, resp.SessionURL)
	}
}

// ---------------------------------------------------------------------------
// Notification JSON round-trip tests
// ---------------------------------------------------------------------------

func TestNotification_JSONRoundTrip(t *testing.T) {
	n := Notification{
		ID:        "notif-123",
		UserID:    "user-456",
		Type:      "payment",
		Title:     "Payment received",
		Body:      "Your pro plan is now active",
		Data:      json.RawMessage(`{"plan":"pro"}`),
		IsRead:    false,
		CreatedAt: time.Now().Truncate(time.Millisecond),
	}

	data, err := json.Marshal(n)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var decoded Notification
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if decoded.ID != n.ID {
		t.Errorf("ID = %q, want %q", decoded.ID, n.ID)
	}
	if decoded.UserID != n.UserID {
		t.Errorf("UserID = %q, want %q", decoded.UserID, n.UserID)
	}
	if decoded.Type != n.Type {
		t.Errorf("Type = %q, want %q", decoded.Type, n.Type)
	}
	if decoded.Title != n.Title {
		t.Errorf("Title = %q, want %q", decoded.Title, n.Title)
	}
	if decoded.Body != n.Body {
		t.Errorf("Body = %q, want %q", decoded.Body, n.Body)
	}
	if decoded.IsRead != n.IsRead {
		t.Errorf("IsRead = %v, want %v", decoded.IsRead, n.IsRead)
	}
	if string(decoded.Data) != string(n.Data) {
		t.Errorf("Data = %q, want %q", string(decoded.Data), string(n.Data))
	}
}

func TestNotification_IsReadTrue(t *testing.T) {
	n := Notification{IsRead: true}
	data, _ := json.Marshal(n)
	var decoded Notification
	json.Unmarshal(data, &decoded)
	if !decoded.IsRead {
		t.Error("IsRead should be true")
	}
}

func TestNotification_EmptyData(t *testing.T) {
	n := Notification{
		Data: json.RawMessage(`{}`),
	}
	data, _ := json.Marshal(n)
	var decoded Notification
	json.Unmarshal(data, &decoded)
	if string(decoded.Data) != `{}` {
		t.Errorf("Data = %q, want {}", string(decoded.Data))
	}
}

func TestNotification_ComplexData(t *testing.T) {
	complexData := `{"nested":{"key":"value"},"array":[1,2,3]}`
	n := Notification{
		Data: json.RawMessage(complexData),
	}
	data, _ := json.Marshal(n)
	var decoded Notification
	json.Unmarshal(data, &decoded)
	if string(decoded.Data) != complexData {
		t.Errorf("Data = %q, want %q", string(decoded.Data), complexData)
	}
}
