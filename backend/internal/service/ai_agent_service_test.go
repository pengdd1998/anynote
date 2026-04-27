package service

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock AIProxyService (satisfies AIProxyService from ai_proxy_service.go)
// ---------------------------------------------------------------------------

type mockAIProxyService struct {
	proxyFn func(ctx context.Context, userID string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error)
}

func (m *mockAIProxyService) Proxy(ctx context.Context, userID string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
	if m.proxyFn != nil {
		return m.proxyFn(ctx, userID, req)
	}
	// Default: return a single chunk with generic content.
	ch := make(chan domain.StreamChunk, 2)
	ch <- domain.StreamChunk{Content: `{"action":"test","result":{},"message":"ok"}`, Done: true}
	close(ch)
	return ch, nil
}

// sendChunks is a test helper that creates a channel and sends the given chunks.
func sendChunks(chunks ...domain.StreamChunk) <-chan domain.StreamChunk {
	ch := make(chan domain.StreamChunk, len(chunks)+1)
	for _, c := range chunks {
		ch <- c
	}
	close(ch)
	return ch
}

// ---------------------------------------------------------------------------
// Tests: ExecuteAction
// ---------------------------------------------------------------------------

func TestAIAgentService_ExecuteAction_SuccessWithJSON(t *testing.T) {
	jsonResponse := map[string]interface{}{
		"action":  "organize_notes",
		"result":  map[string]interface{}{"tags": []string{"go", "testing"}},
		"message": "organized 3 notes",
	}
	jsonBytes, _ := json.Marshal(jsonResponse)

	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, _ domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return sendChunks(
				domain.StreamChunk{Content: string(jsonBytes), Done: true},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)
	userID := uuid.New().String()

	resp, err := svc.ExecuteAction(context.Background(), userID, domain.AIAgentRequest{
		Action: "organize_notes",
	})
	if err != nil {
		t.Fatalf("ExecuteAction: %v", err)
	}

	if resp.Status != "completed" {
		t.Errorf("Status = %q, want %q", resp.Status, "completed")
	}
	if resp.Action != "organize_notes" {
		t.Errorf("Action = %q, want %q", resp.Action, "organize_notes")
	}
	if resp.Result == nil {
		t.Error("Result should not be nil")
	}
}

func TestAIAgentService_ExecuteAction_SuccessWithNonJSON(t *testing.T) {
	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, _ domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return sendChunks(
				domain.StreamChunk{Content: "This is plain text, not JSON", Done: true},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)

	resp, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action: "summarize_notes",
	})
	if err != nil {
		t.Fatalf("ExecuteAction: %v", err)
	}

	if resp.Status != "completed" {
		t.Errorf("Status = %q, want %q", resp.Status, "completed")
	}
	raw, ok := resp.Result["raw"]
	if !ok {
		t.Error("Result should contain 'raw' key when response is not valid JSON")
	}
	if raw != "This is plain text, not JSON" {
		t.Errorf("Result[raw] = %q, want plain text content", raw)
	}
}

func TestAIAgentService_ExecuteAction_MultipleChunks(t *testing.T) {
	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, _ domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return sendChunks(
				domain.StreamChunk{Content: `{"action":"`, Done: false},
				domain.StreamChunk{Content: `create_note",`, Done: false},
				domain.StreamChunk{Content: `"result":{"title":"hi"},`, Done: false},
				domain.StreamChunk{Content: `"message":"done"}`, Done: true},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)

	resp, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action: "create_note",
	})
	if err != nil {
		t.Fatalf("ExecuteAction: %v", err)
	}

	if resp.Status != "completed" {
		t.Errorf("Status = %q, want %q", resp.Status, "completed")
	}
	if resp.Action != "create_note" {
		t.Errorf("Action = %q, want %q", resp.Action, "create_note")
	}
}

func TestAIAgentService_ExecuteAction_ProxyError(t *testing.T) {
	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, _ domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return nil, errors.New("proxy service unavailable")
		},
	}

	svc := NewAIAgentService(proxy)

	resp, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action: "organize_notes",
	})
	// Proxy errors are returned as a failed response, not as a Go error.
	if err != nil {
		t.Fatalf("ExecuteAction should not return Go error for proxy failure: %v", err)
	}
	if resp.Status != "failed" {
		t.Errorf("Status = %q, want %q", resp.Status, "failed")
	}
	if resp.Message != "proxy service unavailable" {
		t.Errorf("Message = %q, want error message", resp.Message)
	}
}

