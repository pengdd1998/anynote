package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Chat tests with httptest mock server
// ---------------------------------------------------------------------------

func TestOpenAICompat_Chat_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request headers.
		if auth := r.Header.Get("Authorization"); auth != "Bearer test-api-key" {
			t.Errorf("Authorization = %q, want %q", auth, "Bearer test-api-key")
		}
		if ct := r.Header.Get("Content-Type"); ct != "application/json" {
			t.Errorf("Content-Type = %q, want %q", ct, "application/json")
		}

		// Verify request body.
		body, _ := io.ReadAll(r.Body)
		defer r.Body.Close()

		var req ChatRequest
		if err := json.Unmarshal(body, &req); err != nil {
			t.Errorf("unmarshal request: %v", err)
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		if req.Stream {
			t.Error("Stream should be false for Chat")
		}

		// Return a valid OpenAI-compatible response.
		resp := openaiChatResponse{
			ID:    "chatcmpl-test",
			Model: "gpt-4",
		}
		resp.Choices = append(resp.Choices, struct {
			Index        int           `json:"index"`
			Message      openaiMessage `json:"message"`
			FinishReason string        `json:"finish_reason"`
		}{
			Index:        0,
			Message:      openaiMessage{Role: "assistant", Content: "Hello! How can I help you?"},
			FinishReason: "stop",
		})

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	resp, err := provider.Chat(context.Background(), "test-api-key", server.URL, ChatRequest{
		Model:    "gpt-4",
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hello"}},
		Stream:   false,
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if resp.Content != "Hello! How can I help you?" {
		t.Errorf("Content = %q, want %q", resp.Content, "Hello! How can I help you?")
	}
	if resp.Model != "gpt-4" {
		t.Errorf("Model = %q, want %q", resp.Model, "gpt-4")
	}
}

func TestOpenAICompat_Chat_NonRetryable400(t *testing.T) {
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error": "invalid request"}`))
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	_, err := provider.Chat(context.Background(), "key", server.URL, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:     3,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err == nil {
		t.Error("expected error for 400 response")
	}
	if !strings.Contains(err.Error(), "400") {
		t.Errorf("error should mention status 400: %v", err)
	}
	// 400 should not be retried.
	if count := atomic.LoadInt32(&callCount); count != 1 {
		t.Errorf("callCount = %d, want 1 (no retries for 400)", count)
	}
}

func TestOpenAICompat_Chat_NonRetryable401(t *testing.T) {
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error": "invalid api key"}`))
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	_, err := provider.Chat(context.Background(), "bad-key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    3,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err == nil {
		t.Error("expected error for 401 response")
	}
	if count := atomic.LoadInt32(&callCount); count != 1 {
		t.Errorf("callCount = %d, want 1 (no retries for 401)", count)
	}
}

func TestOpenAICompat_Chat_NonRetryable403(t *testing.T) {
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.WriteHeader(http.StatusForbidden)
		w.Write([]byte(`{"error": "forbidden"}`))
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	_, err := provider.Chat(context.Background(), "key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    3,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err == nil {
		t.Error("expected error for 403 response")
	}
	if count := atomic.LoadInt32(&callCount); count != 1 {
		t.Errorf("callCount = %d, want 1 (no retries for 403)", count)
	}
}

func TestOpenAICompat_Chat_RetryOn429(t *testing.T) {
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count := atomic.AddInt32(&callCount, 1)
		if count < 3 {
			w.Header().Set("Retry-After", "0") // 0 seconds -- use minimal delay
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error": "rate limited"}`))
			return
		}
		// Succeed on third attempt.
		resp := openaiChatResponse{ID: "chatcmpl-ok", Model: "gpt-4"}
		resp.Choices = append(resp.Choices, struct {
			Index        int           `json:"index"`
			Message      openaiMessage `json:"message"`
			FinishReason string        `json:"finish_reason"`
		}{
			Message:      openaiMessage{Role: "assistant", Content: "retried OK"},
			FinishReason: "stop",
		})
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	resp, err := provider.Chat(context.Background(), "key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    3,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if resp.Content != "retried OK" {
		t.Errorf("Content = %q, want %q", resp.Content, "retried OK")
	}
	if count := atomic.LoadInt32(&callCount); count != 3 {
		t.Errorf("callCount = %d, want 3 (initial + 2 retries)", count)
	}
}

func TestOpenAICompat_Chat_RetryOn503(t *testing.T) {
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count := atomic.AddInt32(&callCount, 1)
		if count == 1 {
			w.WriteHeader(http.StatusServiceUnavailable)
			w.Write([]byte(`{"error": "overloaded"}`))
			return
		}
		resp := openaiChatResponse{ID: "chatcmpl-ok", Model: "gpt-4"}
		resp.Choices = append(resp.Choices, struct {
			Index        int           `json:"index"`
			Message      openaiMessage `json:"message"`
			FinishReason string        `json:"finish_reason"`
		}{
			Message:      openaiMessage{Role: "assistant", Content: "recovered"},
			FinishReason: "stop",
		})
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	resp, err := provider.Chat(context.Background(), "key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    3,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if resp.Content != "recovered" {
		t.Errorf("Content = %q, want %q", resp.Content, "recovered")
	}
	if count := atomic.LoadInt32(&callCount); count != 2 {
		t.Errorf("callCount = %d, want 2 (initial + 1 retry)", count)
	}
}

func TestOpenAICompat_Chat_RetryOn502(t *testing.T) {
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count := atomic.AddInt32(&callCount, 1)
		if count <= 2 {
			w.WriteHeader(http.StatusBadGateway)
			w.Write([]byte(`bad gateway`))
			return
		}
		resp := openaiChatResponse{ID: "chatcmpl-ok", Model: "gpt-4"}
		resp.Choices = append(resp.Choices, struct {
			Index        int           `json:"index"`
			Message      openaiMessage `json:"message"`
			FinishReason string        `json:"finish_reason"`
		}{
			Message:      openaiMessage{Role: "assistant", Content: "OK"},
			FinishReason: "stop",
		})
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	resp, err := provider.Chat(context.Background(), "key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    3,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if resp.Content != "OK" {
		t.Errorf("Content = %q, want %q", resp.Content, "OK")
	}
}

func TestOpenAICompat_Chat_RetryExhausted(t *testing.T) {
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"error": "always overloaded"}`))
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	_, err := provider.Chat(context.Background(), "key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    2,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err == nil {
		t.Error("expected error when retries exhausted")
	}
	if !strings.Contains(err.Error(), "failed after") {
		t.Errorf("error should mention retries exhausted: %v", err)
	}
	// Initial call + 2 retries = 3 total.
	if count := atomic.LoadInt32(&callCount); count != 3 {
		t.Errorf("callCount = %d, want 3", count)
	}
}

func TestOpenAICompat_Chat_RetryAfterHeader(t *testing.T) {
	var callCount int32
	var observedDelay time.Duration
	startTime := time.Now()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count := atomic.AddInt32(&callCount, 1)
		if count == 1 {
			w.Header().Set("Retry-After", "1") // 1 second
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`rate limited`))
			return
		}
		observedDelay = time.Since(startTime)
		resp := openaiChatResponse{ID: "chatcmpl-ok", Model: "gpt-4"}
		resp.Choices = append(resp.Choices, struct {
			Index        int           `json:"index"`
			Message      openaiMessage `json:"message"`
			FinishReason string        `json:"finish_reason"`
		}{
			Message:      openaiMessage{Role: "assistant", Content: "after retry-after"},
			FinishReason: "stop",
		})
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	resp, err := provider.Chat(context.Background(), "key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    3,
		RetryBaseDelay: 1 * time.Millisecond, // base delay is tiny, but Retry-After overrides
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if resp.Content != "after retry-after" {
		t.Errorf("Content = %q, want %q", resp.Content, "after retry-after")
	}
	// The Retry-After header of 1 second should have been respected.
	// We check that at least 800ms passed (allowing some tolerance).
	if observedDelay < 800*time.Millisecond {
		t.Errorf("observed delay = %v, should be >= ~1s (Retry-After header)", observedDelay)
	}
}

func TestOpenAICompat_Chat_RetryOn504(t *testing.T) {
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count := atomic.AddInt32(&callCount, 1)
		if count == 1 {
			w.WriteHeader(http.StatusGatewayTimeout)
			w.Write([]byte(`gateway timeout`))
			return
		}
		resp := openaiChatResponse{ID: "chatcmpl-ok", Model: "gpt-4"}
		resp.Choices = append(resp.Choices, struct {
			Index        int           `json:"index"`
			Message      openaiMessage `json:"message"`
			FinishReason string        `json:"finish_reason"`
		}{
			Message:      openaiMessage{Role: "assistant", Content: "after timeout"},
			FinishReason: "stop",
		})
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	resp, err := provider.Chat(context.Background(), "key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    3,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err != nil {
		t.Fatalf("Chat: %v", err)
	}
	if resp.Content != "after timeout" {
		t.Errorf("Content = %q, want %q", resp.Content, "after timeout")
	}
}

// ---------------------------------------------------------------------------
// ChatStream tests
// ---------------------------------------------------------------------------

func TestOpenAICompat_ChatStream_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		flusher, ok := w.(http.Flusher)
		if !ok {
			t.Fatal("ResponseWriter does not support flushing")
		}

		// Verify request.
		if auth := r.Header.Get("Authorization"); auth != "Bearer stream-key" {
			t.Errorf("Authorization = %q, want %q", auth, "Bearer stream-key")
		}

		body, _ := io.ReadAll(r.Body)
		r.Body.Close()
		var req ChatRequest
		json.Unmarshal(body, &req)
		if !req.Stream {
			t.Error("Stream should be true for ChatStream")
		}

		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("Cache-Control", "no-cache")

		// Send SSE events.
		events := []string{
			`{"id":"chatcmpl-1","choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":""}]}`,
			`{"id":"chatcmpl-1","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":""}]}`,
			`{"id":"chatcmpl-1","choices":[{"index":0,"delta":{"content":" World"},"finish_reason":""}]}`,
			`{"id":"chatcmpl-1","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}`,
		}
		for _, event := range events {
			fmt.Fprintf(w, "data: %s\n\n", event)
			flusher.Flush()
		}
		fmt.Fprintf(w, "data: [DONE]\n\n")
		flusher.Flush()
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	ch, err := provider.ChatStream(context.Background(), "stream-key", server.URL, ChatRequest{
		Model:    "gpt-4",
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hello"}},
		Stream:   true,
	})
	if err != nil {
		t.Fatalf("ChatStream: %v", err)
	}

	var content string
	var gotDone bool
	for chunk := range ch {
		if chunk.Error != "" {
			t.Fatalf("stream error: %s", chunk.Error)
		}
		content += chunk.Content
		if chunk.Done {
			gotDone = true
		}
	}
	if content != "Hello World" {
		t.Errorf("content = %q, want %q", content, "Hello World")
	}
	if !gotDone {
		t.Error("should have received Done chunk")
	}
}

