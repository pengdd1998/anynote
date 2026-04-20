// Package appsetup provides shared application initialization helpers
// used by both the server and worker entry points.
package appsetup

import (
	"os"

	"github.com/anynote/backend/internal/platform"
	"github.com/anynote/backend/internal/platform/medium"
	"github.com/anynote/backend/internal/platform/webhook"
	"github.com/anynote/backend/internal/platform/wechat"
	"github.com/anynote/backend/internal/platform/wordpress"
	"github.com/anynote/backend/internal/platform/xiaohongshu"
	"github.com/anynote/backend/internal/platform/zhihu"
)

// RegisterDefaultAdapters creates and registers all built-in platform adapters
// into the given registry. chromeWSURL is the WebSocket URL for the headless
// Chrome instance used by CDP-based adapters (XHS, WeChat, Zhihu). Medium
// OAuth credentials are read from environment variables.
func RegisterDefaultAdapters(registry *platform.Registry, chromeWSURL string) {
	registry.Register("xiaohongshu", xiaohongshu.NewAdapter(chromeWSURL))
	registry.Register("wechat", wechat.NewAdapter(chromeWSURL))
	registry.Register("zhihu", zhihu.NewAdapter(chromeWSURL))
	registry.Register("medium", medium.NewAdapter(
		os.Getenv("MEDIUM_CLIENT_ID"),
		os.Getenv("MEDIUM_CLIENT_SECRET"),
		os.Getenv("MEDIUM_REDIRECT_URI"),
	))
	registry.Register("wordpress", wordpress.NewAdapter())
	registry.Register("webhook", webhook.NewAdapter())
}
