package zhihu

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/cdproto/page"
	"github.com/chromedp/chromedp"

	"github.com/anynote/backend/internal/llm"
	"github.com/anynote/backend/internal/platform"
)

// Zhihu platform URLs.
const (
	zhihuBaseURL  = "https://www.zhihu.com"
	loginURL      = zhihuBaseURL + "/signin"
	writeURL      = zhihuBaseURL + "/writer"
	columnBaseURL = zhihuBaseURL + "/p/"

	// Delay between automated actions to reduce bot-detection risk.
	actionDelay = 1500 * time.Millisecond
)

// Adapter implements platform publishing for Zhihu.
// Uses chromedp for headless browser automation.
type Adapter struct {
	// wsURL is the Chrome DevTools Protocol WebSocket URL for the remote
	// headless Chrome instance (the chrome service from docker-compose).
	wsURL string
}

// NewAdapter creates a new Zhihu adapter.
func NewAdapter(chromeWSURL string) *Adapter {
	return &Adapter{wsURL: chromeWSURL}
}

func (a *Adapter) Name() string { return "zhihu" }

// cookieJar is the JSON structure used to persist Zhihu cookies.
type cookieJar struct {
	Cookies []httpCookie `json:"cookies"`
}

type httpCookie struct {
	Name     string `json:"name"`
	Value    string `json:"value"`
	Domain   string `json:"domain"`
	Path     string `json:"path"`
	Expires  int64  `json:"expires"` // Unix seconds; 0 = session
	HTTPOnly bool   `json:"http_only"`
	Secure   bool   `json:"secure"`
	SameSite string `json:"same_site"`
}

// ---------------------------------------------------------------------------
// Authentication: QR code / credentials page flow
// ---------------------------------------------------------------------------

// StartAuth navigates to the Zhihu login page, waits for the QR code or
// credentials form to render, captures a screenshot as PNG bytes, and
// returns it.  The AuthSession.CDPContext carries the chromedp context so
// that PollAuth can reuse the same browser tab.
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

	// Navigate to the login page and wait for the QR code or sign-in form.
	qrSelector := `img.Qrcode-img, .SignFlow-qrcode img, .Login-qrcode img, img[src*="qr"]`
	if err := chromedp.Run(browserCtx,
		chromedp.Navigate(loginURL),
		// Give the page time to load; Zhihu login may take a moment.
		chromedp.Sleep(3*time.Second),
		// Wait for the QR code element.  Zhihu renders it as an <img> inside
		// a qrcode container.
		chromedp.WaitVisible(qrSelector, chromedp.ByQuery),
	); err != nil {
		cancel()
		return nil, nil, fmt.Errorf("navigate to login page: %w", err)
	}

	// Extract the QR code image as PNG bytes.
	var pngBytes []byte
	if err := chromedp.Run(browserCtx,
		chromedp.Evaluate(`
			new Promise((resolve, reject) => {
				const img = document.querySelector('img.Qrcode-img, .SignFlow-qrcode img, .Login-qrcode img, img[src*="qr"]');
				if (!img) { reject('QR image not found'); return; }
				if (img.src.startsWith('data:')) {
					const byteString = atob(img.src.split(',')[1]);
					const bytes = new Uint8Array(byteString.length);
					for (let i = 0; i < byteString.length; i++) bytes[i] = byteString.charCodeAt(i);
					resolve(Array.from(bytes));
					return;
				}
				const canvas = document.createElement('canvas');
				canvas.width = img.naturalWidth || img.width;
				canvas.height = img.naturalHeight || img.height;
				const ctx2d = canvas.getContext('2d');
				img.crossOrigin = 'anonymous';
				img.onload = () => {
					ctx2d.drawImage(img, 0, 0);
					const dataUrl = canvas.toDataURL('image/png');
					const byteString = atob(dataUrl.split(',')[1]);
					const bytes = new Uint8Array(byteString.length);
					for (let i = 0; i < byteString.length; i++) bytes[i] = byteString.charCodeAt(i);
					resolve(Array.from(bytes));
				};
				img.onerror = () => reject('Failed to load QR image');
				img.src = img.src;
			})
		`, &pngBytes),
	); err != nil {
		cancel()
		return nil, nil, fmt.Errorf("extract QR code image: %w", err)
	}

	authRef := fmt.Sprintf("zhihu-%d", time.Now().UnixMilli())

	return &platform.AuthSession{
		CDPContext: &cdpContextHandle{allocCancel: cancel, browserCtx: browserCtx},
		AuthRef:    authRef,
	}, pngBytes, nil
}

