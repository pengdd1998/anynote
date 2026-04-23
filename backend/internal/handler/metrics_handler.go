package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Prometheus metrics registered once at package init time.
var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests processed, partitioned by method, path and status code.",
		},
		[]string{"method", "path", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Histogram of HTTP request durations in seconds, partitioned by method and path.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
}

// MetricsHandler returns an http.Handler that serves Prometheus metrics.
func MetricsHandler() http.Handler {
	return promhttp.Handler()
}

// responseWriterWithStatus wraps http.ResponseWriter to capture the status code
// for Prometheus instrumentation.
type responseWriterWithStatus struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func newResponseWriterWithStatus(w http.ResponseWriter) *responseWriterWithStatus {
	return &responseWriterWithStatus{ResponseWriter: w, status: http.StatusOK}
}

func (rw *responseWriterWithStatus) WriteHeader(code int) {
	if !rw.wroteHeader {
		rw.status = code
		rw.wroteHeader = true
	}
	rw.ResponseWriter.WriteHeader(code)
}

// Flush forwards Flush calls to the underlying ResponseWriter so that SSE
// streaming works through this middleware.
func (rw *responseWriterWithStatus) Flush() {
	if flusher, ok := rw.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}

// MetricsMiddleware instruments all HTTP requests with Prometheus counter and
// histogram metrics. It should be inserted before the RequestLogger so that
// every request is recorded regardless of downstream errors.
func MetricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := newResponseWriterWithStatus(w)

		next.ServeHTTP(rw, r)

		duration := time.Since(start).Seconds()
		// Use chi route pattern if available for low-cardinality path labels;
		// fall back to the raw path for non-chi routes.
		routePattern := r.URL.Path
		if rctx := chi.RouteContext(r.Context()); rctx != nil {
			if pattern := rctx.RoutePattern(); pattern != "" {
				routePattern = pattern
			}
		}

		httpRequestsTotal.WithLabelValues(r.Method, routePattern, strconv.Itoa(rw.status)).Inc()
		httpRequestDuration.WithLabelValues(r.Method, routePattern).Observe(duration)
	})
}
