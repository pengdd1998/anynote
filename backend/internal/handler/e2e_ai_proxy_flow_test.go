package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// E2E AI Proxy Flow: streaming SSE, quota enforcement, validation
// ---------------------------------------------------------------------------

// TestE2EAIProxyFlow_SSEStreaming verifies that a streaming AI proxy request
// returns SSE-formatted chunks over a real HTTP server round-trip.
func TestE2EAIProxyFlow_SSEStreaming(t *testing.T) {
	userID := uuid.New()

	aiSvc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			if uid != userID.String() {
				t.Errorf("proxy: userID = %q, want %q", uid, userID.String())
			}
			if !req.Stream {
				t.Error("proxy: Stream should be true")
			}

			ch := make(chan domain.StreamChunk, 3)
			ch <- domain.StreamChunk{Content: "Hello "}
			ch <- domain.StreamChunk{Content: "from AI"}
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}

	quotaSvc := &mockQuotaSvcForHandler{}
	h := &AIHandler{aiService: aiSvc, quotaSvc: quotaSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/ai/proxy", h.Proxy)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Summarize my note"},
		},
		Stream: true,
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/ai/proxy", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	ct := resp.Header.Get("Content-Type")
	if ct != "text/event-stream" {
		t.Errorf("Content-Type = %q, want %q", ct, "text/event-stream")
	}

	// Read the full SSE body and verify structure.
	sseBytes, _ := io.ReadAll(resp.Body)
	sseBody := string(sseBytes)

	if !strings.Contains(sseBody, "data:") {
		t.Error("SSE response should contain data lines")
	}
	if !strings.Contains(sseBody, "Hello ") {
		t.Error("SSE response should contain first chunk content")
	}
	if !strings.Contains(sseBody, "from AI") {
		t.Error("SSE response should contain second chunk content")
	}
	if !strings.Contains(sseBody, `"done":true`) {
		t.Error("SSE response should contain done:true marker")
	}
}

// TestE2EAIProxyFlow_QuotaExceeded verifies that a quota-exceeded error
// from the service returns 429 with the correct response body.
func TestE2EAIProxyFlow_QuotaExceeded(t *testing.T) {
	userID := uuid.New()

	aiSvc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return nil, service.ErrQuotaExceeded
		},
	}

	quotaSvc := &mockQuotaSvcForHandler{}
	h := &AIHandler{aiService: aiSvc, quotaSvc: quotaSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/ai/proxy", h.Proxy)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hi"},
		},
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/ai/proxy", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusTooManyRequests)
	}

	var quotaResp domain.QuotaExceededResponse
	if err := json.NewDecoder(resp.Body).Decode(&quotaResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if quotaResp.Error != "quota_exceeded" {
		t.Errorf("error = %q, want %q", quotaResp.Error, "quota_exceeded")
	}
}

// TestE2EAIProxyFlow_MissingAuth verifies that a request without an
// Authorization header returns 401.
func TestE2EAIProxyFlow_MissingAuth(t *testing.T) {
	aiSvc := &mockAIProxyService{}
	quotaSvc := &mockQuotaSvcForHandler{}
	h := &AIHandler{aiService: aiSvc, quotaSvc: quotaSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/ai/proxy", h.Proxy)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hi"},
		},
	})

	resp, err := server.Client().Post(server.URL+"/api/v1/ai/proxy", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}

// TestE2EAIProxyFlow_EmptyMessages verifies that a request with an empty
// messages array returns 400 with a validation error.
func TestE2EAIProxyFlow_EmptyMessages(t *testing.T) {
	userID := uuid.New()

	aiSvc := &mockAIProxyService{}
	quotaSvc := &mockQuotaSvcForHandler{}
	h := &AIHandler{aiService: aiSvc, quotaSvc: quotaSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/ai/proxy", h.Proxy)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{},
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/ai/proxy", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&errResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "validation_error")
	}
	if !strings.Contains(errResp.Error.Message, "required") {
		t.Errorf("error message = %q, should mention 'required'", errResp.Error.Message)
	}
}

// TestE2EAIProxyFlow_TooManyMessages verifies that a request with more
// than 100 messages returns 400 with a validation error.
func TestE2EAIProxyFlow_TooManyMessages(t *testing.T) {
	userID := uuid.New()

	aiSvc := &mockAIProxyService{}
	quotaSvc := &mockQuotaSvcForHandler{}
	h := &AIHandler{aiService: aiSvc, quotaSvc: quotaSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/ai/proxy", h.Proxy)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	// Build a request with 101 messages to exceed the limit.
	tooManyMessages := make([]domain.ChatMessage, 101)
	for i := range tooManyMessages {
		tooManyMessages[i] = domain.ChatMessage{Role: "user", Content: "msg"}
	}

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: tooManyMessages,
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/ai/proxy", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&errResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "validation_error")
	}
	if !strings.Contains(errResp.Error.Message, "Too many messages") {
		t.Errorf("error message = %q, should mention 'Too many messages'", errResp.Error.Message)
	}
}

// TestE2EAIProxyFlow_NonStreamSuccess verifies a non-streaming proxy request
// returns a complete JSON response over a real HTTP server round-trip.
func TestE2EAIProxyFlow_NonStreamSuccess(t *testing.T) {
	userID := uuid.New()

	aiSvc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			ch := make(chan domain.StreamChunk, 2)
			ch <- domain.StreamChunk{Content: "Summary: "}
			ch <- domain.StreamChunk{Content: "This is a test note.", Done: true}
			close(ch)
			return ch, nil
		},
	}

	quotaSvc := &mockQuotaSvcForHandler{}
	h := &AIHandler{aiService: aiSvc, quotaSvc: quotaSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/ai/proxy", h.Proxy)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Summarize"},
		},
		Stream: false,
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/ai/proxy", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode: %v", err)
	}

	content, _ := result["content"].(string)
	if content != "Summary: This is a test note." {
		t.Errorf("content = %q, want %q", content, "Summary: This is a test note.")
	}
	done, _ := result["done"].(bool)
	if !done {
		t.Error("done should be true")
	}
}