// PollAuth checks if the user has scanned the QR code and completed login.
// On success it extracts cookies from the browser, encrypts them with
// AES-256-GCM, and returns the encrypted blob.
func (a *Adapter) PollAuth(ctx context.Context, session *platform.AuthSession, masterKey []byte) ([]byte, error) {
	handle, ok := session.CDPContext.(*cdpContextHandle)
	if !ok {
		return nil, fmt.Errorf("invalid session: wrong context type")
	}

	// Check if we have been redirected away from the login page, or
	// if authentication cookies now exist.
	var currentURL string
	var hasAuthCookie bool

	// Zhihu sets a "z_c0" or "capsion_ticket" cookie upon successful login,
	// or redirects to the homepage.
	if err := chromedp.Run(handle.browserCtx,
		chromedp.Location(&currentURL),
		chromedp.Evaluate(`
			document.cookie.includes('z_c0') ||
			document.cookie.includes('capsion_ticket') ||
			document.cookie.includes('q_c1') ||
			!document.querySelector('img.Qrcode-img, .SignFlow-qrcode img, .Login-qrcode img')
		`, &hasAuthCookie),
	); err != nil {
		return nil, fmt.Errorf("poll login status: %w", err)
	}

	if !hasAuthCookie && strings.Contains(currentURL, "signin") {
		// Still waiting for the user to scan.
		return nil, nil
	}

	// Auth appears complete.  Wait briefly for the page to settle, then
	// extract cookies.
	chromedp.Run(handle.browserCtx, chromedp.Sleep(2*time.Second))

	var cookies []*network.Cookie
	if err := chromedp.Run(handle.browserCtx,
		chromedp.ActionFunc(func(ctx context.Context) error {
			var err error
			cookies, err = network.GetCookies().Do(ctx)
			return err
		}),
	); err != nil {
		return nil, fmt.Errorf("get cookies: %w", err)
	}

	// Build the cookie jar, filtering to Zhihu-related domains.
	jar := cookieJar{Cookies: make([]httpCookie, 0, len(cookies))}
	for _, c := range cookies {
		if !strings.Contains(c.Domain, "zhihu.com") {
			continue
		}
		jar.Cookies = append(jar.Cookies, httpCookie{
			Name:     c.Name,
			Value:    c.Value,
			Domain:   c.Domain,
			Path:     c.Path,
			Expires:  int64(c.Expires),
			HTTPOnly: c.HTTPOnly,
			Secure:   c.Secure,
			SameSite: sameSiteString(c.SameSite),
		})
	}

	if len(jar.Cookies) == 0 {
		return nil, fmt.Errorf("no Zhihu cookies found after login")
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
	handle.allocCancel()

	return encrypted, nil
}

// ---------------------------------------------------------------------------
// Publishing
// ---------------------------------------------------------------------------

// Publish creates a new article on Zhihu.  It decrypts the stored auth data,
// sets cookies in a fresh browser tab, navigates to the writing page, fills
// in the form fields, and submits.
func (a *Adapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
	// Decrypt cookies.
	cookieJSON, err := llm.DecryptAPIKey(encryptedAuth, masterKey)
	if err != nil {
		return nil, fmt.Errorf("decrypt auth data: %w", err)
	}

	var jar cookieJar
	if err := json.Unmarshal([]byte(cookieJSON), &jar); err != nil {
		return nil, fmt.Errorf("unmarshal cookies: %w", err)
	}

	// Create a browser context and set cookies before navigating.
	allocCtx, cancel := chromedp.NewRemoteAllocator(ctx, a.wsURL)
	defer cancel()

	browserCtx, _ := chromedp.NewContext(allocCtx)

	// Set cookies via CDP before navigating.
	cookieActions := make([]chromedp.Action, 0, len(jar.Cookies))
	for i := range jar.Cookies {
		c := jar.Cookies[i] // create local copy for closure
		cookieActions = append(cookieActions, chromedp.ActionFunc(func(ctx context.Context) error {
			return network.SetCookie(c.Name, c.Value).
				WithDomain(c.Domain).
				WithPath(c.Path).
				WithHTTPOnly(c.HTTPOnly).
				WithSecure(c.Secure).
				Do(ctx)
		}))
	}

	// Navigate to the writing page.
	if err := chromedp.Run(browserCtx,
		chromedp.EmulateViewport(1280, 800),
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, _, _, err := page.Navigate(writeURL).Do(ctx)
			return err
		}),
		chromedp.Sleep(2*time.Second),
	); err != nil {
		return nil, fmt.Errorf("navigate to write page: %w", err)
	}

	// Now set cookies and reload so they apply.
	if err := chromedp.Run(browserCtx, cookieActions...); err != nil {
		return nil, fmt.Errorf("set cookies: %w", err)
	}

	// Reload with cookies applied.
	titleSelector := `input[placeholder*="标题"], input[placeholder*="title"], .WriteIndex-titleInput input, input.WriteIndex-titleInput`
	contentSelector := `.ProsemirrorEditor, [contenteditable="true"], .WriteIndex-bodyInput textarea`
	if err := chromedp.Run(browserCtx,
		chromedp.Navigate(writeURL),
		chromedp.Sleep(3*time.Second),
		// Wait for the editor form to appear.  If we get redirected to
		// the login page instead, the session has expired.
		chromedp.WaitVisible(titleSelector, chromedp.ByQuery),
	); err != nil {
		return nil, fmt.Errorf("editor form not loaded (session may have expired): %w", err)
	}

	// Fill in the title.
	if err := chromedp.Run(browserCtx,
		chromedp.SendKeys(titleSelector, params.Title, chromedp.ByQuery),
		chromedp.Sleep(actionDelay),
	); err != nil {
		return nil, fmt.Errorf("fill title: %w", err)
	}

	// Fill in the content body.
	// Zhihu uses a ProseMirror-based rich text editor (contenteditable div).
	if params.Content != "" {
		if err := chromedp.Run(browserCtx,
			chromedp.Click(contentSelector, chromedp.ByQuery),
			chromedp.Sleep(500*time.Millisecond),
			chromedp.SendKeys(contentSelector, params.Content, chromedp.ByQuery),
			chromedp.Sleep(actionDelay),
		); err != nil {
			return nil, fmt.Errorf("fill content: %w", err)
		}
	}

	// Add tags.  Zhihu supports topic tags on articles.
	// We attempt to use the tag input if available; otherwise tags are
	// appended as text at the end of the article body.
	if len(params.Tags) > 0 {
		tagText := "\n\n"
		for _, t := range params.Tags {
			tagText += fmt.Sprintf("#%s ", t)
		}
		// Try to fill tags via the dedicated topic input first.
		tagInputSelector := `input[placeholder*="话题"], input[placeholder*="topic"], .WriteIndex-topicInput input`
		tagFilled := false
		for _, t := range params.Tags {
			if err := chromedp.Run(browserCtx,
				chromedp.SendKeys(tagInputSelector, t, chromedp.ByQuery),
				chromedp.Sleep(800*time.Millisecond),
				chromedp.SendKeys(tagInputSelector, "\r", chromedp.ByQuery), // Enter to confirm the topic suggestion
				chromedp.Sleep(500*time.Millisecond),
			); err == nil {
				tagFilled = true
			}
		}
		if !tagFilled {
			// Fallback: append tags to content body.
			if err := chromedp.Run(browserCtx,
				chromedp.Click(contentSelector, chromedp.ByQuery),
				chromedp.Sleep(300*time.Millisecond),
				chromedp.SendKeys(contentSelector, tagText, chromedp.ByQuery),
				chromedp.Sleep(actionDelay),
			); err != nil {
				// Non-fatal: tags are supplementary content.
				_ = err
			}
		}
	}

	// Click the publish button.
	if err := chromedp.Run(browserCtx,
		chromedp.Sleep(actionDelay),
		chromedp.Click(`button.PublishPanel-publishBtn, button:has-text("发布文章"), button:has-text("Publish")`, chromedp.ByQuery),
	); err != nil {
		return nil, fmt.Errorf("click publish button: %w", err)
	}

	// Wait for the success confirmation or a redirect that indicates success.
	if err := chromedp.Run(browserCtx,
		chromedp.Sleep(3*time.Second),
	); err != nil {
		return nil, fmt.Errorf("wait for publish result: %w", err)
	}

	// Try to extract the article URL from the resulting page.
	// Zhihu redirects to the article page after publishing.
	var postURL string
	chromedp.Run(browserCtx,
		chromedp.Location(&postURL),
	)

	// Derive the platform ID from the URL.
	platformID := extractArticleID(postURL)
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