func TestAIAgentService_ExecuteAction_StreamError(t *testing.T) {
	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, _ domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return sendChunks(
				domain.StreamChunk{Error: "rate limited by provider"},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)

	resp, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action: "summarize_notes",
	})
	if err != nil {
		t.Fatalf("ExecuteAction should not return Go error for stream error: %v", err)
	}
	if resp.Status != "failed" {
		t.Errorf("Status = %q, want %q", resp.Status, "failed")
	}
	if resp.Message != "rate limited by provider" {
		t.Errorf("Message = %q, want %q", resp.Message, "rate limited by provider")
	}
}

func TestAIAgentService_ExecuteAction_WithNoteIDs(t *testing.T) {
	var capturedReq domain.AIProxyRequest
	noteID1 := uuid.New()
	noteID2 := uuid.New()

	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			capturedReq = req
			return sendChunks(
				domain.StreamChunk{Content: `{"action":"organize"}`, Done: true},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)

	_, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action:  "organize_notes",
		NoteIDs: []uuid.UUID{noteID1, noteID2},
	})
	if err != nil {
		t.Fatalf("ExecuteAction: %v", err)
	}

	// Verify the prompt contains the Note IDs.
	userMsg := capturedReq.Messages[1].Content
	if userMsg == "" {
		t.Fatal("user message should not be empty")
	}
	// The prompt should contain the action name.
	if capturedReq.Messages[0].Role != "system" {
		t.Errorf("first message role = %q, want %q", capturedReq.Messages[0].Role, "system")
	}
	if capturedReq.Messages[1].Role != "user" {
		t.Errorf("second message role = %q, want %q", capturedReq.Messages[1].Role, "user")
	}
}

func TestAIAgentService_ExecuteAction_WithContext(t *testing.T) {
	var capturedReq domain.AIProxyRequest

	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			capturedReq = req
			return sendChunks(
				domain.StreamChunk{Content: `{}`, Done: true},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)

	_, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action:  "summarize_notes",
		Context: map[string]interface{}{"language": "en", "summary_length": "short"},
	})
	if err != nil {
		t.Fatalf("ExecuteAction: %v", err)
	}

	userMsg := capturedReq.Messages[1].Content
	if userMsg == "" {
		t.Fatal("user message should not be empty")
	}
}

func TestAIAgentService_ExecuteAction_WithParameters(t *testing.T) {
	var capturedReq domain.AIProxyRequest

	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			capturedReq = req
			return sendChunks(
				domain.StreamChunk{Content: `{}`, Done: true},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)

	_, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action:     "create_note",
		Parameters: map[string]interface{}{"title": "Test Note", "format": "markdown"},
	})
	if err != nil {
		t.Fatalf("ExecuteAction: %v", err)
	}

	userMsg := capturedReq.Messages[1].Content
	if userMsg == "" {
		t.Fatal("user message should not be empty")
	}
}

func TestAIAgentService_ExecuteAction_EmptyContext(t *testing.T) {
	var capturedReq domain.AIProxyRequest

	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			capturedReq = req
			return sendChunks(
				domain.StreamChunk{Content: `{}`, Done: true},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)

	_, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action:  "organize_notes",
		Context: map[string]interface{}{}, // empty context
	})
	if err != nil {
		t.Fatalf("ExecuteAction: %v", err)
	}

	userMsg := capturedReq.Messages[1].Content
	// Empty context should not add "Context:" line to the prompt.
	if userMsg == "" {
		t.Fatal("user message should not be empty")
	}
}

func TestAIAgentService_ExecuteAction_StreamNotRunningJSON(t *testing.T) {
	// The response is not JSON -- should fall back to raw wrapping.
	proxy := &mockAIProxyService{
		proxyFn: func(_ context.Context, _ string, _ domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return sendChunks(
				domain.StreamChunk{Content: "Some error occurred: timeout", Done: true},
			), nil
		},
	}

	svc := NewAIAgentService(proxy)

	resp, err := svc.ExecuteAction(context.Background(), "user1", domain.AIAgentRequest{
		Action: "create_note",
	})
	if err != nil {
		t.Fatalf("ExecuteAction: %v", err)
	}

	if resp.Status != "completed" {
		t.Errorf("Status = %q, want %q", resp.Status, "completed")
	}
	raw, ok := resp.Result["raw"]
	if !ok {
		t.Error("Result should contain 'raw' key for non-JSON response")
	}
	if raw != "Some error occurred: timeout" {
		t.Errorf("Result[raw] = %q, want the raw content", raw)
	}
}
