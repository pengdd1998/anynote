package wechat

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/chromedp/cdproto/network"

	"github.com/anynote/backend/internal/platform/chromedputil"
)

func TestAdapterName(t *testing.T) {
	a := NewAdapter("ws://localhost:9222")
	if a.Name() != "wechat" {
		t.Errorf("Adapter.Name() = %q, want %q", a.Name(), "wechat")
	}
}

func TestExtractArticleID(t *testing.T) {
	tests := []struct {
		name   string
		rawURL string
		want   string
	}{
		{
			name:   "appmsgid parameter",
			rawURL: "https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_edit&action=edit&type=77&appmsgid=123456",
			want:   "123456",
		},
		{
			name:   "appmsgid with trailing ampersand",
			rawURL: "https://mp.weixin.qq.com/cgi-bin/appmsg?appmsgid=123456&other=foo",
			want:   "123456",
		},
		{
			name:   "appmsgid with trailing anchor",
			rawURL: "https://mp.weixin.qq.com/cgi-bin/appmsg?appmsgid=123456#anchor",
			want:   "123456",
		},
		{
			name:   "short ID path /s/abcdefg",
			rawURL: "https://mp.weixin.qq.com/s/abcdefg",
			want:   "abcdefg",
		},
		{
			name:   "short ID path with query string",
			rawURL: "https://mp.weixin.qq.com/s/abcdefg?query=1",
			want:   "abcdefg",
		},
		{
			name:   "mid parameter",
			rawURL: "https://mp.weixin.qq.com/s?__biz=xxx&mid=987654&idx=1&sn=abc",
			want:   "987654",
		},
		{
			name:   "empty URL",
			rawURL: "",
			want:   "",
		},
		{
			name:   "no matching patterns",
			rawURL: "https://mp.weixin.qq.com/cgi-bin/home?t=home/index",
			want:   "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := extractArticleID(tt.rawURL)
			if got != tt.want {
				t.Errorf("extractArticleID(%q) = %q, want %q", tt.rawURL, got, tt.want)
			}
		})
	}
}

func TestCookieJarRoundTrip(t *testing.T) {
	jar := chromedputil.CookieJar{
		Cookies: []chromedputil.HTTPCookie{
			{
				Name:     "slave_sid",
				Value:    "session-token-value",
				Domain:   ".weixin.qq.com",
				Path:     "/",
				Expires:  1735689600,
				HTTPOnly: true,
				Secure:   true,
				SameSite: "lax",
			},
			{
				Name:    "bizuin",
				Value:   "another-cookie",
				Domain:  ".weixin.qq.com",
				Path:    "/",
				Expires: 0,
			},
		},
	}

	// Marshal to JSON.
	data, err := json.Marshal(jar)
	if err != nil {
		t.Fatalf("marshal cookie jar: %v", err)
	}

	// Unmarshal back.
	var jar2 chromedputil.CookieJar
	if err := json.Unmarshal(data, &jar2); err != nil {
		t.Fatalf("unmarshal cookie jar: %v", err)
	}

	if len(jar2.Cookies) != len(jar.Cookies) {
		t.Fatalf("got %d cookies, want %d", len(jar2.Cookies), len(jar.Cookies))
	}

	for i, c := range jar2.Cookies {
		orig := jar.Cookies[i]
		if c.Name != orig.Name {
			t.Errorf("cookie[%d].Name = %q, want %q", i, c.Name, orig.Name)
		}
		if c.Value != orig.Value {
			t.Errorf("cookie[%d].Value = %q, want %q", i, c.Value, orig.Value)
		}
		if c.Domain != orig.Domain {
			t.Errorf("cookie[%d].Domain = %q, want %q", i, c.Domain, orig.Domain)
		}
		if c.Expires != orig.Expires {
			t.Errorf("cookie[%d].Expires = %d, want %d", i, c.Expires, orig.Expires)
		}
		if c.HTTPOnly != orig.HTTPOnly {
			t.Errorf("cookie[%d].HTTPOnly = %v, want %v", i, c.HTTPOnly, orig.HTTPOnly)
		}
		if c.Secure != orig.Secure {
			t.Errorf("cookie[%d].Secure = %v, want %v", i, c.Secure, orig.Secure)
		}
		if c.SameSite != orig.SameSite {
			t.Errorf("cookie[%d].SameSite = %q, want %q", i, c.SameSite, orig.SameSite)
		}
	}
}

func TestSameSiteString(t *testing.T) {
	tests := []struct {
		input network.CookieSameSite
		want  string
	}{
		{network.CookieSameSiteStrict, "strict"},
		{network.CookieSameSiteLax, "lax"},
		{network.CookieSameSiteNone, "none"},
		{network.CookieSameSite("unknown"), ""},
	}

	for _, tt := range tests {
		got := chromedputil.SameSiteString(tt.input)
		if got != tt.want {
			t.Errorf("SameSiteString(%v) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestRevokeAuth(t *testing.T) {
	a := NewAdapter("ws://localhost:9222")
	err := a.RevokeAuth(context.Background(), nil, nil)
	if err != nil {
		t.Errorf("RevokeAuth() returned error: %v, want nil", err)
	}
}
