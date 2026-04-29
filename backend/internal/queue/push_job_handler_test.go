package queue

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/hibiken/asynq"

	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock PushService for push job handler tests
// ---------------------------------------------------------------------------

type mockPushSvc struct {
	sendPushFn func(ctx context.Context, userID string, payload service.PushPayload) error
	calls      []service.PushPayload
}

func (m *mockPushSvc) SendPush(ctx context.Context, userID string, payload service.PushPayload) error {
	m.calls = append(m.calls, payload)
	if m.sendPushFn != nil {
		return m.sendPushFn(ctx, userID, payload)
	}
	return nil
}

func (m *mockPushSvc) RegisterDevice(ctx context.Context, userID string, token string, platform string) error {
	return nil
}

func (m *mockPushSvc) UnregisterDevice(ctx context.Context, userID string, token string) error {
	return nil
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestPushJobHandler_ProcessTask_Success(t *testing.T) {
	pushSvc := &mockPushSvc{}

	h := NewPushJobHandler(pushSvc)

	payload := PushPayload{
		UserID: "user-123",
		Title:  "Test Title",
		Body:   "Test Body",
		Data:   map[string]string{"type": "test"},
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePush, data)

	err := h.ProcessTask(context.Background(), task)
	if err != nil {
		t.Fatalf("ProcessTask: %v", err)
	}

	if len(pushSvc.calls) != 1 {
		t.Fatalf("expected 1 SendPush call, got %d", len(pushSvc.calls))
	}

	call := pushSvc.calls[0]
	if call.Title != "Test Title" {
		t.Errorf("Title = %q, want %q", call.Title, "Test Title")
	}
	if call.Body != "Test Body" {
		t.Errorf("Body = %q, want %q", call.Body, "Test Body")
	}
	if call.Data["type"] != "test" {
		t.Errorf("Data[type] = %v, want %q", call.Data["type"], "test")
	}
}

func TestPushJobHandler_ProcessTask_MissingUserID(t *testing.T) {
	pushSvc := &mockPushSvc{}

	h := NewPushJobHandler(pushSvc)

	payload := PushPayload{
		Title: "Test Title",
		Body:  "Test Body",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePush, data)

	err := h.ProcessTask(context.Background(), task)
	if err != nil {
		t.Errorf("missing user_id should return nil (non-retriable), got: %v", err)
	}

	if len(pushSvc.calls) != 0 {
		t.Errorf("expected 0 SendPush calls, got %d", len(pushSvc.calls))
	}
}

func TestPushJobHandler_ProcessTask_PushServiceError(t *testing.T) {
	pushSvc := &mockPushSvc{
		sendPushFn: func(ctx context.Context, userID string, payload service.PushPayload) error {
			return errors.New("FCM unavailable")
		},
	}

	h := NewPushJobHandler(pushSvc)

	payload := PushPayload{
		UserID: "user-123",
		Title:  "Test Title",
		Body:   "Test Body",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePush, data)

	err := h.ProcessTask(context.Background(), task)
	if err == nil {
		t.Error("expected retriable error when push service fails")
	}
}

func TestPushJobHandler_ProcessTask_InvalidJSON(t *testing.T) {
	pushSvc := &mockPushSvc{}

	h := NewPushJobHandler(pushSvc)

	task := asynq.NewTask(TaskTypePush, []byte("not valid json"))

	err := h.ProcessTask(context.Background(), task)
	if err == nil {
		t.Error("expected error for invalid JSON payload")
	}
}

func TestPushJobHandler_ProcessTask_EmptyData(t *testing.T) {
	pushSvc := &mockPushSvc{}

	h := NewPushJobHandler(pushSvc)

	payload := PushPayload{
		UserID: "user-456",
		Title:  "No Data",
		Body:   "Simple notification",
	}

	data, _ := json.Marshal(payload)
	task := asynq.NewTask(TaskTypePush, data)

	err := h.ProcessTask(context.Background(), task)
	if err != nil {
		t.Fatalf("ProcessTask: %v", err)
	}

	if len(pushSvc.calls) != 1 {
		t.Fatalf("expected 1 SendPush call, got %d", len(pushSvc.calls))
	}

	call := pushSvc.calls[0]
	if len(call.Data) != 0 {
		t.Errorf("Data should be empty, got %v", call.Data)
	}
}

// ---------------------------------------------------------------------------
// Tests: PushPayload serialization
// ---------------------------------------------------------------------------

func TestPushPayload_Serialization(t *testing.T) {
	payload := PushPayload{
		UserID: "user-abc",
		Title:  "Hello",
		Body:   "World",
		Data:   map[string]string{"key1": "value1", "key2": "value2"},
	}

	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded PushPayload
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.UserID != payload.UserID {
		t.Errorf("UserID = %q, want %q", decoded.UserID, payload.UserID)
	}
	if decoded.Title != payload.Title {
		t.Errorf("Title = %q, want %q", decoded.Title, payload.Title)
	}
	if decoded.Body != payload.Body {
		t.Errorf("Body = %q, want %q", decoded.Body, payload.Body)
	}
	if decoded.Data["key1"] != "value1" {
		t.Errorf("Data[key1] = %q, want %q", decoded.Data["key1"], "value1")
	}
	if decoded.Data["key2"] != "value2" {
		t.Errorf("Data[key2] = %q, want %q", decoded.Data["key2"], "value2")
	}
}

func TestPushPayload_EmptyData(t *testing.T) {
	payload := PushPayload{
		UserID: "user-abc",
		Title:  "Hello",
		Body:   "World",
	}

	data, _ := json.Marshal(payload)
	var decoded PushPayload
	json.Unmarshal(data, &decoded)

	if decoded.Data != nil {
		t.Errorf("Data should be nil when not provided, got %v", decoded.Data)
	}
}
