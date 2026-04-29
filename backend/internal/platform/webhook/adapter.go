// Package webhook implements a generic webhook platform adapter for publishing content.
package webhook

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/platform/httpclient"
)

// Adapter implements platform publishing via generic webhooks.
// This is a fire-and-forget adapter that POSTs a JSON payload to a
// user-configured endpoint.
type Adapter struct{}

// NewAdapter creates a new webhook adapter.
func NewAdapter() *Adapter {
	return &Adapter{}
}

func (a *Adapter) Name() string { return "webhook" }

// webhookAuthData is the internal structure for persisted webhook config.
type webhookAuthData struct {
	// URL is the webhook endpoint URL.
	URL string `json:"url"`
	// Secret is an optional shared secret sent as a header for verification.
	Secret string `json:"secret,omitempty"`
	// Headers are additional custom headers to include in requests.
	Headers map[string]string `json:"headers,omitempty"`
}

// webhookCredInput is the JSON payload sent to the client for URL input.
type webhookCredInput struct {
	AuthType string `json:"auth_type"`
	Message  string `json:"message"`
	Fields   []struct {
		Name        string `json:"name"`
		Label       string `json:"label"`
		Type        string `json:"type"`
		Placeholder string `json:"placeholder"`
		Required    bool   `json:"required"`
	} `json:"fields"`
}

// webhookPayload is the JSON structure sent to the webhook endpoint.
type webhookPayload struct {
	Title       string   `json:"title"`
	Content     string   `json:"content"`
	Tags        []string `json:"tags"`
	Platform    string   `json:"platform"`
	PublishedAt string   `json:"published_at"`
}

// ---------------------------------------------------------------------------
// Authentication: URL input
// ---------------------------------------------------------------------------

// StartAuth returns a JSON payload instructing the client to collect the
// webhook endpoint URL and optional secret from the user.
func (a *Adapter) StartAuth(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
	input := webhookCredInput{
		AuthType: "credentials_input",
		Message:  "Enter your webhook endpoint URL",
		Fields: []struct {
			Name        string `json:"name"`
			Label       string `json:"label"`
			Type        string `json:"type"`
			Placeholder string `json:"placeholder"`
			Required    bool   `json:"required"`
		}{
			{Name: "url", Label: "Webhook URL", Type: "url", Placeholder: "https://example.com/webhook", Required: true},
			{Name: "secret", Label: "Secret (optional)", Type: "password", Placeholder: "Shared secret for HMAC or Bearer token", Required: false},
		},
	}

	payloadBytes, err := json.Marshal(input)
	if err != nil {
		return nil, nil, fmt.Errorf("marshal credential input: %w", err)
	}

	authRef := fmt.Sprintf("webhook-%d", time.Now().UnixMilli())

	return &platform.AuthSession{
		AuthRef: authRef,
	}, payloadBytes, nil
}

// PollAuth validates the webhook endpoint by sending a test request.
// The caller should pass the URL and optional secret via the session CDPContext.
func (a *Adapter) PollAuth(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
	// For webhooks, the URL and secret are passed directly by the service
	// layer after the client submits them.
	if session.CDPContext == nil {
		return nil, nil
	}

	credMap, ok := session.CDPContext.(map[string]string)
	if !ok {
		return nil, fmt.Errorf("invalid session: expected credential map")
	}

	webhookURL := credMap["url"]
	secret := credMap["secret"]

	if webhookURL == "" {
		return nil, fmt.Errorf("webhook URL is required")
	}

	// Validate the endpoint by sending a test request.
	// We send a GET or HEAD request to verify the endpoint is reachable.
	// Some webhook endpoints only accept POST, so we try POST with an
	// empty test payload.
	testPayload := map[string]interface{}{
		"test":    true,
		"message": "AnyNote webhook verification",
	}
	testJSON, err := json.Marshal(testPayload)
	if err != nil {
		return nil, fmt.Errorf("marshal test payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, webhookURL, bytes.NewReader(testJSON))
	if err != nil {
		return nil, fmt.Errorf("create test request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "AnyNote-Webhook/1.0")
	if secret != "" {
		req.Header.Set("X-Webhook-Secret", secret)
	}

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return nil, fmt.Errorf("webhook endpoint unreachable: %w", err)
	}
	defer resp.Body.Close()

	// Accept any 2xx response as success.
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return nil, fmt.Errorf("webhook endpoint returned status %d: %s", resp.StatusCode, string(body))
	}

	// Endpoint is valid.  Encrypt and return.
	authData := webhookAuthData{
		URL:    webhookURL,
		Secret: secret,
	}

	authJSON, err := json.Marshal(authData)
	if err != nil {
		return nil, fmt.Errorf("marshal auth data: %w", err)
	}

	// Encrypt the auth data using AES-256-GCM.
	encrypted, err := llm.EncryptAPIKey(string(authJSON), masterKey)
	if err != nil {
		return nil, fmt.Errorf("encrypt auth data: %w", err)
	}

	return encrypted, nil
}

// ---------------------------------------------------------------------------
// Publishing
// ---------------------------------------------------------------------------

// Publish sends a JSON payload to the configured webhook endpoint.
func (a *Adapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
	// Decrypt auth data.
	authJSON, err := llm.DecryptAPIKey(encryptedAuth, masterKey)
	if err != nil {
		return nil, fmt.Errorf("decrypt auth data: %w", err)
	}

	var authData webhookAuthData
	if err := json.Unmarshal([]byte(authJSON), &authData); err != nil {
		return nil, fmt.Errorf("unmarshal auth data: %w", err)
	}

	// Build the webhook payload.
	payload := webhookPayload{
		Title:       params.Title,
		Content:     params.Content,
		Tags:        params.Tags,
		Platform:    "webhook",
		PublishedAt: time.Now().UTC().Format(time.RFC3339),
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal webhook payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, authData.URL, bytes.NewReader(payloadJSON))
	if err != nil {
		return nil, fmt.Errorf("create webhook request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "AnyNote-Webhook/1.0")
	if authData.Secret != "" {
		req.Header.Set("X-Webhook-Secret", authData.Secret)
	}
	// Set any custom headers.
	for k, v := range authData.Headers {
		req.Header.Set(k, v)
	}

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return nil, fmt.Errorf("webhook request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return nil, fmt.Errorf("webhook returned status %d: %s", resp.StatusCode, string(body))
	}

	// Webhook is fire-and-forget.  Generate a platform ID from the timestamp.
	platformID := fmt.Sprintf("webhook-%d", time.Now().UnixMilli())

	return &platform.PublishResult{
		PlatformURL: authData.URL,
		PlatformID:  platformID,
	}, nil
}

// ---------------------------------------------------------------------------
// Status check
// ---------------------------------------------------------------------------

// CheckStatus assumes success for webhooks since they are fire-and-forget.
// We have no way to verify delivery status after the fact.
func (a *Adapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	// Webhooks are fire-and-forget.  We assume success after publish.
	return "live", nil
}

// ---------------------------------------------------------------------------
// Revoke auth
// ---------------------------------------------------------------------------

// RevokeAuth is a no-op for webhooks.  There is no server-side session to
// revoke.  The caller is responsible for deleting the persisted auth data.
func (a *Adapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	// Webhooks have no server-side session to revoke.
	// The caller (service layer) will delete the stored encrypted_auth
	// from the platform_connections table.
	return nil
}

// ensure the adapter satisfies the interface at compile time.
var _ platform.Adapter = (*Adapter)(nil)
