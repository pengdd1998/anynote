package xiaohongshu

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/cdproto/page"
	"github.com/chromedp/chromedp"

	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/platform/chromedputil"
)

// XHS creator and publish URLs.
const (
	creatorBaseURL = "https://creator.xiaohongshu.com"
	loginURL       = creatorBaseURL + "/login"
	publishURL     = creatorBaseURL + "/publish/publish"
	postBaseURL    = "https://www.xiaohongshu.com/explore/"

	// Delay between automated actions to reduce bot-detection risk.
	actionDelay = 1500 * time.Millisecond
)

// Adapter implements platform publishing for Xiaohongshu (XHS / RedNote).
// Uses chromedp for headless browser automation.
type Adapter struct {
	// wsURL is the Chrome DevTools Protocol WebSocket URL for the remote
	// headless Chrome instance (the chrome service from docker-compose).
	wsURL string
}

// NewAdapter creates a new XHS adapter.
func NewAdapter(chromeWSURL string) *Adapter {
	return &Adapter{wsURL: chromeWSURL}
}

func (a *Adapter) Name() string { return "xiaohongshu" }

// ---------------------------------------------------------------------------
// Authentication: QR code flow
// ---------------------------------------------------------------------------

// StartAuth navigates to the XHS creator login page, waits for the QR code
// to render, captures the QR code image as PNG bytes, and returns it.
// The AuthSession.CDPContext carries the chromedp context so that PollAuth
// can reuse the same browser tab.
func (a *Adapter) StartAuth(ctx context.Context, masterKey []byte) (*platform.AuthSession, []byte, error) {
	// Create an allocator context that connects to the remote Chrome instance.
	allocCtx, cancel := chromedp.NewRemoteAllocator(ctx, a.wsURL)
	// We do NOT call cancel() here; the caller will handle cleanup via the
	// session's CDPContext after polling completes or times out.

	// Create a new browser tab.
	browserCtx, _ := chromedp.NewContext(allocCtx)

	// Set a generous viewport so the login page renders correctly.
	if err := chromedp.Run(browserCtx,
		chromedp.EmulateViewport(1280, 800),
	); err != nil {
		cancel()
		return nil, nil, fmt.Errorf("set viewport: %w", err)
	}

	// Navigate to the login page and wait for the QR code element.
	qrSelector := `img[src*="qrcode"], .qrcode-img img, .login-container img`
	if err := chromedp.Run(browserCtx,
		chromedp.Navigate(loginURL),
		// Give the page time to load; XHS login may take a moment.
		chromedp.Sleep(3*time.Second),
		// The QR code is rendered as an <img> inside the login container.
		// XHS typically uses a selector like ".qrcode-img img" or ".login-qrcode img".
		chromedp.WaitVisible(qrSelector, chromedp.ByQuery),
	); err != nil {
		cancel()
		return nil, nil, fmt.Errorf("navigate to login page: %w", err)
	}

	// Extract the QR code image as PNG bytes.
	var pngBytes []byte
	if err := chromedp.Run(browserCtx,
		chromedp.Evaluate(chromedputil.QRExtractJS(qrSelector), &pngBytes),
	); err != nil {
		cancel()
		return nil, nil, fmt.Errorf("extract QR code image: %w", err)
	}

	authRef := fmt.Sprintf("xhs-%d", time.Now().UnixMilli())

	return &platform.AuthSession{
		CDPContext: &chromedputil.CDPContextHandle{AllocCancel: cancel, BrowserCtx: browserCtx},
		AuthRef:    authRef,
	}, pngBytes, nil
}

