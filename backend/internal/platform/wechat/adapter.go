package wechat

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
	"github.com/anynote/backend/internal/platform/common"
)

// WeChat Official Account platform URLs.
const (
	mpBaseURL  = "https://mp.weixin.qq.com"
	loginURL   = mpBaseURL + "/"
	publishURL = mpBaseURL + "/cgi-bin/appmsg?t=media/appmsg_edit&action=edit&type=77"

	// Delay between automated actions to reduce bot-detection risk.
	actionDelay = 1500 * time.Millisecond
)

// Adapter implements platform publishing for WeChat Official Account (WeChat OA).
// Uses chromedp for headless browser automation.
type Adapter struct {
	// wsURL is the Chrome DevTools Protocol WebSocket URL for the remote
	// headless Chrome instance (the chrome service from docker-compose).
	wsURL string
}

// NewAdapter creates a new WeChat adapter.
func NewAdapter(chromeWSURL string) *Adapter {
	return &Adapter{wsURL: chromeWSURL}
}

func (a *Adapter) Name() string { return "wechat" }

// ---------------------------------------------------------------------------
// Authentication: QR code flow
// ---------------------------------------------------------------------------

// StartAuth navigates to the WeChat OA login page, waits for the QR code
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

	// Navigate to the WeChat OA login page and wait for the QR code element.
	// NOTE(wechat-selectors): The QR code selector targets the login page QR
	// image via compound selectors (.login__type__scan img, .qrcode img, etc.).
	// WeChat may change their login page DOM structure, requiring selector updates
	// if the QR code element is no longer found.
	qrSelector := `.login__type__scan img, .qrcode img, img[src*="qrcode"], .login_qrcode img`
	if err := chromedp.Run(browserCtx,
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, _, _, err := page.Navigate(loginURL).Do(ctx)
			return err
		}),
		// Give the page time to load; WeChat login page may take a moment.
		chromedp.Sleep(3*time.Second),
		// Wait for the QR code to appear.
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

	authRef := fmt.Sprintf("wechat-%d", time.Now().UnixMilli())

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

	// WeChat MP login sets a "slave_sid" or "bizuin" cookie upon successful
	// login, or redirects to the main console page.
	// NOTE(wechat-selectors): The cookie names (slave_sid, bizuin, slave_user)
	// are checked to detect successful authentication. WeChat may rename or add
	// new session cookies, requiring updates to the detection logic.
	if err := chromedp.Run(handle.BrowserCtx,
		chromedp.Location(&currentURL),
		chromedp.Evaluate(`
			document.cookie.includes('slave_sid') ||
			document.cookie.includes('bizuin') ||
			document.cookie.includes('slave_user') ||
			!document.querySelector('.login__type__scan img, .qrcode img, img[src*="qrcode"]')
		`, &hasAuthCookie),
	); err != nil {
		return nil, fmt.Errorf("poll login status: %w", err)
	}

	if !hasAuthCookie && (strings.Contains(currentURL, "login") || currentURL == loginURL || strings.HasSuffix(currentURL, "/")) {
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

	// Build the cookie jar, filtering to WeChat-related domains.
	jar := chromedputil.CookieJar{Cookies: make([]chromedputil.HTTPCookie, 0, len(cookies))}
	for _, c := range cookies {
		if !strings.Contains(c.Domain, "weixin.qq.com") && !strings.Contains(c.Domain, "wx.qq.com") {
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
		return nil, fmt.Errorf("no WeChat cookies found after login")
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

// Publish creates a new draft article on WeChat Official Account platform.
// It decrypts the stored auth data, sets cookies in a fresh browser tab,
// navigates to the article creation page, fills in the form fields,
// and saves as draft.
func (a *Adapter) Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params platform.PublishParams) (*platform.PublishResult, error) {
	jar, err := common.DecryptCookieJar(ctx, encryptedAuth, masterKey)
	if err != nil {
		return nil, err
	}

	// Create a browser context and set cookies before navigating.
	allocCtx, cancel := chromedp.NewRemoteAllocator(ctx, a.wsURL)
	defer cancel()

	browserCtx, _ := chromedp.NewContext(allocCtx)

	// Navigate to the publish page.
	// NOTE(wechat-selectors): The publish URL is constructed from the
	// publishURL constant which targets the WeChat MP article editor endpoint.
	// The URL structure and query parameters may differ across account types
	// (subscription vs service account) or platform versions.
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
	// NOTE(wechat-selectors): The title selector targets #title, input.title,
	// input[placeholder*="标题"], or input[name="title"]. The content selector
	// targets the rich text editor area via contenteditable or textarea. WeChat
	// may change their editor DOM structure or element IDs in future updates.
	titleSelector := `#title, input.title, input[placeholder*="标题"], input[name="title"]`
	contentSelector := `#js_editor, .edui-body-container, [contenteditable="true"], textarea[placeholder*="正文"]`
	if err := chromedp.Run(browserCtx,
		chromedp.Navigate(publishURL),
		chromedp.Sleep(3*time.Second),
		// Wait for the publish form to appear.  If we get redirected to
		// the login page instead, the session has expired.
		chromedp.WaitVisible(titleSelector, chromedp.ByQuery),
	); err != nil {
		return nil, fmt.Errorf("publish form not loaded (session may have expired): %w", err)
	}

	// Upload images if provided.
	for _, img := range params.Images {
		filePath := img.FilePath
		if filePath == "" && img.URL != "" {
			// If only a URL is provided, skip image upload from this path.
			// Image downloading should be handled by the caller (e.g. download
			// to a temp file and pass FilePath).
			continue
		}
		if filePath == "" {
			continue
		}
		// NOTE(wechat-selectors): The file input selector targets
		// input[type="file"] for image uploads. WeChat may use a custom
		// upload widget that replaces the standard file input, requiring
		// selector updates if image uploads fail.
		if err := chromedp.Run(browserCtx,
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
		chromedp.SendKeys(titleSelector, params.Title, chromedp.ByQuery),
		chromedp.Sleep(actionDelay),
	); err != nil {
		return nil, fmt.Errorf("fill title: %w", err)
	}

	// Fill in the content body.
	// WeChat MP uses a rich text editor (typically contenteditable).
	// For rich content we click to focus then type.
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

	// WeChat MP does not use hashtags in the same way as social platforms.
	// If tags are provided, we append them at the end of the article body.
	if len(params.Tags) > 0 {
		tagText := "\n\n"
		for _, t := range params.Tags {
			tagText += fmt.Sprintf("#%s ", t)
		}
		if err := chromedp.Run(browserCtx,
			chromedp.Click(contentSelector, chromedp.ByQuery),
			chromedp.Sleep(300*time.Millisecond),
			chromedp.SendKeys(contentSelector, tagText, chromedp.ByQuery),
			chromedp.Sleep(actionDelay),
		); err != nil {
			// Non-fatal: tags may not be supported in this exact way.
			slog.Debug("platform: tag insertion failed (non-fatal)", "platform", "wechat", "error", err)
		}
	}

	// Save as draft.
	// NOTE(wechat-selectors): The save button selector targets #js_submit,
	// button.js_save, or buttons containing "保存"/"Save". WeChat has both a
	// "Save" and a "Submit for Review" button; this targets the save-draft
	// action so users can review before manual submission. Button labels or
	// IDs may change with editor updates.
	if err := chromedp.Run(browserCtx,
		chromedp.Sleep(actionDelay),
		chromedp.Click(`#js_submit, button.js_save, button:has-text("保存"), button:has-text("Save")`, chromedp.ByQuery),
	); err != nil {
		return nil, fmt.Errorf("click save draft button: %w", err)
	}

	// Wait for the save confirmation.
	if err := chromedp.Run(browserCtx,
		chromedp.Sleep(3*time.Second),
	); err != nil {
		return nil, fmt.Errorf("wait for save result: %w", err)
	}

	// Try to extract the article ID from the resulting page.
	// NOTE(wechat-selectors): The draft article ID is extracted from the
	// browser location URL, typically via the appmsgid query parameter.
	// WeChat may change how the editor exposes the saved article ID (e.g.,
	// returning it via an API response or a different URL format).
	var articleURL string
	chromedp.Run(browserCtx,
		chromedp.Location(&articleURL),
	)

	// Derive the platform ID from the URL query parameters.
	platformID := extractArticleID(articleURL)
	if platformID == "" {
		// If we cannot extract the ID from the page, construct a fallback
		// using the current time so the caller can still track the publish.
		platformID = fmt.Sprintf("draft-%d", time.Now().UnixMilli())
	}

	return &platform.PublishResult{
		PlatformURL: articleURL,
		PlatformID:  platformID,
	}, nil
}

// ---------------------------------------------------------------------------
// Status check
// ---------------------------------------------------------------------------

// CheckStatus checks if a published WeChat article is still accessible.
// For draft articles this checks the MP console; for published articles
// it checks the public-facing URL.
func (a *Adapter) CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error) {
	jar, err := common.DecryptCookieJar(ctx, encryptedAuth, masterKey)
	if err != nil {
		return "unknown", err
	}

	// Build the URL to check.  For drafts, use the MP console;
	// for published articles, use the public article URL.
	checkURL := mpBaseURL + "/cgi-bin/appmsg?t=media/appmsg_edit&action=edit&type=77&appmsgid=" + platformID
	if strings.HasPrefix(platformID, "http") {
		checkURL = platformID
	}

	allocCtx, cancel := chromedp.NewRemoteAllocator(ctx, a.wsURL)
	defer cancel()

	browserCtx, _ := chromedp.NewContext(allocCtx)

	var pageContent string

	if err := chromedp.Run(browserCtx,
		chromedp.EmulateViewport(1280, 800),
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, _, _, err := page.Navigate(checkURL).Do(ctx)
			return err
		}),
		chromedp.Sleep(2*time.Second),
	); err != nil {
		return "unknown", fmt.Errorf("navigate to article: %w", err)
	}

	// Set cookies and reload.
	cookieActions := chromedputil.CookieActions(&jar)
	if err := chromedp.Run(browserCtx, cookieActions...); err != nil {
		return "unknown", fmt.Errorf("set cookies: %w", err)
	}

	// Reload with cookies.
	if err := chromedp.Run(browserCtx,
		chromedp.Navigate(checkURL),
		chromedp.Sleep(3*time.Second),
		chromedp.Evaluate(`document.body.innerText.substring(0, 500)`, &pageContent),
	); err != nil {
		return "unknown", fmt.Errorf("check page: %w", err)
	}

	// If the page contains indicators that the article has been removed or
	// is unavailable, report accordingly.
	// NOTE(wechat-selectors): The removed-article detection relies on specific
	// Chinese and English phrases in the page content (e.g., "该内容已被发布者删除",
	// "内容不存在", "has been deleted"). WeChat may update these messages or add
	// new ones for different removal reasons (e.g., policy violations).
	if strings.Contains(pageContent, "该内容已被发布者删除") ||
		strings.Contains(pageContent, "内容不存在") ||
		strings.Contains(pageContent, "此内容因违规无法查看") ||
		strings.Contains(pageContent, "has been deleted") ||
		strings.Contains(pageContent, "content unavailable") {
		return "removed", nil
	}

	// Check for indicators that the article is live or in draft state.
	// WeChat MP editor page contains form elements when the article exists.
	if strings.Contains(pageContent, "保存") ||
		strings.Contains(pageContent, "发布") ||
		strings.Contains(pageContent, "群发") {
		return "live", nil
	}

	// If the page redirected to login, the session has expired.
	var currentURL string
	chromedp.Run(browserCtx, chromedp.Location(&currentURL))
	if strings.Contains(currentURL, "login") || strings.Contains(pageContent, "请登录") {
		return "unknown", fmt.Errorf("session expired")
	}

	return "unknown", nil
}

