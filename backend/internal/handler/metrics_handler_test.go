package handler

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestMetricsMiddleware_RecordsMetrics(t *testing.T) {
	// Use a simple handler that returns 200.
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	handler := MetricsMiddleware(next)

	req := httptest.NewRequest("GET", "/test/path", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	// Verify the counter was incremented by reading the metrics endpoint.
	metricsReq := httptest.NewRequest("GET", "/metrics", nil)
	metricsRec := httptest.NewRecorder()
	MetricsHandler().ServeHTTP(metricsRec, metricsReq)
	body := metricsRec.Body.String()

	if !strings.Contains(body, "http_requests_total") {
		t.Error("metrics output does not contain http_requests_total")
	}
}

func TestMetricsMiddleware_RecordsNon200Status(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	})

	handler := MetricsMiddleware(next)

	req := httptest.NewRequest("POST", "/fail", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusInternalServerError)
	}
}

func TestMetricsMiddleware_FlushForwarding(t *testing.T) {
	// Verify the wrapped ResponseWriter forwards Flush calls.
	rw := newResponseWriterWithStatus(httptest.NewRecorder())
	// Should not panic.
	rw.Flush()
}

func TestMetricsHandler_ReturnsOK(t *testing.T) {
	req := httptest.NewRequest("GET", "/metrics", nil)
	rec := httptest.NewRecorder()
	MetricsHandler().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("MetricsHandler status = %d, want %d", rec.Code, http.StatusOK)
	}
}
