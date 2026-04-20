package handler

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5/middleware"
)

// TestResponseWriter_WriteHeader_CapturesCode verifies that the responseWriter
// wrapper correctly records the status code passed to WriteHeader.
func TestResponseWriter_WriteHeader_CapturesCode(t *testing.T) {
	rec := httptest.NewRecorder()
	rw := newResponseWriter(rec)

	// Default status should be 200.
	if rw.status != http.StatusOK {
		t.Errorf("initial status = %d, want %d", rw.status, http.StatusOK)
	}

	rw.WriteHeader(http.StatusCreated)
	if rw.status != http.StatusCreated {
		t.Errorf("status after WriteHeader(201) = %d, want %d", rw.status, http.StatusCreated)
	}
	if rec.Code != http.StatusCreated {
		t.Errorf("underlying recorder code = %d, want %d", rec.Code, http.StatusCreated)
	}
}

// TestResponseWriter_WriteHeader_MultipleCalls verifies that the last
// WriteHeader call wins, matching http.ResponseWriter semantics.
func TestResponseWriter_WriteHeader_MultipleCalls(t *testing.T) {
	rec := httptest.NewRecorder()
	rw := newResponseWriter(rec)

	rw.WriteHeader(http.StatusBadRequest)
	rw.WriteHeader(http.StatusInternalServerError)

	if rw.status != http.StatusInternalServerError {
		t.Errorf("status = %d, want %d (last WriteHeader call should win)", rw.status, http.StatusInternalServerError)
	}
}

// TestResponseWriter_Flush_Forwarded verifies that Flush delegates to the
// underlying http.ResponseWriter when it implements http.Flusher.
func TestResponseWriter_Flush_Forwarded(t *testing.T) {
	rec := httptest.NewRecorder()

	// httptest.ResponseRecorder does NOT implement http.Flusher, so we use a
	// custom wrapper that records whether Flush was called.
	flushed := false
	rw := newResponseWriter(flusherRespWriter{ResponseWriter: rec, flushed: &flushed})
	rw.Flush()

	if !flushed {
		t.Error("Flush should have been forwarded to the underlying Flusher")
	}
}

// flusherRespWriter is a test helper that implements http.Flusher.
type flusherRespWriter struct {
	http.ResponseWriter
	flushed *bool
}

func (f flusherRespWriter) Flush() {
	*f.flushed = true
}

// TestResponseWriter_Flush_NonFlusher verifies that Flush does not panic when
// the underlying ResponseWriter does not implement http.Flusher.
func TestResponseWriter_Flush_NonFlusher(t *testing.T) {
	rec := httptest.NewRecorder()
	rw := newResponseWriter(rec)

	// Should not panic.
	rw.Flush()
}

// TestRequestLogger_CallsNextForNormalPaths verifies that the middleware
// delegates to the next handler for non-skipped paths.
func TestRequestLogger_CallsNextForNormalPaths(t *testing.T) {
	called := false
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	})

	handler := middleware.RequestID(RequestLogger(next))

	req := httptest.NewRequest("GET", "/api/v1/notes", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if !called {
		t.Error("next handler should be called for normal paths")
	}
	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}

// TestRequestLogger_SkippedPathsStillCallNext verifies that skipped paths
// (/health, /ready, /metrics) still invoke the next handler even though
// logging is suppressed.
func TestRequestLogger_SkippedPathsStillCallNext(t *testing.T) {
	paths := []string{"/health", "/ready", "/metrics"}
	for _, path := range paths {
		t.Run(path, func(t *testing.T) {
			called := false
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				called = true
				w.WriteHeader(http.StatusOK)
			})

			handler := RequestLogger(next)

			req := httptest.NewRequest("GET", path, nil)
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			if !called {
				t.Errorf("next handler should still be called for %s", path)
			}
			if rec.Code != http.StatusOK {
				t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
			}
		})
	}
}

// TestRequestLogger_SkippedPathsNoRequestIDHeader verifies that skipped paths
// do NOT get the X-Request-ID header set by RequestLogger (because the
// responseWriter wrapper is not used for skipped paths).
func TestRequestLogger_SkippedPathsNoRequestIDHeader(t *testing.T) {
	paths := []string{"/health", "/ready", "/metrics"}
	for _, path := range paths {
		t.Run(path, func(t *testing.T) {
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
			})

			handler := RequestLogger(next)

			req := httptest.NewRequest("GET", path, nil)
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			// For skipped paths RequestLogger passes the original writer through,
			// so no X-Request-ID is set by RequestLogger itself.
			reqID := rec.Header().Get("X-Request-ID")
			if reqID != "" {
				t.Errorf("X-Request-ID should be empty for skipped path %s, got %q", path, reqID)
			}
		})
	}
}

// TestRequestLogger_StatusCodeTracking verifies that different status codes
// from the inner handler are correctly observed through the middleware.
func TestRequestLogger_StatusCodeTracking(t *testing.T) {
	tests := []struct {
		name       string
		statusCode int
	}{
		{"OK", http.StatusOK},
		{"Created", http.StatusCreated},
		{"BadRequest", http.StatusBadRequest},
		{"NotFound", http.StatusNotFound},
		{"InternalServerError", http.StatusInternalServerError},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(tt.statusCode)
			})

			handler := middleware.RequestID(RequestLogger(next))

			req := httptest.NewRequest("GET", "/api/v1/test", nil)
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			if rec.Code != tt.statusCode {
				t.Errorf("status = %d, want %d", rec.Code, tt.statusCode)
			}
		})
	}
}

// TestRequestLogger_DefaultStatusOK verifies that when the inner handler does
// NOT call WriteHeader, the default status remains 200.
func TestRequestLogger_DefaultStatusOK(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Write body without calling WriteHeader; Go defaults to 200.
		w.Write([]byte("ok"))
	})

	handler := middleware.RequestID(RequestLogger(next))

	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}
