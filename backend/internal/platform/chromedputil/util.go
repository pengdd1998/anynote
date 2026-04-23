// Package chromedputil provides shared types and helpers for chromedp-based
// platform adapters (XHS, WeChat, Zhihu). Extracted from per-adapter
// duplicates to reduce code duplication.
package chromedputil

import (
	"context"

	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/chromedp"
)

// CookieJar is the JSON structure used to persist browser cookies for
// chromedp-based platform adapters.
type CookieJar struct {
	Cookies []HTTPCookie `json:"cookies"`
}

// HTTPCookie represents a single cookie in a CookieJar.
type HTTPCookie struct {
	Name     string `json:"name"`
	Value    string `json:"value"`
	Domain   string `json:"domain"`
	Path     string `json:"path"`
	Expires  int64  `json:"expires"` // Unix seconds; 0 = session
	HTTPOnly bool   `json:"http_only"`
	Secure   bool   `json:"secure"`
	SameSite string `json:"same_site"`
}

// CDPContextHandle wraps chromedp context references so they can be stored
// in the platform.AuthSession.CDPContext interface{} field.
type CDPContextHandle struct {
	AllocCancel context.CancelFunc
	BrowserCtx  context.Context
}

// SameSiteString converts a network.CookieSameSite value to a string
// suitable for JSON serialization.
func SameSiteString(ss network.CookieSameSite) string {
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

// CookieActions builds a slice of chromedp actions that set each cookie from
// the jar via the CDP network.SetCookie command. The caller runs these
// actions against a browser context before navigating to the target page.
func CookieActions(jar *CookieJar) []chromedp.Action {
	actions := make([]chromedp.Action, 0, len(jar.Cookies))
	for i := range jar.Cookies {
		c := jar.Cookies[i] // local copy for closure
		actions = append(actions, chromedp.ActionFunc(func(ctx context.Context) error {
			return network.SetCookie(c.Name, c.Value).
				WithDomain(c.Domain).
				WithPath(c.Path).
				WithHTTPOnly(c.HTTPOnly).
				WithSecure(c.Secure).
				Do(ctx)
		}))
	}
	return actions
}

// QRExtractJS returns a JavaScript expression (for chromedp.Evaluate) that
// extracts the image element matching the given CSS selector as PNG bytes.
// It handles both data-URI and remote image sources by drawing the image
// onto an offscreen canvas and converting to PNG.
func QRExtractJS(selector string) string {
	return `new Promise((resolve, reject) => {
		const img = document.querySelector('` + selector + `');
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
	})`
}