// PollAuth checks if the user has scanned the QR code and completed login.
// On success it extracts cookies from the browser, encrypts them with
// AES-256-GCM, and returns the encrypted blob.
func (a *Adapter) PollAuth(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
	handle, ok := session.CDPContext.(*chromedputil.CDPContextHandle)
	if !ok {
		return nil, fmt.Errorf("invalid session: wrong context type")
	}

	// Check if we have been redirected away from the login page, or
	// if authentication cookies now exist.
	var currentURL string
	var hasAuthCookie bool

	if err := chromedp.Run(handle.BrowserCtx,
		chromedp.Location(&currentURL),
		chromedp.Evaluate(`
			document.cookie.includes('web_session') ||
			document.cookie.includes('galaxy_creator_session_id') ||
			!document.querySelector('.qrcode-img img, .login-container img')
		`, &hasAuthCookie),
	); err != nil {
		return nil, fmt.Errorf("poll login status: %w", err)
	}

	if !hasAuthCookie && strings.Contains(currentURL, "login") {
		// Still waiting for the user to scan.
		return nil, nil
	}

	// Auth appears complete.  Wait briefly for the page to settle, then
	// extract cookies.
	chromedp.Run(handle.BrowserCtx, chromedp.Sleep(2*time.Second))

	var cookies []*network.Cookie
	if err := chromedp.Run(handle.BrowserCtx,
		chromedp.ActionFunc(func(ctx context.Context) error {
			var err error
			cookies, err = network.GetCookies().Do(ctx)
			return err
		}),
	); err != nil {
		return nil, fmt.Errorf("get cookies: %w", err)
	}

	// Build the cookie jar.
	jar := chromedputil.CookieJar{Cookies: make([]chromedputil.HTTPCookie, 0, len(cookies))}
	for _, c := range cookies {
		if !strings.Contains(c.Domain, "xiaohongshu.com") && !strings.Contains(c.Domain, "xhscdn.com") {
			continue
		}
		jar.Cookies = append(jar.Cookies, chromedputil.HTTPCookie{
			Name:     c.Name,
			Value:    c.Value,
			Domain:   c.Domain,
			Path:     c.Path,
			Expires:  int64(c.Expires),
			HTTPOnly: c.HTTPOnly,
			Secure:   c.Secure,
			SameSite: chromedputil.SameSiteString(c.SameSite),
		})
	}

	if len(jar.Cookies) == 0 {
		return nil, fmt.Errorf("no XHS cookies found after login")
	}

	jarBytes, err := json.Marshal(jar)
	if err != nil {
		return nil, fmt.Errorf("marshal cookies: %w", err)
	}

	// Encrypt the cookie jar using AES-256-GCM (same approach as API keys).
	encrypted, err := llm.EncryptAPIKey(string(jarBytes), masterKey)
	if err != nil {
		return nil, fmt.Errorf("encrypt cookies: %w", err)
	}

	// Clean up the browser context.
	handle.AllocCancel()

	return encrypted, nil
}

// ---------------------------------------------------------------------------
// Publishing
// ---------------------------------------------------------------------------

