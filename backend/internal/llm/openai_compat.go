package llm

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/anynote/backend/internal/domain"
)

// OpenAICompatProvider implements Provider for OpenAI-compatible APIs.
// Covers: OpenAI, DeepSeek, Qwen, and any OpenAI-compatible endpoint.
type OpenAICompatProvider struct{}

func (p *OpenAICompatProvider) Name() string { return "openai_compat" }

func (p *OpenAICompatProvider) ChatStream(ctx context.Context, apiKey, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error) {
	req.Stream = true

	// Streaming connections are never retried -- doing so would duplicate
	// output the client has already started consuming.
	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := strings.TrimRight(baseURL, "/") + "/chat/completions"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("send request: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		return nil, fmt.Errorf("LLM returned %d: %s", resp.StatusCode, string(respBody))
	}

	ch := make(chan domain.StreamChunk, 64)

	go func() {
		defer close(ch)
		defer resp.Body.Close()

		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

		for scanner.Scan() {
			line := scanner.Text()

			if !strings.HasPrefix(line, "data: ") {
				continue
			}

			data := strings.TrimPrefix(line, "data: ")
			if data == "[DONE]" {
				ch <- domain.StreamChunk{Done: true}
				return
			}

			var sseResp openaiStreamResponse
			if err := json.Unmarshal([]byte(data), &sseResp); err != nil {
				continue
			}

			if len(sseResp.Choices) > 0 {
				content := sseResp.Choices[0].Delta.Content
				if content != "" {
					ch <- domain.StreamChunk{Content: content}
				}
				if sseResp.Choices[0].FinishReason == "stop" {
					ch <- domain.StreamChunk{Done: true}
					return
				}
			}
		}

		if err := scanner.Err(); err != nil {
			ch <- domain.StreamChunk{Error: err.Error()}
		}
	}()

	return ch, nil
}

func (p *OpenAICompatProvider) Chat(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
	req.Stream = false

	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := strings.TrimRight(baseURL, "/") + "/chat/completions"

	maxRetries := req.MaxRetries
	retryBaseDelay := req.RetryBaseDelay

	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			delay := retryBackoff(attempt, retryBaseDelay)
			slog.Info("retrying LLM request", "attempt", attempt, "delay", delay)

			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(delay):
			}
		}

		// Re-create the request body reader for each attempt since the
		// previous response consumed it.
		httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			return nil, fmt.Errorf("create request: %w", err)
		}

		httpReq.Header.Set("Content-Type", "application/json")
		httpReq.Header.Set("Authorization", "Bearer "+apiKey)

		client := &http.Client{Timeout: 120 * time.Second}
		resp, err := client.Do(httpReq)
		if err != nil {
			lastErr = fmt.Errorf("send request: %w", err)
			// Network errors are retriable
			slog.Warn("LLM request network error", "attempt", attempt, "error", err)
			continue
		}

		respBody, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			lastErr = fmt.Errorf("read response: %w", readErr)
			continue
		}

		// Non-retriable client errors
		if resp.StatusCode == http.StatusBadRequest ||
			resp.StatusCode == http.StatusUnauthorized ||
			resp.StatusCode == http.StatusForbidden {
			return nil, fmt.Errorf("LLM returned %d: %s", resp.StatusCode, string(respBody))
		}

		// Retriable server/rate-limit errors
		if isRetriable(resp.StatusCode) {
			lastErr = fmt.Errorf("LLM returned %d: %s", resp.StatusCode, string(respBody))

			// Respect Retry-After header for 429 responses
			if resp.StatusCode == http.StatusTooManyRequests {
				if after := parseRetryAfter(resp.Header.Get("Retry-After")); after > 0 {
					retryBaseDelay = after
				}
			}

			slog.Warn("LLM returned retriable status",
				"status", resp.StatusCode,
				"attempt", attempt,
				"max_retries", maxRetries,
			)
			continue
		}

		// Any other non-OK status is not retried
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("LLM returned %d: %s", resp.StatusCode, string(respBody))
		}

		// Success path
		var chatResp openaiChatResponse
		if err := json.Unmarshal(respBody, &chatResp); err != nil {
			return nil, fmt.Errorf("parse response: %w", err)
		}

		if len(chatResp.Choices) == 0 {
			return nil, fmt.Errorf("no choices in response")
		}

		return &ChatResponse{
			Content: chatResp.Choices[0].Message.Content,
			Model:   chatResp.Model,
		}, nil
	}

	return nil, fmt.Errorf("LLM request failed after %d retries: %w", maxRetries, lastErr)
}

// ── Retry helpers ──────────────────────────────────

// isRetriable returns true for HTTP status codes that warrant a retry.
func isRetriable(statusCode int) bool {
	switch statusCode {
	case http.StatusTooManyRequests, // 429
		http.StatusBadGateway,        // 502
		http.StatusServiceUnavailable, // 503
		http.StatusGatewayTimeout:    // 504
		return true
	default:
		return false
	}
}

// retryBackoff computes exponential backoff duration for the given attempt
// number (1-based). Delay = baseDelay * 2^(attempt-1), yielding 1s, 2s, 4s
// with a default base of 1s.
func retryBackoff(attempt int, baseDelay time.Duration) time.Duration {
	if baseDelay <= 0 {
		baseDelay = 1 * time.Second
	}
	shift := uint(attempt - 1)
	if shift > 10 {
		shift = 10 // cap to avoid overflow
	}
	return baseDelay * time.Duration(1<<shift)
}

// parseRetryAfter parses the Retry-After header value. It supports both
// integer seconds and HTTP-date formats (for the latter it falls back to a
// reasonable default).
func parseRetryAfter(value string) time.Duration {
	if value == "" {
		return 0
	}
	// Try integer seconds first
	if seconds, err := strconv.Atoi(value); err == nil && seconds > 0 {
		return time.Duration(seconds) * time.Second
	}
	// Try HTTP-date parsing (rarely used; treat as 5s default)
	if _, err := http.ParseTime(value); err == nil {
		return 5 * time.Second
	}
	return 0
}

// ── OpenAI API response types ──────────────────────

type openaiStreamResponse struct {
	ID      string `json:"id"`
	Choices []struct {
		Index        int               `json:"index"`
		Delta        openaiStreamDelta `json:"delta"`
		FinishReason string            `json:"finish_reason"`
	} `json:"choices"`
}

type openaiStreamDelta struct {
	Role    string `json:"role,omitempty"`
	Content string `json:"content,omitempty"`
}

type openaiChatResponse struct {
	ID      string `json:"id"`
	Model   string `json:"model"`
	Choices []struct {
		Index        int           `json:"index"`
		Message      openaiMessage `json:"message"`
		FinishReason string        `json:"finish_reason"`
	} `json:"choices"`
	Usage struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
		TotalTokens      int `json:"total_tokens"`
	} `json:"usage"`
}

type openaiMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}
