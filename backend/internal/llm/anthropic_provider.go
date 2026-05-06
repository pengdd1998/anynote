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
	"strings"
	"time"

	"github.com/anynote/backend/internal/domain"
)

// AnthropicProvider implements Provider for the Anthropic Messages API.
// Unlike OpenAI, Anthropic uses a different endpoint, auth header, and
// message format where system prompts are a top-level field.
type AnthropicProvider struct {
	httpClient *http.Client
}

// NewAnthropicProvider creates an AnthropicProvider with a shared HTTP client.
func NewAnthropicProvider(client *http.Client) *AnthropicProvider {
	if client == nil {
		client = &http.Client{
			Transport: newSSRFSafeTransport(),
		}
	}
	return &AnthropicProvider{httpClient: client}
}

func (p *AnthropicProvider) Name() string { return "anthropic" }

// anthropicRequest is the Anthropic Messages API request format.
type anthropicRequest struct {
	Model     string              `json:"model"`
	MaxTokens int                 `json:"max_tokens"`
	System    string              `json:"system,omitempty"`
	Messages  []anthropicMessage  `json:"messages"`
	Stream    bool                `json:"stream"`
}

// anthropicMessage is a single message in the Anthropic format.
// Only "user" and "assistant" roles are supported.
type anthropicMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// toAnthropicMessages converts OpenAI-style messages to Anthropic format.
// System messages are extracted separately; user/assistant messages are
// converted directly. Other roles are dropped.
func toAnthropicMessages(msgs []domain.ChatMessage) (system string, messages []anthropicMessage) {
	var systemParts []string
	for _, m := range msgs {
		switch m.Role {
		case "system":
			systemParts = append(systemParts, m.Content)
		case "user", "assistant":
			messages = append(messages, anthropicMessage{
				Role:    m.Role,
				Content: m.Content,
			})
		}
	}
	return strings.Join(systemParts, "\n"), messages
}

