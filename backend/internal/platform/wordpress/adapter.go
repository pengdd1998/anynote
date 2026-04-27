package wordpress

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/platform/common"
	"github.com/anynote/backend/internal/platform/httpclient"
)

// Adapter implements platform publishing for WordPress sites via the
// WordPress REST API with Application Passwords for authentication.
type Adapter struct{}

// NewAdapter creates a new WordPress adapter.
func NewAdapter() *Adapter {
	return &Adapter{}
}

func (a *Adapter) Name() string { return "wordpress" }

// wpAuthData is the internal structure for persisted WordPress credentials.
type wpAuthData struct {
	// SiteURL is the base URL of the WordPress site (e.g. "https://example.com").
	SiteURL string `json:"site_url"`
	// Username is the WordPress username.
	Username string `json:"username"`
	// AppPassword is the WordPress Application Password.
	AppPassword string `json:"app_password"`
}

// wpCredInput is the JSON payload sent to the client for credential entry.
type wpCredInput struct {
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

// ---------------------------------------------------------------------------
// Authentication: Application Passwords
// ---------------------------------------------------------------------------

// StartAuth returns a JSON payload instructing the client to collect
// WordPress site URL, username, and application password from the user.
func (a *Adapter) StartAuth(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
	input := wpCredInput{
		AuthType: "credentials_input",
		Message:  "Enter your WordPress site credentials",
		Fields: []struct {
			Name        string `json:"name"`
			Label       string `json:"label"`
			Type        string `json:"type"`
			Placeholder string `json:"placeholder"`
			Required    bool   `json:"required"`
		}{
			{Name: "site_url", Label: "Site URL", Type: "url", Placeholder: "https://example.com", Required: true},
			{Name: "username", Label: "Username", Type: "text", Placeholder: "admin", Required: true},
			{Name: "app_password", Label: "Application Password", Type: "password", Placeholder: "xxxx xxxx xxxx xxxx xxxx xxxx", Required: true},
		},
	}

	payloadBytes, err := json.Marshal(input)
	if err != nil {
		return nil, nil, fmt.Errorf("marshal credential input: %w", err)
	}

	authRef := fmt.Sprintf("wp-%d", time.Now().UnixMilli())

	return &platform.AuthSession{
		AuthRef: authRef,
	}, payloadBytes, nil
}

// PollAuth validates the WordPress credentials by calling the users/me
// endpoint.  The caller should pass the credentials (site_url, username,
// app_password) via the session CDPContext.
func (a *Adapter) PollAuth(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
	// For WordPress, the credentials are passed directly by the service layer
	// after the client submits them.  If CDPContext is nil, we are still
	// waiting for input.
	if session.CDPContext == nil {
		return nil, nil
	}

	credMap, ok := session.CDPContext.(map[string]string)
	if !ok {
		return nil, fmt.Errorf("invalid session: expected credential map")
	}

	siteURL := strings.TrimRight(credMap["site_url"], "/")
	username := credMap["username"]
	appPassword := credMap["app_password"]

	if siteURL == "" || username == "" || appPassword == "" {
		return nil, fmt.Errorf("missing required credential fields")
	}

	// Validate credentials by calling the WordPress REST API users/me endpoint.
	meURL := siteURL + "/wp-json/wp/v2/users/me"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, meURL, nil)
	if err != nil {
		return nil, fmt.Errorf("create validation request: %w", err)
	}
	req.SetBasicAuth(username, appPassword)
	req.Header.Set("Accept", "application/json")

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return nil, fmt.Errorf("validate credentials: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, err := io.ReadAll(io.LimitReader(resp.Body, 1*1024*1024))
		if err != nil {
			return nil, fmt.Errorf("reading credentials validation error response body: %w", err)
		}
		return nil, fmt.Errorf("invalid credentials (status %d): %s", resp.StatusCode, string(body))
	}

	// Credentials are valid.  Encrypt and return.
	authData := wpAuthData{
		SiteURL:     siteURL,
		Username:    username,
		AppPassword: appPassword,
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

// Publish creates a new post on the WordPress site via the REST API.
// It decrypts the stored auth data and POSTs to the posts endpoint.
func (a *Adapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
	var authData wpAuthData
	if err := common.DecryptAuth(ctx, encryptedAuth, masterKey, &authData); err != nil {
		return nil, err
	}

	// Build the WordPress post payload.
	// WordPress REST API: POST /wp-json/wp/v2/posts
	body := map[string]interface{}{
		"title":   params.Title,
		"content": params.Content,
		"status":  "publish",
	}
	if len(params.Tags) > 0 {
		// WordPress expects tag names.  We pass them as strings; WordPress
		// will create the tags if they do not exist.
		body["tags"] = params.Tags
	}

	bodyJSON, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("marshal post body: %w", err)
	}

	postURL := authData.SiteURL + "/wp-json/wp/v2/posts"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, postURL, bytes.NewReader(bodyJSON))
	if err != nil {
		return nil, fmt.Errorf("create post request: %w", err)
	}
	req.SetBasicAuth(authData.Username, authData.AppPassword)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return nil, fmt.Errorf("publish request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1*1024*1024))
		if err != nil {
			return nil, fmt.Errorf("reading publish error response body: %w", err)
		}
		return nil, fmt.Errorf("publish failed (status %d): %s", resp.StatusCode, string(respBody))
	}

	var postResp struct {
		ID      int    `json:"id"`
		Link    string `json:"link"`
		Status  string `json:"status"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&postResp); err != nil {
		return nil, fmt.Errorf("decode publish response: %w", err)
	}

	return &platform.PublishResult{
		PlatformURL: postResp.Link,
		PlatformID:  fmt.Sprintf("%d", postResp.ID),
	}, nil
}

// ---------------------------------------------------------------------------
// Status check
// ---------------------------------------------------------------------------

// CheckStatus checks whether a WordPress post is still live by fetching
// the post via the REST API.
func (a *Adapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	var authData wpAuthData
	if err := common.DecryptAuth(ctx, encryptedAuth, masterKey, &authData); err != nil {
		return "unknown", err
	}

	postURL := authData.SiteURL + "/wp-json/wp/v2/posts/" + platformID
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, postURL, nil)
	if err != nil {
		return "unknown", fmt.Errorf("create status request: %w", err)
	}
	req.SetBasicAuth(authData.Username, authData.AppPassword)
	req.Header.Set("Accept", "application/json")

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return "unknown", fmt.Errorf("status request: %w", err)
	}
	defer resp.Body.Close()

	switch resp.StatusCode {
	case http.StatusOK:
		var postResp struct {
			Status string `json:"status"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&postResp); err != nil {
			return "unknown", fmt.Errorf("decode status response: %w", err)
		}
		switch postResp.Status {
		case "publish":
			return "live", nil
		case "draft", "pending":
			return "live", nil // Post exists but is not publicly published.
		case "trash":
			return "removed", nil
		default:
			return "unknown", nil
		}
	case http.StatusNotFound:
		return "removed", nil
	default:
		return "unknown", nil
	}
}

