package handler

import (
	"github.com/prometheus/client_golang/prometheus"
)

// AI-specific Prometheus metrics. Registered once at package init time.
var (
	// aiProxyRequestsTotal counts all AI proxy requests by provider, mode,
	// and outcome (success/error).
	aiProxyRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "ai_proxy_requests_total",
			Help: "Total number of AI proxy requests, partitioned by provider, mode and status.",
		},
		[]string{"provider", "mode", "status"},
	)

	// aiProxyTokensTotal tracks token usage reported by the LLM provider.
	// The "type" label is either "prompt" or "completion".
	aiProxyTokensTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "ai_proxy_tokens_total",
			Help: "Total tokens consumed through the AI proxy, partitioned by provider and type.",
		},
		[]string{"provider", "type"},
	)

	// aiProxyActiveStreams tracks the number of currently active SSE streaming
	// connections to the AI proxy.
	aiProxyActiveStreams = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "ai_proxy_active_streams",
			Help: "Number of currently active SSE streaming connections to the AI proxy.",
		},
	)
)

func init() {
	prometheus.MustRegister(aiProxyRequestsTotal)
	prometheus.MustRegister(aiProxyTokensTotal)
	prometheus.MustRegister(aiProxyActiveStreams)
}

// IncAIProxyRequest increments the AI proxy request counter.
func IncAIProxyRequest(provider, mode, status string) {
	aiProxyRequestsTotal.WithLabelValues(provider, mode, status).Inc()
}

// AddAIProxyTokens adds token counts to the AI proxy token counter.
func AddAIProxyTokens(provider string, promptTokens, completionTokens int) {
	if promptTokens > 0 {
		aiProxyTokensTotal.WithLabelValues(provider, "prompt").Add(float64(promptTokens))
	}
	if completionTokens > 0 {
		aiProxyTokensTotal.WithLabelValues(provider, "completion").Add(float64(completionTokens))
	}
}

// IncAIActiveStreams increments the active SSE stream gauge.
func IncAIActiveStreams() {
	aiProxyActiveStreams.Inc()
}

// DecAIActiveStreams decrements the active SSE stream gauge.
func DecAIActiveStreams() {
	aiProxyActiveStreams.Dec()
}