// CheckStatus navigates to the published article URL and checks whether
// the article is still accessible.
func (a *Adapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	// Decrypt cookies.
	cookieJSON, err := llm.DecryptAPIKey(encryptedAuth, masterKey)
	if err != nil {
		return "unknown", fmt.Errorf("decrypt auth data: %w", err)
	}

	var jar cookieJar
	if err := json.Unmarshal([]byte(cookieJSON), &jar); err != nil {
		return "unknown", fmt.Errorf("unmarshal cookies: %w", err)
	}

	postURL := columnBaseURL + platformID
	if strings.HasPrefix(platformID, "http") {
		postURL = platformID
	}

	allocCtx, cancel := chromedp.NewRemoteAllocator(ctx, a.wsURL)
	defer cancel()

	browserCtx, _ := chromedp.NewContext(allocCtx)

	// Set cookies.
	cookieActions := make([]chromedp.Action, 0, len(jar.Cookies))
	for i := range jar.Cookies {
		c := jar.Cookies[i] // create local copy for closure
		cookieActions = append(cookieActions, chromedp.ActionFunc(func(ctx context.Context) error {
			return network.SetCookie(c.Name, c.Value).
				WithDomain(c.Domain).
				WithPath(c.Path).
				WithHTTPOnly(c.HTTPOnly).
				WithSecure(c.Secure).
				Do(ctx)
		}))
	}

	var pageContent string

	if err := chromedp.Run(browserCtx,
		chromedp.EmulateViewport(1280, 800),
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, _, _, err := page.Navigate(postURL).Do(ctx)
			return err
		}),
		chromedp.Sleep(2*time.Second),
	); err != nil {
		return "unknown", fmt.Errorf("navigate to article: %w", err)
	}

	// Set cookies and reload.
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

	// If the page contains indicators that the article has been removed or
	// is unavailable, report accordingly.
	if strings.Contains(pageContent, "你似乎来到了没有知识存在的荒原") ||
		strings.Contains(pageContent, "该内容已被删除") ||
		strings.Contains(pageContent, "内容违规") ||
		strings.Contains(pageContent, "reviewing") ||
		strings.Contains(pageContent, "has been deleted") {
		return "removed", nil
	}

	// If the page contains typical article elements, it is live.
	if strings.Contains(pageContent, "赞同") ||
		strings.Contains(pageContent, "评论") ||
		strings.Contains(pageContent, "收藏") ||
		strings.Contains(pageContent, "Upvote") {
		return "live", nil
	}

	return "unknown", nil
}