// Publish creates a new post on XHS.  It decrypts the stored auth data,
// sets cookies in a fresh browser tab, navigates to the publish page, fills
// in the form fields, and submits.
func (a *Adapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
	// Decrypt cookies.
	cookieJSON, err := llm.DecryptAPIKey(encryptedAuth, masterKey)
	if err != nil {
		return nil, fmt.Errorf("decrypt auth data: %w", err)
	}

	var jar chromedputil.CookieJar
	if err := json.Unmarshal([]byte(cookieJSON), &jar); err != nil {
		return nil, fmt.Errorf("unmarshal cookies: %w", err)
	}

	// Create a browser context and set cookies before navigating.
	allocCtx, cancel := chromedp.NewRemoteAllocator(ctx, a.wsURL)
	defer cancel()

	browserCtx, _ := chromedp.NewContext(allocCtx)

	// Navigate to the publish page.
	if err := chromedp.Run(browserCtx,
		chromedp.EmulateViewport(1280, 800),
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, _, _, err := page.Navigate(publishURL).Do(ctx)
			return err
		}),
		chromedp.Sleep(2*time.Second),
	); err != nil {
		return nil, fmt.Errorf("navigate to publish page: %w", err)
	}

	// Now set cookies and reload so they apply.
	cookieActions := chromedputil.CookieActions(&jar)
	if err := chromedp.Run(browserCtx, cookieActions...); err != nil {
		return nil, fmt.Errorf("set cookies: %w", err)
	}

	// Reload with cookies applied.
	if err := chromedp.Run(browserCtx,
		chromedp.Navigate(publishURL),
		chromedp.Sleep(3*time.Second),
		// Wait for the publish form to appear.  If we get redirected to
		// the login page instead, the session has expired.
		chromedp.WaitVisible(`#title, .title-input, input[placeholder*="标题"], input[placeholder*="title"]`, chromedp.ByQuery),
	); err != nil {
		return nil, fmt.Errorf("publish form not loaded (session may have expired): %w", err)
	}

	// Upload images if provided.
	for _, img := range params.Images {
		filePath := img.FilePath
		if filePath == "" && img.URL != "" {
			// If only a URL is provided, we skip image upload from this path.
			// Image downloading should be handled by the caller (e.g. download
			// to a temp file and pass FilePath).
			continue
		}
		if filePath == "" {
			continue
		}
		if err := chromedp.Run(browserCtx,
			// XHS uses a file input for image uploads.
			chromedp.SendKeys(`input[type="file"]`, filePath, chromedp.ByQuery),
			chromedp.Sleep(actionDelay),
		); err != nil {
			return nil, fmt.Errorf("upload image %s: %w", filePath, err)
		}
		// Wait for the upload to complete (image thumbnail appears).
		chromedp.Run(browserCtx,
			chromedp.Sleep(2*time.Second),
		)
	}

	// Fill in the title.
	if err := chromedp.Run(browserCtx,
		chromedp.SendKeys(`#title, .title-input, input[placeholder*="标题"], input[placeholder*="title"]`, params.Title, chromedp.ByQuery),
		chromedp.Sleep(actionDelay),
	); err != nil {
		return nil, fmt.Errorf("fill title: %w", err)
	}

	// Fill in the content/description textarea.
	// XHS uses a contenteditable div or a textarea for the body.
	if params.Content != "" {
		if err := chromedp.Run(browserCtx,
			chromedp.Click(`#content, .content-input, textarea[placeholder*="正文"], textarea[placeholder*="content"], [contenteditable="true"]`, chromedp.ByQuery),
			chromedp.Sleep(500*time.Millisecond),
			chromedp.SendKeys(`#content, .content-input, textarea[placeholder*="正文"], textarea[placeholder*="content"], [contenteditable="true"]`, params.Content, chromedp.ByQuery),
			chromedp.Sleep(actionDelay),
		); err != nil {
			return nil, fmt.Errorf("fill content: %w", err)
		}
	}

	// Add tags.  XHS allows adding hashtags in the content body or via a tag
	// input.  We append them to the content area.
	if len(params.Tags) > 0 {
		tagText := ""
		for _, t := range params.Tags {
			tagText += fmt.Sprintf(" #%s", t)
		}
		if err := chromedp.Run(browserCtx,
			chromedp.Click(`#content, .content-input, textarea[placeholder*="正文"], [contenteditable="true"]`, chromedp.ByQuery),
			chromedp.Sleep(300*time.Millisecond),
			chromedp.SendKeys(`#content, .content-input, textarea[placeholder*="正文"], [contenteditable="true"]`, tagText, chromedp.ByQuery),
			chromedp.Sleep(actionDelay),
		); err != nil {
			// Non-fatal: tags may not be supported in this exact way.
			// Log and continue.
			slog.Debug("platform: tag insertion failed (non-fatal)", "platform", "xiaohongshu", "error", err)
		}
	}

	// Click the publish button.
	if err := chromedp.Run(browserCtx,
		chromedp.Sleep(actionDelay),
		chromedp.Click(`button.publishBtn, button.publish-btn, button:has-text("发布"), button:has-text("Publish")`, chromedp.ByQuery),
	); err != nil {
		return nil, fmt.Errorf("click publish button: %w", err)
	}

	// Wait for the success confirmation or a redirect that indicates success.
	if err := chromedp.Run(browserCtx,
		chromedp.Sleep(3*time.Second),
	); err != nil {
		return nil, fmt.Errorf("wait for publish result: %w", err)
	}

	// Try to extract the post URL from the resulting page.
	// XHS creator dashboard may show the newly published note with a link.
	var postURL string
	chromedp.Run(browserCtx,
		chromedp.Evaluate(`
			(() => {
				// Look for a link to the published note.
				const links = document.querySelectorAll('a[href*="/explore/"], a[href*="/discovery/item/"]');
				for (const link of links) {
					if (link.href) return link.href;
				}
				return '';
			})()
		`, &postURL),
	)

	// Derive the platform ID from the URL.
	platformID := extractNoteID(postURL)
	if platformID == "" {
		// If we cannot extract the ID from the page, construct a fallback
		// using the current time so the caller can still track the publish.
		platformID = fmt.Sprintf("pending-%d", time.Now().UnixMilli())
	}

	return &platform.PublishResult{
		PlatformURL: postURL,
		PlatformID:  platformID,
	}, nil
}

