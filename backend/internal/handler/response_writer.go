package handler

import "net/http"

// instrumentedResponseWriter wraps http.ResponseWriter to capture the HTTP status code.
type instrumentedResponseWriter struct {
	http.ResponseWriter
	statusCode   int
	wroteHeader  bool
}

func newInstrumentedResponseWriter(w http.ResponseWriter) *instrumentedResponseWriter {
	return &instrumentedResponseWriter{ResponseWriter: w, statusCode: http.StatusOK}
}

func (rw *instrumentedResponseWriter) WriteHeader(code int) {
	if !rw.wroteHeader {
		rw.statusCode = code
		rw.wroteHeader = true
	}
	rw.ResponseWriter.WriteHeader(code)
}

// Status returns the captured HTTP status code.
func (rw *instrumentedResponseWriter) Status() int {
	return rw.statusCode
}

// Flush forwards Flush calls to the underlying ResponseWriter when it
// implements http.Flusher. This is necessary for SSE streaming to work
// through middlewares that wrap the ResponseWriter.
func (rw *instrumentedResponseWriter) Flush() {
	if flusher, ok := rw.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}
