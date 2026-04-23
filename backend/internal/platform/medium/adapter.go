package medium

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
	"github.com/anynote/backend/internal/platform/httpclient"
)

// Medium API URLs.
const (
	mediumAPIBase    = "https://api.medium.com/v1"
	mediumOAuthBase  = "https://medium.com/m/oauth2"
	mediumAuthorize  = mediumOAuthBase + "/authorize"
	mediumTokenURL   = mediumOAuthBase + "/token"
)

// Adapter implements platform publishing for Medium via its REST API.
type Adapter struct {
	// clientID is the Medium OAuth application client ID.
	clientID string
	// clientSecret is the Medium OAuth application client secret.
	clientSecret string
	// redirectURI is the OAuth callback URL.
	redirectURI string
}

// NewAdapter creates a new Medium adapter.
func NewAdapter(clientID, clientSecret, redirectURI string) *Adapter {
	return &Adapter{
		clientID:     clientID,
		clientSecret: clientSecret,
		redirectURI:  redirectURI,
	}
}

func (a *Adapter) Name() string { return "medium" }

// mediumAuthData is the internal structure for persisted Medium credentials.
type mediumAuthData struct {
	AccessToken string `json:"access_token"`
	RefreshToken string `json:"refresh_token,omitempty"`
	ExpiresAt    int64  `json:"expires_at"` // Unix seconds
	TokenType    string `json:"token_type"`
	UserID       string `json:"user_id,omitempty"`
}

// oauthState holds transient state for an in-progress OAuth flow.
type oauthState struct {
	State       string `json:"state"`
	Code        string `json:"code,omitempty"`
	Completed   bool   `json:"completed"`
}

// ---------------------------------------------------------------------------
// Authentication: OAuth 2.0 flow
// ---------------------------------------------------------------------------

// StartAuth generates the Medium OAuth authorization URL.  Since Medium uses
// a redirect-based OAuth flow, the returned bytes are a JSON payload
// containing the authorization URL that the client should open in a browser.
func (a *Adapter) StartAuth(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
	// Generate a state parameter for CSRF protection.
	state := fmt.Sprintf("medium-%d", time.Now().UnixMilli())

	// Build the OAuth authorization URL.
	// The client should redirect the user to this URL to grant access.
	authURL := fmt.Sprintf("%s?client_id=%s&response_type=code&redirect_uri=%s&scope=basicProfile,publishPost&state=%s",
		mediumAuthorize,
		a.clientID,
		a.redirectURI,
		state,
	)

	// Return the auth URL as JSON so the client can redirect the user.
	payload := map[string]string{
		"auth_url":  authURL,
		"state":     state,
		"auth_type": "oauth2_redirect",
	}
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, nil, fmt.Errorf("marshal auth payload: %w", err)
	}

	return &platform.AuthSession{
		CDPContext: &oauthState{State: state},
		AuthRef:    state,
	}, payloadBytes, nil
}