// ---------------------------------------------------------------------------
// Revoke auth
// ---------------------------------------------------------------------------

// RevokeAuth attempts to revoke the WordPress application password.
// WordPress supports deleting application passwords via the REST API.
func (a *Adapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	var authData wpAuthData
	if err := common.DecryptAuth(ctx, encryptedAuth, masterKey, &authData); err != nil {
		return err
	}

	// WordPress allows listing and deleting application passwords via
	// the REST API.  We need to find the app password slug to delete it.
	// GET /wp-json/wp/v2/users/me/application-passwords
	listURL := authData.SiteURL + "/wp-json/wp/v2/users/me/application-passwords"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, listURL, nil)
	if err != nil {
		return fmt.Errorf("create list app passwords request: %w", err)
	}
	req.SetBasicAuth(authData.Username, authData.AppPassword)
	req.Header.Set("Accept", "application/json")

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		// Non-fatal: if we cannot reach the site, the caller still deletes
		// the persisted data.
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		// Cannot list passwords; return nil so the caller proceeds with
		// deleting the local data.
		return nil
	}

	var appPasswords []struct {
		UUID string `json:"uuid"`
		Name string `json:"name"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&appPasswords); err != nil {
		return nil
	}

	// Try to find and delete the application password that matches.
	// We delete all application passwords named "AnyNote" or a similar pattern.
	for _, ap := range appPasswords {
		if strings.Contains(strings.ToLower(ap.Name), "anynote") {
			deleteURL := authData.SiteURL + "/wp-json/wp/v2/users/me/application-passwords/" + ap.UUID
			delReq, err := http.NewRequestWithContext(ctx, http.MethodDelete, deleteURL, nil)
			if err != nil {
				continue
			}
			delReq.SetBasicAuth(authData.Username, authData.AppPassword)
			httpclient.Shared.Do(delReq)
		}
	}

	return nil
}
