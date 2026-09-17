package xiaohongshu

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/chromedp/cdproto/page"
	"github.com/chromedp/chromedp"

	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/platform/chromedputil"
	"github.com/anynote/backend/internal/platform/common"
)

// resolvePostURL turns a platform id (note id or full URL) into the note URL.
func resolvePostURL(platformPostID string) string {
	if strings.HasPrefix(platformPostID, "http") {
		return platformPostID
	}
	return postBaseURL + platformPostID
}

// FetchStats implements platform.StatsFetcher. It loads the published note
// with the stored session cookies and reads the engagement counters from
// the page's __INITIAL_STATE__ payload, falling back to the visible DOM.
// XHS does not expose view counts on the note page, so Views stays 0
// unless the state happens to include one.
//
// This is best-effort scraping: any failure is returned as an error and
// the stats refresher simply keeps the previous snapshot.
func (a *Adapter) FetchStats(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformPostID string) (*platform.PostStats, error) {
	jar, err := common.DecryptCookieJar(ctx, encryptedAuth, masterKey)
	if err != nil {
		return nil, err
	}

	postURL := resolvePostURL(platformPostID)

	allocCtx, cancel := chromedp.NewRemoteAllocator(ctx, a.wsURL)
	defer cancel()

	browserCtx, cancelBrowser := chromedp.NewContext(allocCtx)
	defer cancelBrowser()
	// Fail fast: a stats scrape must never hog a browser tab; the caller
	// retries in the next hourly cycle.
	browserCtx, cancelTimeout := context.WithTimeout(browserCtx, 30*time.Second)
	defer cancelTimeout()

	var stateJSON, likeText, collectText, commentText string

	cookieActions := chromedputil.CookieActions(&jar)

	err = chromedp.Run(browserCtx,
		chromedp.EmulateViewport(1280, 800),
		chromedp.ActionFunc(func(ctx context.Context) error {
			_, _, _, err := page.Navigate(postURL).Do(ctx)
			return err
		}),
		chromedp.Sleep(2*time.Second),
		chromedp.Tasks(cookieActions),
		chromedp.Navigate(postURL),
		chromedp.Sleep(3*time.Second),
		// The note payload embedded in the page carries canonical counts.
		chromedp.Evaluate(`(() => {
			const s = window.__INITIAL_STATE__;
			if (!s) return "";
			const n = (s.note && (s.note.noteDetailMap || s.note.firstNote)) ||
				(s.noteData && s.noteData.note) || null;
			return n ? JSON.stringify(n.interactInfo || {}) : "";
		})()`, &stateJSON),
		// DOM fallbacks for the engage bar counts.
		chromedp.Evaluate(`document.querySelector('.like-wrapper .count')?.textContent?.trim() || ""`, &likeText),
		chromedp.Evaluate(`document.querySelector('.collect-wrapper .count')?.textContent?.trim() || ""`, &collectText),
		chromedp.Evaluate(`document.querySelector('.chat-wrapper .count, .comments-wrapper .count')?.textContent?.trim() || ""`, &commentText),
	)
	if err != nil {
		return nil, fmt.Errorf("scrape note page: %w", err)
	}

	stats := &platform.PostStats{}

	if stateJSON != "" {
		var interact map[string]interface{}
		if jsonErr := json.Unmarshal([]byte(stateJSON), &interact); jsonErr == nil {
			stats.Likes = parseCountField(interact, "likeCount", "likes")
			stats.Comments = parseCountField(interact, "commentCount", "comments")
			stats.Views = parseCountField(interact, "readCount", "viewCount", "views")
		}
	}

	// DOM fallbacks only fill in what the state payload missed.
	if stats.Likes == 0 && likeText != "" {
		stats.Likes = parseChineseCount(likeText)
	}
	if stats.Comments == 0 && commentText != "" {
		stats.Comments = parseChineseCount(commentText)
	}
	// The collect (bookmark) count has no PostStats slot; ignored on purpose.

	if stats.Likes == 0 && stats.Comments == 0 && stats.Views == 0 {
		return nil, fmt.Errorf("no engagement counters found on %s", postURL)
	}

	slog.Debug("xhs: fetched post stats",
		"post", platformPostID, "views", stats.Views,
		"likes", stats.Likes, "comments", stats.Comments,
	)
	return stats, nil
}

// parseCountField reads the first present numeric-ish field from the
// interactInfo map (values may be numbers or strings like "1.2万").
func parseCountField(m map[string]interface{}, keys ...string) int {
	for _, k := range keys {
		v, ok := m[k]
		if !ok || v == nil {
			continue
		}
		switch n := v.(type) {
		case float64:
			return int(n)
		case string:
			if c := parseChineseCount(n); c > 0 {
				return c
			}
		}
	}
	return 0
}

var countDigits = regexp.MustCompile(`[\d.]+`)

// parseChineseCount parses counters like "123", "1,234", "1.2万", "3千".
// Returns 0 for anything unparseable.
func parseChineseCount(s string) int {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}
	mult := 1
	switch {
	case strings.Contains(s, "万"), strings.Contains(s, "w"), strings.Contains(s, "W"):
		mult = 10000
	case strings.Contains(s, "千"), strings.Contains(s, "k"), strings.Contains(s, "K"):
		mult = 1000
	}
	numStr := countDigits.FindString(strings.ReplaceAll(s, ",", ""))
	if numStr == "" {
		return 0
	}
	f, err := strconv.ParseFloat(numStr, 64)
	if err != nil {
		return 0
	}
	return int(f * float64(mult))
}