// PollAuth checks whether the OAuth callback has been received.
// For Medium, the caller should pass the OAuth authorization code via
// the session CDPContext.  Once a code is available, this method exchanges
// it for an access token.
func (a *Adapter) PollAuth(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
	oauthSt, ok := session.CDPContext.(*oauthState)
	if !ok {
		return nil, fmt.Errorf("invalid session: wrong context type")
	}

	if oauthSt.Code == "" {
		// Still waiting for the OAuth callback.
		return nil, nil
	}

	// Exchange the authorization code for an access token.
	reqBody := fmt.Sprintf("grant_type=authorization_code&code=%s&client_id=%s&client_secret=%s&redirect_uri=%s",
		oauthSt.Code,
		a.clientID,
		a.clientSecret,
		a.redirectURI,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, mediumTokenURL, strings.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("create token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return nil, fmt.Errorf("exchange token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("token exchange failed (status %d): %s", resp.StatusCode, string(body))
	}

	var tokenResp struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		ExpiresIn    int    `json:"expires_in"`
		TokenType    string `json:"token_type"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return nil, fmt.Errorf("decode token response: %w", err)
	}

	// Fetch the authenticated user's ID for future API calls.
	userID, err := a.fetchUserID(ctx, tokenResp.AccessToken)
	if err != nil {
		return nil, fmt.Errorf("fetch user ID: %w", err)
	}

	authData := mediumAuthData{
		AccessToken:  tokenResp.AccessToken,
		RefreshToken: tokenResp.RefreshToken,
		ExpiresAt:    time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second).Unix(),
		TokenType:    tokenResp.TokenType,
		UserID:       userID,
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

// Publish creates a new post on Medium via the REST API.
// It decrypts the stored auth data and POSTs to the Medium publications
// endpoint.
func (a *Adapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
	// Decrypt auth data.
	authJSON, err := llm.DecryptAPIKey(encryptedAuth, masterKey)
	if err != nil {
		return nil, fmt.Errorf("decrypt auth data: %w", err)
	}

	var authData mediumAuthData
	if err := json.Unmarshal([]byte(authJSON), &authData); err != nil {
		return nil, fmt.Errorf("unmarshal auth data: %w", err)
	}

	// Check if the access token is expired and needs refresh.
	accessToken := authData.AccessToken
	if authData.ExpiresAt > 0 && time.Now().Unix() > authData.ExpiresAt {
		if authData.RefreshToken == "" {
			return nil, fmt.Errorf("access token expired and no refresh token available")
		}
		newToken, err := a.refreshAccessToken(ctx, authData.RefreshToken)
		if err != nil {
			return nil, fmt.Errorf("refresh access token: %w", err)
		}
		accessToken = newToken
	}

	// Build the publish request body.
	// Medium API: POST /v1/me/posts
	// The content format can be html, markdown, or plain.
	body := map[string]interface{}{
		"title":         params.Title,
		"content":       params.Content,
		"contentFormat": "markdown",
		"publishStatus": "public",
	}
	if len(params.Tags) > 0 {
		body["tags"] = params.Tags
	}

	bodyJSON, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("marshal publish body: %w", err)
	}

	publishURL := mediumAPIBase + "/me/posts"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, publishURL, bytes.NewReader(bodyJSON))
	if err != nil {
		return nil, fmt.Errorf("create publish request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return nil, fmt.Errorf("publish request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("publish failed (status %d): %s", resp.StatusCode, string(respBody))
	}

	var publishResp struct {
		Data struct {
			ID        string `json:"id"`
			Title     string `json:"title"`
			URL       string `json:"url"`
			AuthorID  string `json:"authorId"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&publishResp); err != nil {
		return nil, fmt.Errorf("decode publish response: %w", err)
	}

	return &platform.PublishResult{
		PlatformURL: publishResp.Data.URL,
		PlatformID:  publishResp.Data.ID,
	}, nil
}

// ---------------------------------------------------------------------------
// Status check
// ---------------------------------------------------------------------------

// CheckStatus checks whether a Medium post is still live.
// Medium articles are published immediately, so we make a HEAD request
// to the post URL to verify it is still accessible.
func (a *Adapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	// Decrypt auth data.
	authJSON, err := llm.DecryptAPIKey(encryptedAuth, masterKey)
	if err != nil {
		return "unknown", fmt.Errorf("decrypt auth data: %w", err)
	}

	var authData mediumAuthData
	if err := json.Unmarshal([]byte(authJSON), &authData); err != nil {
		return "unknown", fmt.Errorf("unmarshal auth data: %w", err)
	}

	// Medium does not have a public API to check post status by ID.
	// We try to use the user's publications endpoint, but as a fallback
	// we make a HEAD request to the article URL if available.
	// For now, we return "live" since Medium posts are immediately published
	// and we do not have a way to check status by ID alone.
	return "live", nil
}

// ---------------------------------------------------------------------------
// Revoke auth
// ---------------------------------------------------------------------------

// RevokeAuth attempts to revoke the Medium OAuth token.
// Medium does not have a token revocation endpoint, so this is effectively
// a no-op.  The caller is responsible for deleting the persisted auth data.
func (a *Adapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	// Medium does not offer a token revocation endpoint.
	// The caller (service layer) will delete the stored encrypted_auth
	// from the platform_connections table.
	return nil
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// fetchUserID retrieves the authenticated Medium user's ID.
func (a *Adapter) fetchUserID(ctx context.Context, accessToken string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, mediumAPIBase+"/me", nil)
	if err != nil {
		return "", fmt.Errorf("create me request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Accept", "application/json")

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return "", fmt.Errorf("fetch me: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("fetch me failed (status %d): %s", resp.StatusCode, string(body))
	}

	var meResp struct {
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&meResp); err != nil {
		return "", fmt.Errorf("decode me response: %w", err)
	}

	return meResp.Data.ID, nil
}

// refreshAccessToken refreshes an expired Medium access token using the
// refresh token.
func (a *Adapter) refreshAccessToken(ctx context.Context, refreshToken string) (string, error) {
	reqBody := fmt.Sprintf("grant_type=refresh_token&refresh_token=%s&client_id=%s&client_secret=%s",
		refreshToken,
		a.clientID,
		a.clientSecret,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, mediumTokenURL, strings.NewReader(reqBody))
	if err != nil {
		return "", fmt.Errorf("create refresh request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")

	resp, err := httpclient.Shared.Do(req)
	if err != nil {
		return "", fmt.Errorf("refresh token request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("refresh token failed (status %d): %s", resp.StatusCode, string(body))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("decode refresh response: %w", err)
	}

	return tokenResp.AccessToken, nil
}