// ---------------------------------------------------------------------------
// Revoke auth
// ---------------------------------------------------------------------------

// RevokeAuth is a no-op for Zhihu because there is no server-side session
// revocation API.  The caller is responsible for deleting the persisted
// encrypted auth data from the database.
func (a *Adapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	// Zhihu does not offer a programmatic logout/session-revoke endpoint.
	// The caller (service layer) will delete the stored encrypted_auth
	// from the platform_connections table.
	return nil
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// cdpContextHandle wraps chromedp context references so they can be stored
// in the AuthSession.CDPContext interface{} field.
type cdpContextHandle struct {
	allocCancel context.CancelFunc
	browserCtx  context.Context
}

// extractArticleID tries to parse a Zhihu article ID from a URL.
// Expected formats:
//   - https://zhuanlan.zhihu.com/p/{articleId}
//   - https://www.zhihu.com/p/{articleId}
func extractArticleID(rawURL string) string {
	if rawURL == "" {
		return ""
	}

	// Look for /p/{id} pattern.
	if idx := strings.Index(rawURL, "/p/"); idx >= 0 {
		start := idx + len("/p/")
		rest := rawURL[start:]
		if end := strings.IndexAny(rest, "?#/"); end >= 0 {
			return rest[:end]
		}
		return rest
	}

	return ""
}

// sameSiteString converts a network.CookieSameSite value to a string
// suitable for JSON serialization.
func sameSiteString(ss network.CookieSameSite) string {
	switch ss {
	case network.CookieSameSiteStrict:
		return "strict"
	case network.CookieSameSiteLax:
		return "lax"
	case network.CookieSameSiteNone:
		return "none"
	default:
		return ""
	}
}
