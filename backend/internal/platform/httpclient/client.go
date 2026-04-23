// Package httpclient provides a shared HTTP client with proper timeouts
// for platform adapters that make outbound HTTP requests (Medium, WordPress,
// Webhook). Replaces direct use of http.DefaultClient which has no timeouts.
package httpclient

import (
	"crypto/tls"
	"net"
	"net/http"
	"time"
)

const (
	// dialTimeout is the maximum time to wait for a TCP connection.
	dialTimeout = 10 * time.Second
	// tlsHandshakeTimeout is the maximum time to wait for TLS handshake.
	tlsHandshakeTimeout = 30 * time.Second
	// overallTimeout is the overall request timeout.
	overallTimeout = 60 * time.Second
	// maxIdleConns is the maximum number of idle connections across all hosts.
	maxIdleConns = 100
	// maxIdleConnsPerHost is the maximum number of idle connections per host.
	maxIdleConnsPerHost = 10
	// idleConnTimeout is how long idle connections remain in the pool.
	idleConnTimeout = 90 * time.Second
)

// Shared is a package-level HTTP client with safe timeouts. Use this instead
// of http.DefaultClient in all platform adapters.
var Shared = &http.Client{
	Timeout: overallTimeout,
	Transport: &http.Transport{
		DialContext: (&net.Dialer{
			Timeout:   dialTimeout,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		TLSClientConfig:       &tls.Config{MinVersion: tls.VersionTLS12},
		TLSHandshakeTimeout:   tlsHandshakeTimeout,
		MaxIdleConns:          maxIdleConns,
		MaxIdleConnsPerHost:   maxIdleConnsPerHost,
		IdleConnTimeout:       idleConnTimeout,
		ResponseHeaderTimeout: 30 * time.Second,
		// ExpectContinueTimeout is set to a reasonable default so that
		// POST requests with Expect: 100-continue do not block.
		ExpectContinueTimeout: 1 * time.Second,
	},
}
