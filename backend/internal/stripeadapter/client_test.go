package stripeadapter

import (
	"testing"

	"github.com/anynote/backend/internal/config"
)

func TestInitStripeClient_MissingSecretKey(t *testing.T) {
	_, err := InitStripeClient(config.StripeConfig{
		ProPriceID:      "price_pro",
		LifetimePriceID: "price_lifetime",
	})
	if err == nil {
		t.Fatal("expected error for missing secret key")
	}
}

func TestInitStripeClient_MissingProPriceID(t *testing.T) {
	_, err := InitStripeClient(config.StripeConfig{
		SecretKey:       "sk_test_xxx",
		LifetimePriceID: "price_lifetime",
	})
	if err == nil {
		t.Fatal("expected error for missing pro price ID")
	}
}

func TestInitStripeClient_MissingLifetimePriceID(t *testing.T) {
	_, err := InitStripeClient(config.StripeConfig{
		SecretKey:  "sk_test_xxx",
		ProPriceID: "price_pro",
	})
	if err == nil {
		t.Fatal("expected error for missing lifetime price ID")
	}
}

func TestInitStripeClient_Success(t *testing.T) {
	adapter, err := InitStripeClient(config.StripeConfig{
		SecretKey:       "sk_test_xxx",
		ProPriceID:      "price_pro",
		LifetimePriceID: "price_lifetime",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if adapter == nil {
		t.Fatal("expected non-nil adapter")
	}
}

func TestPlanConfig(t *testing.T) {
	adapter := &StripeAdapter{
		proPriceID:      "price_pro",
		lifetimePriceID: "price_lifetime",
	}

	tests := []struct {
		plan        string
		wantPriceID string
		wantMode    string
		wantErr     bool
	}{
		{"pro", "price_pro", "subscription", false},
		{"lifetime", "price_lifetime", "payment", false},
		{"invalid", "", "", true},
	}

	for _, tt := range tests {
		t.Run(tt.plan, func(t *testing.T) {
			priceID, mode, err := adapter.planConfig(tt.plan)
			if (err != nil) != tt.wantErr {
				t.Errorf("planConfig(%q) error = %v, wantErr %v", tt.plan, err, tt.wantErr)
				return
			}
			if priceID != tt.wantPriceID {
				t.Errorf("planConfig(%q) priceID = %q, want %q", tt.plan, priceID, tt.wantPriceID)
			}
			if mode != tt.wantMode {
				t.Errorf("planConfig(%q) mode = %q, want %q", tt.plan, mode, tt.wantMode)
			}
		})
	}
}
