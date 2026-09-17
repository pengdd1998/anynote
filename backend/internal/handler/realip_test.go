package handler

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestTrustedRealIP(t *testing.T) {
	tests := []struct {
		name         string
		trusted      []string
		remoteAddr   string
		trueClientIP string
		realIP       string
		forwardedFor string
		want         string
	}{
		{
			name:       "untrusted peer ignores X-Real-IP",
			trusted:    []string{"10.0.0.0/8"},
			remoteAddr: "203.0.113.7:1234",
			realIP:     "1.2.3.4",
			want:       "203.0.113.7:1234",
		},
		{
			name:       "trusted peer adopts X-Real-IP",
			trusted:    []string{"10.0.0.0/8"},
			remoteAddr: "10.0.0.5:443",
			realIP:     "198.51.100.9",
			want:       "198.51.100.9",
		},
		{
			name:       "empty trusted list never adopts headers",
			remoteAddr: "10.0.0.5:443",
			realIP:     "198.51.100.9",
			want:       "10.0.0.5:443",
		},
		{
			name:         "X-Forwarded-For leftmost used",
			trusted:      []string{"172.16.0.0/12"},
			remoteAddr:   "172.18.0.2:3",
			forwardedFor: "198.51.100.10, 10.0.0.9",
			want:         "198.51.100.10",
		},
		{
			name:         "True-Client-IP wins over X-Real-IP",
			trusted:      []string{"172.16.0.0/12"},
			remoteAddr:   "172.18.0.2:3",
			trueClientIP: "198.51.100.11",
			realIP:       "1.1.1.1",
			want:         "198.51.100.11",
		},
		{
			name:         "garbage X-Real-IP falls through to XFF",
			trusted:      []string{"172.16.0.0/12"},
			remoteAddr:   "172.18.0.2:3",
			realIP:       "not-an-ip",
			forwardedFor: "198.51.100.12",
			want:         "198.51.100.12",
		},
		{
			name:         "garbage headers keep peer address",
			trusted:      []string{"172.16.0.0/12"},
			remoteAddr:   "172.18.0.2:3",
			realIP:       "not-an-ip",
			forwardedFor: "also bad",
			want:         "172.18.0.2:3",
		},
		{
			name:       "bare IP trusted entry",
			trusted:    []string{"192.0.2.5"},
			remoteAddr: "192.0.2.5:1",
			realIP:     "198.51.100.13",
			want:       "198.51.100.13",
		},
		{
			name:       "IPv6 trusted CIDR",
			trusted:    []string{"fd00::/8"},
			remoteAddr: "[fd00::1]:5",
			realIP:     "198.51.100.14",
			want:       "198.51.100.14",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mw, err := TrustedRealIP(tt.trusted)
			if err != nil {
				t.Fatalf("TrustedRealIP(%v): %v", tt.trusted, err)
			}
			var got string
			rec := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			req.RemoteAddr = tt.remoteAddr
			if tt.trueClientIP != "" {
				req.Header.Set("True-Client-IP", tt.trueClientIP)
			}
			if tt.realIP != "" {
				req.Header.Set("X-Real-IP", tt.realIP)
			}
			if tt.forwardedFor != "" {
				req.Header.Set("X-Forwarded-For", tt.forwardedFor)
			}
			mw(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				got = r.RemoteAddr
			})).ServeHTTP(rec, req)
			if got != tt.want {
				t.Errorf("RemoteAddr = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestTrustedRealIP_InvalidConfig(t *testing.T) {
	for _, bad := range []string{"nonsense", "10.0.0.0/99", "10.0.0.0/8,oops"} {
		if _, err := TrustedRealIP([]string{bad}); err == nil {
			t.Errorf("TrustedRealIP(%q) expected error, got nil", bad)
		}
	}
}
