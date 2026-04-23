package llm

import (
	"github.com/prometheus/client_golang/prometheus"
)

// Prometheus metric for circuit breaker state per provider.
// Values: 0=closed, 1=open, 2=half-open.
var circuitBreakerState = prometheus.NewGaugeVec(
	prometheus.GaugeOpts{
		Name: "llm_circuit_breaker_state",
		Help: "Current state of the LLM provider circuit breaker. 0=closed, 1=open, 2=half-open.",
	},
	[]string{"provider"},
)

func init() {
	prometheus.MustRegister(circuitBreakerState)
}

// setCircuitBreakerMetric updates the Prometheus gauge for the given provider.
func setCircuitBreakerMetric(provider string, state State) {
	circuitBreakerState.WithLabelValues(provider).Set(float64(state))
}
