package queue

import (
	"encoding/json"
	"testing"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Tests: Priority constants
// ---------------------------------------------------------------------------

func TestPriorityConstants(t *testing.T) {
	if PriorityHigh != 10 {
		t.Errorf("PriorityHigh = %d, want 10", PriorityHigh)
	}
	if PriorityNormal != 5 {
		t.Errorf("PriorityNormal = %d, want 5", PriorityNormal)
	}
	if PriorityLow != 1 {
		t.Errorf("PriorityLow = %d, want 1", PriorityLow)
	}

	// Verify ordering.
	if PriorityHigh <= PriorityNormal {
		t.Error("PriorityHigh should be greater than PriorityNormal")
	}
	if PriorityNormal <= PriorityLow {
		t.Error("PriorityNormal should be greater than PriorityLow")
	}
}

// ---------------------------------------------------------------------------
// Tests: Task type constants
// ---------------------------------------------------------------------------

func TestTaskTypeConstants(t *testing.T) {
	if TaskTypeAIProxy != "ai:proxy" {
		t.Errorf("TaskTypeAIProxy = %q, want %q", TaskTypeAIProxy, "ai:proxy")
	}
	if TaskTypePublish != "publish:execute" {
		t.Errorf("TaskTypePublish = %q, want %q", TaskTypePublish, "publish:execute")
	}
}

// ---------------------------------------------------------------------------
// Tests: AIJobPayload JSON marshaling
// ---------------------------------------------------------------------------

func TestAIJobPayload_MarshalUnmarshal(t *testing.T) {
	payload := AIJobPayload{
		UserID: "user-123",
		JobID:  "job-456",
		Stream: true,
		Request: domain.AIProxyRequest{
			Model: "gpt-4",
			Messages: []domain.ChatMessage{
				{Role: "user", Content: "Hello"},
			},
		},
	}

	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded AIJobPayload
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.UserID != "user-123" {
		t.Errorf("UserID = %q, want %q", decoded.UserID, "user-123")
	}
	if decoded.JobID != "job-456" {
		t.Errorf("JobID = %q, want %q", decoded.JobID, "job-456")
	}
	if !decoded.Stream {
		t.Error("Stream should be true")
	}
	if decoded.Request.Model != "gpt-4" {
		t.Errorf("Model = %q, want %q", decoded.Request.Model, "gpt-4")
	}
}

// ---------------------------------------------------------------------------
// Tests: PublishJobPayload JSON marshaling
// ---------------------------------------------------------------------------

func TestPublishJobPayload_MarshalUnmarshal(t *testing.T) {
	payload := PublishJobPayload{
		UserID:       "user-789",
		Platform:     "xiaohongshu",
		PublishLogID: "log-012",
		Title:        "Test Title",
		Content:      "Test Content",
		Tags:         []string{"tag1", "tag2"},
	}

	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded PublishJobPayload
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.UserID != "user-789" {
		t.Errorf("UserID = %q, want %q", decoded.UserID, "user-789")
	}
	if decoded.Platform != "xiaohongshu" {
		t.Errorf("Platform = %q, want %q", decoded.Platform, "xiaohongshu")
	}
	if decoded.PublishLogID != "log-012" {
		t.Errorf("PublishLogID = %q, want %q", decoded.PublishLogID, "log-012")
	}
	if decoded.Title != "Test Title" {
		t.Errorf("Title = %q, want %q", decoded.Title, "Test Title")
	}
	if len(decoded.Tags) != 2 {
		t.Fatalf("Tags len = %d, want 2", len(decoded.Tags))
	}
	if decoded.Tags[0] != "tag1" {
		t.Errorf("Tags[0] = %q, want %q", decoded.Tags[0], "tag1")
	}
}

func TestPublishJobPayload_EmptyFields(t *testing.T) {
	payload := PublishJobPayload{
		UserID:   "user-1",
		Platform: "medium",
	}

	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded PublishJobPayload
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Title != "" {
		t.Errorf("Title = %q, want empty", decoded.Title)
	}
	if decoded.Tags != nil {
		t.Errorf("Tags = %v, want nil", decoded.Tags)
	}
}

// ---------------------------------------------------------------------------
// Tests: PublishJobPayload with EncryptedAuthRef
// ---------------------------------------------------------------------------

func TestPublishJobPayload_WithEncryptedAuthRef(t *testing.T) {
	payload := PublishJobPayload{
		UserID:           "user-1",
		Platform:         "xiaohongshu",
		PublishLogID:     "log-1",
		EncryptedAuthRef: "enc-ref-xyz",
	}

	data, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded PublishJobPayload
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.EncryptedAuthRef != "enc-ref-xyz" {
		t.Errorf("EncryptedAuthRef = %q, want %q", decoded.EncryptedAuthRef, "enc-ref-xyz")
	}
}