// ---------------------------------------------------------------------------
// Revoke auth
// ---------------------------------------------------------------------------

// RevokeAuth is a no-op for WeChat because there is no server-side session
// revocation API.  The caller is responsible for deleting the persisted
// encrypted auth data from the database.
func (a *Adapter) RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error {
	// WeChat does not offer a programmatic logout/session-revoke endpoint
	// for the MP platform via browser automation.
	// The caller (service layer) will delete the stored encrypted_auth
	// from the platform_connections table.
	return nil
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// extractArticleID tries to parse a WeChat article ID from a URL.
// Expected formats:
//   - https://mp.weixin.qq.com/cgi-bin/appmsg?...&appmsgid=123456
//   - https://mp.weixin.qq.com/s/abcdefg
//   - https://mp.weixin.qq.com/s?__biz=...&mid=...&idx=...&sn=...
func extractArticleID(rawURL string) string {
	if rawURL == "" {
		return ""
	}

	// Try to extract appmsgid from query parameters.
	if idx := strings.Index(rawURL, "appmsgid="); idx >= 0 {
		start := idx + len("appmsgid=")
		rest := rawURL[start:]
		if end := strings.IndexAny(rest, "&#"); end >= 0 {
			return rest[:end]
		}
		return rest
	}

	// Try to extract from /s/{shortId} path.
	if idx := strings.Index(rawURL, "/s/"); idx >= 0 {
		start := idx + len("/s/")
		rest := rawURL[start:]
		if end := strings.IndexAny(rest, "?#"); end >= 0 {
			return rest[:end]
		}
		return rest
	}

	// Try to extract mid parameter.
	if idx := strings.Index(rawURL, "mid="); idx >= 0 {
		start := idx + len("mid=")
		rest := rawURL[start:]
		if end := strings.IndexAny(rest, "&#"); end >= 0 {
			return rest[:end]
		}
		return rest
	}

	return ""
}
