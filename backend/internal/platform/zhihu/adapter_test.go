package zhihu

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/chromedp/cdproto/network"

	"github.com/anynote/backend/internal/platform/chromedputil"
)

func TestAdapterName(t *testing.T) {
	a := NewAdapter("ws://localhost:9222")
	if a.Name() != "zhihu" {
		t.Errorf("Adapter.Name() = %q, want %q", a.Name(), "zhihu")
	}
}

func TestExtractArticleID(t *testing.T) {
	tests := []struct {
		name   string
		rawURL string
		want   string
	}{
		{
			name:   "zhuanlan URL",
			rawURL: "https://zhuanlan.zhihu.com/p/123456789",
			want:   "123456789",
		},
		{
			name:   "www URL",
			rawURL: "https://www.zhihu.com/p/987654321",
			want:   "987654321",
		},
		{
			name:   "with query params",
			rawURL: "https://zhuanlan.zhihu.com/p/123456789?utm_source=wechat",
			want:   "123456789",
		},
		{
			name:   "with hash fragment",
			rawURL: "https://www.zhihu.com/p/111#section",
			want:   "111",
		},
		{
			name:   "with trailing slash",
			rawURL: "https://zhuanlan.zhihu.com/p/555/",
			want:   "555",
		},
		{
			name:   "empty URL",
			rawURL: "",
			want:   "",
		},
		{
			name:   "no match -- question URL",
			rawURL: "https://www.zhihu.com/question/12345",
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
				Name:     "z_c0",
				Value:    "session-token-value",
				Domain:   ".zhihu.com",
				Path:     "/",
				Expires:  1735689600,
				HTTPOnly: true,
				Secure:   true,
				SameSite: "lax",
			},
			{
				Name:    "q_c1",
				Value:   "another-cookie",
				Domain:  ".zhihu.com",
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
		if c.Path != orig.Path {
			t.Errorf("cookie[%d].Path = %q, want %q", i, c.Path, orig.Path)
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
		t.Errorf("RevokeAuth() = %v, want nil", err)
	}
}