func TestOpenAICompat_ChatStream_NonOKStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`service unavailable`))
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	_, err := provider.ChatStream(context.Background(), "key", server.URL, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "test"}},
		Stream:   true,
	})
	if err == nil {
		t.Error("expected error for non-200 streaming response")
	}
	if !strings.Contains(err.Error(), "503") {
		t.Errorf("error should mention 503: %v", err)
	}
}

func TestOpenAICompat_ChatStream_NotRetriedOnError(t *testing.T) {
	// Streaming connections are never retried.
	var callCount int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.WriteHeader(http.StatusTooManyRequests)
		w.Write([]byte(`rate limited`))
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	_, err := provider.ChatStream(context.Background(), "key", server.URL, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "test"}},
		Stream:   true,
	})
	if err == nil {
		t.Error("expected error")
	}
	// Should only be called once -- streaming is never retried.
	if count := atomic.LoadInt32(&callCount); count != 1 {
		t.Errorf("callCount = %d, want 1 (streaming never retried)", count)
	}
}

func TestOpenAICompat_ChatStream_EmptyStream(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		flusher := w.(http.Flusher)
		w.Header().Set("Content-Type", "text/event-stream")
		// Send only [DONE].
		fmt.Fprintf(w, "data: [DONE]\n\n")
		flusher.Flush()
	}))
	defer server.Close()

	provider := NewOpenAICompatProvider(nil)
	ch, err := provider.ChatStream(context.Background(), "key", server.URL, ChatRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "test"}},
		Stream:   true,
	})
	if err != nil {
		t.Fatalf("ChatStream: %v", err)
	}

	var content string
	for chunk := range ch {
		if chunk.Error != "" {
			t.Fatalf("stream error: %s", chunk.Error)
		}
		content += chunk.Content
	}
	if content != "" {
		t.Errorf("content = %q, want empty", content)
	}
}