// ---------------------------------------------------------------------------
// Status check
// ---------------------------------------------------------------------------

// CheckStatus navigates to the published post URL and checks whether the
// post is still accessible.
func (a *Adapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	// Decrypt cookies.
	cookieJSON, err := llm.DecryptAPIKey(encryptedAuth, masterKey)
	if err != nil {
		return "unknown", fmt.Errorf("decrypt auth data: %w", err)
	}

	var jar chromedputil.CookieJar
	if err := json.Unmarshal([]byte(cookieJSON), &jar); err != nil {
		return "unknown", fmt.Errorf("unmarshal cookies: %w", err)
	}

	postURL := postBaseURL + platformID
	if strings.HasPrefix(platformID, "http") {
		postURL = platformID
	}

	allocCtx, cancel := chromedp.NewRemoteAllocator(ctx, a.wsURL)
	defer cancel()

	browserCtx, _ := chromedp.NewContext(allocCtx)

	var pageContent string

	if err := chromedp.Run(browserCtx,
		chromedp.EmulateViewport(1280, 800),
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, _, _, err := page.Navigate(postURL).Do(ctx)
			return err
		}),
		chromedp.Sleep(2*time.Second),
	); err != nil {
		return "unknown", fmt.Errorf("navigate to post: %w", err)
	}

	// Set cookies and reload.
	cookieActions := chromedputil.CookieActions(&jar)
	if err := chromedp.Run(browserCtx, cookieActions...); err != nil {
		return "unknown", fmt.Errorf("set cookies: %w", err)
	}

	// Reload with cookies.
	if err := chromedp.Run(browserCtx,
		chromedp.Navigate(postURL),
		chromedp.Sleep(3*time.Second),
		chromedp.Evaluate(`document.body.innerText.substring(0, 500)`, &pageContent),
	); err != nil {
		return "unknown", fmt.Errorf("check page: %w", err)
	}

	// If the page contains indicators that the note has been removed or
	// is unavailable, report accordingly.
	if strings.Contains(pageContent, "该笔记已被删除") ||
		strings.Contains(pageContent, "笔记不存在") ||
		strings.Contains(pageContent, "has been deleted") {
		return "removed", nil
	}

	if strings.Contains(pageContent, "笔记") ||
		strings.Contains(pageContent, "评论") ||
		strings.Contains(pageContent, "点赞") {
		return "live", nil
	}

	return "unknown", nil
}

// ---------------------------------------------------------------------------
// Revoke auth
// ---------------------------------------------------------------------------

// RevokeAuth is a no-op for XHS because there is no server-side session
// revocation API.  The caller is responsible for deleting the persisted
// encrypted auth data from the database.
func (a *Adapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	// XHS does not offer a programmatic logout/session-revoke endpoint.
	// The caller (service layer) will delete the stored encrypted_auth
	// from the platform_connections table.
	return nil
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// extractNoteID tries to parse an XHS note ID from a URL.
// Expected format: https://www.xiaohongshu.com/explore/{noteId}
func extractNoteID(rawURL string) string {
	if rawURL == "" {
		return ""
	}
	parts := strings.Split(rawURL, "/")
	for i := len(parts) - 1; i >= 0; i-- {
		p := strings.TrimSpace(parts[i])
		if p != "" && p != "explore" && p != "discovery" && p != "item" {
			// Skip hostnames (contain dots).
			if strings.Contains(p, ".") {
				continue
			}
			// Remove query parameters.
			if idx := strings.Index(p, "?"); idx >= 0 {
				p = p[:idx]
			}
			// Simple heuristic: XHS note IDs are typically 24 hex chars.
			if len(p) >= 10 {
				return p
			}
		}
	}
	return ""
}