func (p *AnthropicProvider) ChatStream(ctx context.Context, apiKey, baseURL string, req ChatRequest) (<-chan domain.StreamChunk, error) {
	if err := validateBaseURL(baseURL); err != nil {
		return nil, err
	}

	system, messages := toAnthropicMessages(req.Messages)
	maxTokens := 4096
	if req.MaxTokens != nil && *req.MaxTokens > 0 {
		maxTokens = *req.MaxTokens
	}

	aReq := anthropicRequest{
		Model:     req.Model,
		MaxTokens: maxTokens,
		System:    system,
		Messages:  messages,
		Stream:    true,
	}

	body, err := json.Marshal(aReq)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	streamCtx, cancel := context.WithTimeout(ctx, requestTimeout(req.Timeout))

	url := strings.TrimRight(baseURL, "/") + "/v1/messages"
	httpReq, err := http.NewRequestWithContext(streamCtx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		cancel()
		return nil, fmt.Errorf("create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("x-api-key", apiKey)
	httpReq.Header.Set("anthropic-version", "2023-06-01")

	resp, err := p.httpClient.Do(httpReq)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("send request: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1*1024*1024))
		_ = resp.Body.Close()
		cancel()
		if err != nil {
			return nil, fmt.Errorf("reading error response body: %w", err)
		}
		slog.Warn("Anthropic returned non-OK status", "status", resp.StatusCode, "body_len", len(respBody))
		return nil, fmt.Errorf("anthropic returned status %d", resp.StatusCode)
	}

	ch := make(chan domain.StreamChunk, 64)

	go func() {
		defer close(ch)
		defer resp.Body.Close()
		defer cancel()

		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

		for scanner.Scan() {
			select {
			case <-streamCtx.Done():
				return
			default:
			}

			line := scanner.Text()
			if !strings.HasPrefix(line, "data: ") {
				continue
			}

			data := strings.TrimPrefix(line, "data: ")

			var evt map[string]json.RawMessage
			if err := json.Unmarshal([]byte(data), &evt); err != nil {
				continue
			}

			// Extract event type
			var eventType string
			if raw, ok := evt["type"]; ok {
				_ = json.Unmarshal(raw, &eventType)
			}

			switch eventType {
			case "content_block_delta":
				var delta struct {
					Delta struct {
						Type string `json:"type"`
						Text string `json:"text"`
					} `json:"delta"`
				}
				if raw, ok := evt["delta"]; ok {
					_ = json.Unmarshal(raw, &delta)
				}
				if delta.Delta.Text != "" {
					ch <- domain.StreamChunk{Content: delta.Delta.Text}
				}
			case "message_stop":
				ch <- domain.StreamChunk{Done: true}
				return
			case "error":
				var errResp struct {
					Error struct {
						Message string `json:"message"`
					} `json:"error"`
				}
				_ = json.Unmarshal([]byte(data), &errResp)
				ch <- domain.StreamChunk{Error: errResp.Error.Message}
				return
			}
		}

		if err := scanner.Err(); err != nil {
			select {
			case <-streamCtx.Done():
			default:
				ch <- domain.StreamChunk{Error: err.Error()}
			}
		}
	}()

	return ch, nil
}

func (p *AnthropicProvider) Chat(ctx context.Context, apiKey, baseURL string, req ChatRequest) (*ChatResponse, error) {
	if err := validateBaseURL(baseURL); err != nil {
		return nil, err
	}

	system, messages := toAnthropicMessages(req.Messages)
	maxTokens := 4096
	if req.MaxTokens != nil && *req.MaxTokens > 0 {
		maxTokens = *req.MaxTokens
	}

	aReq := anthropicRequest{
		Model:     req.Model,
		MaxTokens: maxTokens,
		System:    system,
		Messages:  messages,
		Stream:    false,
	}

	body, err := json.Marshal(aReq)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	maxRetries := 3
	retryBaseDelay := time.Second

	ctx, cancel := context.WithTimeout(ctx, requestTimeout(req.Timeout))
	defer cancel()

	url := strings.TrimRight(baseURL, "/") + "/v1/messages"

	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			delay := retryBackoff(attempt, retryBaseDelay)
			slog.Info("retrying Anthropic request", "attempt", attempt, "delay", delay)
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(delay):
			}
		}

		httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			return nil, fmt.Errorf("create request: %w", err)
		}
		httpReq.Header.Set("Content-Type", "application/json")
		httpReq.Header.Set("x-api-key", apiKey)
		httpReq.Header.Set("anthropic-version", "2023-06-01")

		resp, err := p.httpClient.Do(httpReq)
		if err != nil {
			lastErr = fmt.Errorf("send request: %w", err)
			slog.Warn("Anthropic request network error", "attempt", attempt, "error", err)
			continue
		}

		respBody, readErr := io.ReadAll(io.LimitReader(resp.Body, 10*1024*1024))
		_ = resp.Body.Close()
		if readErr != nil {
			lastErr = fmt.Errorf("reading response body: %w", readErr)
			continue
		}

		// Non-retriable client errors
		if resp.StatusCode == http.StatusBadRequest ||
			resp.StatusCode == http.StatusUnauthorized ||
			resp.StatusCode == http.StatusForbidden {
			return nil, fmt.Errorf("anthropic returned status %d", resp.StatusCode)
		}

		// Retriable server/rate-limit errors
		if isRetriable(resp.StatusCode) {
			lastErr = fmt.Errorf("anthropic returned status %d", resp.StatusCode)
			if resp.StatusCode == http.StatusTooManyRequests {
				if after := parseRetryAfter(resp.Header.Get("Retry-After")); after > 0 {
					retryBaseDelay = after
				}
			}
			slog.Warn("Anthropic returned retriable status",
				"status", resp.StatusCode,
				"attempt", attempt,
				"max_retries", maxRetries,
			)
			continue
		}

		// Any other non-OK status is not retried
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("anthropic returned status %d", resp.StatusCode)
		}

		// Success path
		var aResp anthropicResponse
		if err := json.Unmarshal(respBody, &aResp); err != nil {
			return nil, fmt.Errorf("parse response: %w", err)
		}

		content := ""
		if len(aResp.Content) > 0 {
			content = aResp.Content[0].Text
		}

		return &ChatResponse{
			Content: content,
			Model:   aResp.Model,
			Usage: Usage{
				PromptTokens:     aResp.Usage.InputTokens,
				CompletionTokens: aResp.Usage.OutputTokens,
				TotalTokens:      aResp.Usage.InputTokens + aResp.Usage.OutputTokens,
			},
		}, nil
	}

	return nil, fmt.Errorf("anthropic request failed after %d retries: %w", maxRetries, lastErr)
}

// anthropicResponse is the Anthropic Messages API response format.
type anthropicResponse struct {
	ID      string `json:"id"`
	Model   string `json:"model"`
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	Usage struct {
		InputTokens  int `json:"input_tokens"`
		OutputTokens int `json:"output_tokens"`
	} `json:"usage"`
}
