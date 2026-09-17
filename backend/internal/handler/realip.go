package handler

import (
	"fmt"
	"net"
	"net/http"
	"strings"
)

// parseTrustedProxies converts configured entries (CIDRs or bare IPs) into
// networks. Bare IPs become /32 (IPv4) or /128 (IPv6).
func parseTrustedProxies(entries []string) ([]*net.IPNet, error) {
	var nets []*net.IPNet
	for _, e := range entries {
		e = strings.TrimSpace(e)
		if e == "" {
			continue
		}
		if !strings.Contains(e, "/") {
			if ip := net.ParseIP(e); ip == nil {
				return nil, fmt.Errorf("invalid trusted proxy %q: not an IP or CIDR", e)
			} else if ip.To4() != nil {
				e += "/32"
			} else {
				e += "/128"
			}
		}
		_, ipNet, err := net.ParseCIDR(e)
		if err != nil {
			return nil, fmt.Errorf("invalid trusted proxy %q: %w", e, err)
		}
		nets = append(nets, ipNet)
	}
	return nets, nil
}

// TrustedRealIP sets r.RemoteAddr to the client IP reported via
// True-Client-IP / X-Real-IP / X-Forwarded-For, but only when the direct
// peer is inside one of trustedProxies (IPs or CIDRs, e.g. the edge
// reverse proxy's Docker network). chi's middleware.RealIP trusts these
// headers unconditionally, which lets any direct client spoof rate-limit
// keys and log entries; here an untrusted peer keeps its socket address.
// An empty list never trusts any header.
func TrustedRealIP(trustedProxies []string) (func(http.Handler) http.Handler, error) {
	nets, err := parseTrustedProxies(trustedProxies)
	if err != nil {
		return nil, err
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if len(nets) > 0 && peerTrusted(r.RemoteAddr, nets) {
				if ip := forwardedClientIP(r); ip != "" {
					r.RemoteAddr = ip
				}
			}
			next.ServeHTTP(w, r)
		})
	}, nil
}

// peerTrusted reports whether the socket peer address falls inside any
// trusted network.
func peerTrusted(remoteAddr string, nets []*net.IPNet) bool {
	ip := peerIP(remoteAddr)
	if ip == nil {
		return false
	}
	for _, n := range nets {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

func peerIP(remoteAddr string) net.IP {
	host := remoteAddr
	if h, _, err := net.SplitHostPort(remoteAddr); err == nil {
		host = h
	}
	return net.ParseIP(host)
}

// forwardedClientIP returns the first parseable client IP from the proxy
// headers, in the same precedence chi's RealIP used: True-Client-IP,
// X-Real-IP, then the leftmost X-Forwarded-For entry.
func forwardedClientIP(r *http.Request) string {
	for _, candidate := range []string{r.Header.Get("True-Client-IP"), r.Header.Get("X-Real-IP")} {
		if ip := strings.TrimSpace(candidate); ip != "" && net.ParseIP(ip) != nil {
			return ip
		}
	}
	xff := strings.TrimSpace(r.Header.Get("X-Forwarded-For"))
	if xff == "" {
		return ""
	}
	if i := strings.IndexByte(xff, ','); i >= 0 {
		xff = xff[:i]
	}
	if ip := strings.TrimSpace(xff); net.ParseIP(ip) != nil {
		return ip
	}
	return ""
}