// ---------------------------------------------------------------------------
// Retry helper tests
// ---------------------------------------------------------------------------

func TestIsRetriable(t *testing.T) {
	tests := []struct {
		code int
		want bool
	}{
		{http.StatusTooManyRequests, true},    // 429
		{http.StatusBadGateway, true},         // 502
		{http.StatusServiceUnavailable, true},  // 503
		{http.StatusGatewayTimeout, true},     // 504
		{http.StatusBadRequest, false},        // 400
		{http.StatusUnauthorized, false},       // 401
		{http.StatusForbidden, false},          // 403
		{http.StatusNotFound, false},           // 404
		{http.StatusMethodNotAllowed, false},   // 405
		{http.StatusInternalServerError, false}, // 500
		{http.StatusOK, false},                 // 200
	}

	for _, tt := range tests {
		t.Run(fmt.Sprintf("%d", tt.code), func(t *testing.T) {
			got := isRetriable(tt.code)
			if got != tt.want {
				t.Errorf("isRetriable(%d) = %v, want %v", tt.code, got, tt.want)
			}
		})
	}
}

func TestRetryBackoff(t *testing.T) {
	tests := []struct {
		attempt    int
		baseDelay  time.Duration
		wantDelay  time.Duration
	}{
		{1, 1 * time.Second, 1 * time.Second},
		{2, 1 * time.Second, 2 * time.Second},
		{3, 1 * time.Second, 4 * time.Second},
		{4, 1 * time.Second, 8 * time.Second},
		{1, 500 * time.Millisecond, 500 * time.Millisecond},
		{2, 500 * time.Millisecond, 1 * time.Second},
		{3, 500 * time.Millisecond, 2 * time.Second},
	}

	for _, tt := range tests {
		name := fmt.Sprintf("attempt%d_base%s", tt.attempt, tt.baseDelay)
		t.Run(name, func(t *testing.T) {
			got := retryBackoff(tt.attempt, tt.baseDelay)
			if got != tt.wantDelay {
				t.Errorf("retryBackoff(%d, %v) = %v, want %v", tt.attempt, tt.baseDelay, got, tt.wantDelay)
			}
		})
	}
}

