// Package stripeadapter provides a Stripe client adapter implementing the
// service.StripeClient interface for production payment processing.
package stripeadapter

import (
	"context"
	"fmt"

	stripe "github.com/stripe/stripe-go/v82"
	"github.com/stripe/stripe-go/v82/checkout/session"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/service"
)

// Compile-time check that StripeAdapter satisfies service.StripeClient.
var _ service.StripeClient = (*StripeAdapter)(nil)

// InitStripeClient initializes a production Stripe client.
// Returns an error if required configuration is missing.
func InitStripeClient(cfg config.StripeConfig) (*StripeAdapter, error) {
	if cfg.SecretKey == "" {
		return nil, fmt.Errorf("stripe secret key is required")
	}
	if cfg.ProPriceID == "" {
		return nil, fmt.Errorf("stripe pro price ID is required")
	}
	if cfg.LifetimePriceID == "" {
		return nil, fmt.Errorf("stripe lifetime price ID is required")
	}

	stripe.Key = cfg.SecretKey
	return &StripeAdapter{
		proPriceID:      cfg.ProPriceID,
		lifetimePriceID: cfg.LifetimePriceID,
	}, nil
}

// StripeAdapter implements service.StripeClient using the Stripe Go SDK.
type StripeAdapter struct {
	proPriceID      string
	lifetimePriceID string
}

// CreateCheckoutSession creates a Stripe Checkout Session for the given plan.
func (a *StripeAdapter) CreateCheckoutSession(
	ctx context.Context,
	userID, plan, successURL, cancelURL string,
) (sessionID, sessionURL string, err error) {
	priceID, mode, err := a.planConfig(plan)
	if err != nil {
		return "", "", err
	}

	params := &stripe.CheckoutSessionParams{
		Mode:              stripe.String(mode),
		ClientReferenceID: stripe.String(userID),
		SuccessURL:        stripe.String(successURL),
		CancelURL:         stripe.String(cancelURL),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				Price:    stripe.String(priceID),
				Quantity: stripe.Int64(1),
			},
		},
	}

	s, err := session.New(params)
	if err != nil {
		return "", "", fmt.Errorf("stripe checkout session create: %w", err)
	}

	return s.ID, s.URL, nil
}

// planConfig returns the Stripe Price ID and Checkout mode for the given plan name.
func (a *StripeAdapter) planConfig(plan string) (priceID, mode string, err error) {
	switch plan {
	case "pro":
		return a.proPriceID, string(stripe.CheckoutSessionModeSubscription), nil
	case "lifetime":
		return a.lifetimePriceID, string(stripe.CheckoutSessionModePayment), nil
	default:
		return "", "", fmt.Errorf("unsupported plan: %s", plan)
	}
}