func TestRetryBackoff_ZeroBaseDelay(t *testing.T) {
	got := retryBackoff(1, 0)
	if got != 1*time.Second {
		t.Errorf("retryBackoff(1, 0) = %v, want 1s (default)", got)
	}
}

func TestRetryBackoff_CapAtHighAttempt(t *testing.T) {
	// Attempt 20 should be capped to avoid overflow.
	got := retryBackoff(20, 1*time.Second)
	// shift is capped at 10, so delay = 1s * 2^10 = 1024s
	if got != 1024*time.Second {
		t.Errorf("retryBackoff(20, 1s) = %v, want 1024s", got)
	}
}

func TestParseRetryAfter(t *testing.T) {
	tests := []struct {
		value string
		want  time.Duration
	}{
		{"", 0},
		{"5", 5 * time.Second},
		{"30", 30 * time.Second},
		{"0", 0},
		{"-1", 0},
		{"not-a-number", 0}, // Invalid integer, no valid date.
	}

	for _, tt := range tests {
		t.Run(fmt.Sprintf("value_%q", tt.value), func(t *testing.T) {
			got := parseRetryAfter(tt.value)
			if got != tt.want {
				t.Errorf("parseRetryAfter(%q) = %v, want %v", tt.value, got, tt.want)
			}
		})
	}
}

func TestParseRetryAfter_HTTPDate(t *testing.T) {
	// An HTTP-date should be parseable and return the default 5s fallback.
	// We use a future date to ensure ParseTime succeeds.
	futureDate := "Tue, 18 Apr 2028 12:00:00 GMT"
	got := parseRetryAfter(futureDate)
	if got != 5*time.Second {
		t.Errorf("parseRetryAfter(%q) = %v, want 5s", futureDate, got)
	}
}

// ---------------------------------------------------------------------------
// Context cancellation test
// ---------------------------------------------------------------------------

func TestOpenAICompat_Chat_ContextCancelled(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Delay to give time for context cancellation.
		time.Sleep(200 * time.Millisecond)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"id":"x","model":"x","choices":[{"index":0,"message":{"role":"assistant","content":"ok"},"finish_reason":"stop"}]}`))
	}))
	defer server.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	provider := NewOpenAICompatProvider(nil)
	_, err := provider.Chat(ctx, "key", server.URL, ChatRequest{
		Messages:      []domain.ChatMessage{{Role: "user", Content: "test"}},
		MaxRetries:    0,
		RetryBaseDelay: 1 * time.Millisecond,
	})
	if err == nil {
		t.Error("expected error due to context cancellation")
	}
}
