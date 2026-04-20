package service

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

// ---------------------------------------------------------------------------
// Compile-time interface compliance checks
// ---------------------------------------------------------------------------

// Verify that mockFCMClient satisfies the FCMClient interface.
var _ FCMClient = (*mockFCMClient)(nil)

// Verify that pushService satisfies the PushService interface.
var _ PushService = (*pushService)(nil)

// ---------------------------------------------------------------------------
// FCMMessage construction tests
// ---------------------------------------------------------------------------

func TestFCMMessage_Fields(t *testing.T) {
	msg := &FCMMessage{
		Token:    "device-token-abc123",
		Title:    "Test Title",
		Body:     "Test Body",
		Data:     map[string]string{"key": "value"},
		Priority: "high",
	}

	if msg.Token != "device-token-abc123" {
		t.Errorf("Token = %q, want %q", msg.Token, "device-token-abc123")
	}
	if msg.Title != "Test Title" {
		t.Errorf("Title = %q, want %q", msg.Title, "Test Title")
	}
	if msg.Body != "Test Body" {
		t.Errorf("Body = %q, want %q", msg.Body, "Test Body")
	}
	if msg.Data["key"] != "value" {
		t.Errorf("Data[key] = %q, want %q", msg.Data["key"], "value")
	}
	if msg.Priority != "high" {
		t.Errorf("Priority = %q, want %q", msg.Priority, "high")
	}
}

func TestFCMMessage_EmptyData(t *testing.T) {
	msg := &FCMMessage{
		Token: "tok",
		Title: "title",
		Body:  "body",
	}
	if msg.Data != nil {
		t.Errorf("Data should be nil when not set, got %v", msg.Data)
	}
}

func TestFCMMessage_NilData(t *testing.T) {
	msg := &FCMMessage{
		Token:    "tok",
		Title:    "title",
		Body:     "body",
		Data:     nil,
		Priority: "normal",
	}
	if msg.Data != nil {
		t.Error("Data should be nil")
	}
	if msg.Priority != "normal" {
		t.Errorf("Priority = %q, want %q", msg.Priority, "normal")
	}
}

// ---------------------------------------------------------------------------
// DeviceTokenEntry tests
// ---------------------------------------------------------------------------

func TestDeviceTokenEntry_Fields(t *testing.T) {
	id := uuid.New()
	entry := DeviceTokenEntry{
		ID:        id,
		UserID:    "user-1",
		Token:     "token-abc",
		Platform:  "ios",
		CreatedAt: "2026-01-01T00:00:00Z",
	}

	if entry.ID != id {
		t.Errorf("ID = %v, want %v", entry.ID, id)
	}
	if entry.UserID != "user-1" {
		t.Errorf("UserID = %q, want %q", entry.UserID, "user-1")
	}
	if entry.Token != "token-abc" {
		t.Errorf("Token = %q, want %q", entry.Token, "token-abc")
	}
	if entry.Platform != "ios" {
		t.Errorf("Platform = %q, want %q", entry.Platform, "ios")
	}
	if entry.CreatedAt != "2026-01-01T00:00:00Z" {
		t.Errorf("CreatedAt = %q, want %q", entry.CreatedAt, "2026-01-01T00:00:00Z")
	}
}

// ---------------------------------------------------------------------------
// PushPayload tests
// ---------------------------------------------------------------------------

func TestPushPayload_Fields(t *testing.T) {
	payload := PushPayload{
		Title:    "Title",
		Body:     "Body",
		Priority: "high",
		Data: map[string]interface{}{
			"note_id": "abc",
			"count":   42,
		},
	}

	if payload.Title != "Title" {
		t.Errorf("Title = %q, want %q", payload.Title, "Title")
	}
	if payload.Body != "Body" {
		t.Errorf("Body = %q, want %q", payload.Body, "Body")
	}
	if payload.Priority != "high" {
		t.Errorf("Priority = %q, want %q", payload.Priority, "high")
	}
	if payload.Data["note_id"] != "abc" {
		t.Errorf("Data[note_id] = %v, want %q", payload.Data["note_id"], "abc")
	}
	if payload.Data["count"] != 42 {
		t.Errorf("Data[count] = %v, want %d", payload.Data["count"], 42)
	}
}

func TestPushPayload_EmptyData(t *testing.T) {
	payload := PushPayload{
		Title: "Title",
		Body:  "Body",
	}
	if payload.Data != nil {
		t.Errorf("Data should be nil when not set, got %v", payload.Data)
	}
}

// ---------------------------------------------------------------------------
// mockFCMClient behavior tests
// ---------------------------------------------------------------------------

func TestMockFCMClient_Send_Success(t *testing.T) {
	fcm := newMockFCMClient()
	msg := &FCMMessage{
		Token: "test-token",
		Title: "Hello",
		Body:  "World",
	}

	resp, err := fcm.Send(context.Background(), msg)
	if err != nil {
		t.Fatalf("Send returned unexpected error: %v", err)
	}

	// The mock returns a deterministic message ID based on the token.
	expectedID := "projects/test/messages/test-token"
	if resp != expectedID {
		t.Errorf("Send response = %q, want %q", resp, expectedID)
	}

	if len(fcm.calls) != 1 {
		t.Fatalf("expected 1 call, got %d", len(fcm.calls))
	}
	if fcm.calls[0].Token != "test-token" {
		t.Errorf("recorded token = %q, want %q", fcm.calls[0].Token, "test-token")
	}
	if fcm.calls[0].Title != "Hello" {
		t.Errorf("recorded title = %q, want %q", fcm.calls[0].Title, "Hello")
	}
}

func TestMockFCMClient_Send_Error(t *testing.T) {
	fcm := newMockFCMClient()
	fcm.sendErr["bad-token"] = errors.New("UNREGISTERED")

	msg := &FCMMessage{
		Token: "bad-token",
		Title: "Test",
		Body:  "Test",
	}

	resp, err := fcm.Send(context.Background(), msg)
	if err == nil {
		t.Fatal("expected error for bad-token, got nil")
	}
	if resp != "" {
		t.Errorf("expected empty response on error, got %q", resp)
	}
	if len(fcm.calls) != 1 {
		t.Fatalf("expected 1 call recorded even on error, got %d", len(fcm.calls))
	}
}

func TestMockFCMClient_Send_MultipleTokens(t *testing.T) {
	fcm := newMockFCMClient()
	fcm.sendErr["fail-token"] = errors.New("internal error")

	tokens := []string{"token-1", "fail-token", "token-3"}
	for _, tok := range tokens {
		msg := &FCMMessage{Token: tok, Title: "Test", Body: "Body"}
		fcm.Send(context.Background(), msg)
	}

	if len(fcm.calls) != 3 {
		t.Fatalf("expected 3 calls, got %d", len(fcm.calls))
	}

	// Verify all tokens were recorded.
	seen := map[string]bool{}
	for _, call := range fcm.calls {
		seen[call.Token] = true
	}
	for _, tok := range tokens {
		if !seen[tok] {
			t.Errorf("token %q not seen in recorded calls", tok)
		}
	}
}

// ---------------------------------------------------------------------------
// FCM adapter integration with PushService (batch scenarios)
// ---------------------------------------------------------------------------

func TestFCMAdapter_BatchSend_MultipleDevices(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "batch-user"
	for i := 0; i < 5; i++ {
		tok := fmt.Sprintf("batch-token-%d", i)
		repo.tokens[tok] = DeviceTokenEntry{
			ID:       uuid.New(),
			UserID:   userID,
			Token:    tok,
			Platform: "android",
		}
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Batch Test",
		Body:  "Sent to 5 devices",
	})
	if err != nil {
		t.Fatalf("SendPush batch: %v", err)
	}

	if len(fcm.calls) != 5 {
		t.Errorf("expected 5 FCM calls, got %d", len(fcm.calls))
	}

	// Every call should have the same title/body.
	for _, call := range fcm.calls {
		if call.Title != "Batch Test" {
			t.Errorf("Title = %q, want %q", call.Title, "Batch Test")
		}
		if call.Body != "Sent to 5 devices" {
			t.Errorf("Body = %q, want %q", call.Body, "Sent to 5 devices")
		}
	}
}

func TestFCMAdapter_BatchSend_PartialFailure(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()

	// Make one token fail and one succeed.
	fcm.sendErr["fail-1"] = errors.New("internal error")

	svc := NewPushService(repo, fcm)

	userID := "partial-user"
	repo.tokens["ok-1"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "ok-1",
		Platform: "ios",
	}
	repo.tokens["fail-1"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "fail-1",
		Platform: "android",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Partial",
		Body:  "Test",
	})
	if err != nil {
		t.Fatalf("SendPush should not fail for partial device failures: %v", err)
	}

	// Both devices should have been attempted.
	if len(fcm.calls) != 2 {
		t.Errorf("expected 2 FCM calls, got %d", len(fcm.calls))
	}

	// The failed token should NOT be removed (not an UNREGISTERED error).
	if _, exists := repo.tokens["fail-1"]; !exists {
		t.Error("fail-1 token should not have been removed for non-UNREGISTERED error")
	}
}

func TestFCMAdapter_BatchSend_AllStaleTokens(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()

	// Both tokens return UNREGISTERED.
	fcm.sendErr["stale-1"] = fmt.Errorf("UNREGISTERED")
	fcm.sendErr["stale-2"] = fmt.Errorf("invalid-registration-token")

	svc := NewPushService(repo, fcm)

	userID := "all-stale-user"
	repo.tokens["stale-1"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "stale-1",
		Platform: "android",
	}
	repo.tokens["stale-2"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "stale-2",
		Platform: "ios",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Stale",
		Body:  "Test",
	})
	if err != nil {
		t.Fatalf("SendPush: %v", err)
	}

	// Both stale tokens should be cleaned up.
	if _, exists := repo.tokens["stale-1"]; exists {
		t.Error("stale-1 should have been deleted")
	}
	if _, exists := repo.tokens["stale-2"]; exists {
		t.Error("stale-2 should have been deleted")
	}

	if len(fcm.calls) != 2 {
		t.Errorf("expected 2 FCM calls, got %d", len(fcm.calls))
	}
}

// ---------------------------------------------------------------------------
// Context cancellation and timeout tests
// ---------------------------------------------------------------------------

func TestFCMAdapter_CancelledContext(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "ctx-user"
	repo.tokens["ctx-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "ctx-token",
		Platform: "android",
	}

	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately.

	// The mock does not check context, but the call should still go through
	// since the mock ignores context. This verifies the adapter does not
	// panic on cancelled contexts.
	err := svc.SendPush(ctx, userID, PushPayload{
		Title: "Cancelled",
		Body:  "Context",
	})
	// The mock ignores context, so no error is expected.
	if err != nil {
		t.Fatalf("SendPush with cancelled context: %v", err)
	}
}

func TestFCMAdapter_DeadlineExceeded(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "timeout-user"
	repo.tokens["timeout-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "timeout-token",
		Platform: "ios",
	}

	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Nanosecond)
	defer cancel()

	// Wait for context to expire.
	time.Sleep(1 * time.Millisecond)

	// The mock does not respect context deadlines, but the call should not panic.
	err := svc.SendPush(ctx, userID, PushPayload{
		Title: "Timeout",
		Body:  "Test",
	})
	if err != nil {
		t.Fatalf("SendPush with expired context: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Token validation edge cases
// ---------------------------------------------------------------------------

func TestFCMAdapter_EmptyToken(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "empty-token-user"
	repo.tokens[""] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "",
		Platform: "android",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Empty Token",
		Body:  "Test",
	})
	if err != nil {
		t.Fatalf("SendPush with empty token: %v", err)
	}

	// The empty-token message should still have been sent to FCM.
	if len(fcm.calls) != 1 {
		t.Errorf("expected 1 FCM call, got %d", len(fcm.calls))
	}
	if fcm.calls[0].Token != "" {
		t.Errorf("expected empty token in FCM call, got %q", fcm.calls[0].Token)
	}
}

func TestFCMAdapter_VeryLongToken(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	longToken := ""
	for i := 0; i < 4096; i++ {
		longToken += "a"
	}

	userID := "long-token-user"
	repo.tokens[longToken] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    longToken,
		Platform: "ios",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Long Token",
		Body:  "Test",
	})
	if err != nil {
		t.Fatalf("SendPush with long token: %v", err)
	}

	if len(fcm.calls) != 1 {
		t.Fatalf("expected 1 FCM call, got %d", len(fcm.calls))
	}
	if fcm.calls[0].Token != longToken {
		t.Error("FCM call token does not match the long token")
	}
}

// ---------------------------------------------------------------------------
// Data payload edge cases
// ---------------------------------------------------------------------------

func TestFCMAdapter_NilDataPayload(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "nil-data-user"
	repo.tokens["nil-data-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "nil-data-token",
		Platform: "android",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Nil Data",
		Body:  "Test",
		Data:  nil,
	})
	if err != nil {
		t.Fatalf("SendPush: %v", err)
	}

	if len(fcm.calls) != 1 {
		t.Fatalf("expected 1 FCM call, got %d", len(fcm.calls))
	}
	if fcm.calls[0].Data != nil {
		t.Errorf("Data should be nil when payload Data is nil, got %v", fcm.calls[0].Data)
	}
}

func TestFCMAdapter_EmptyDataPayload(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "empty-data-user"
	repo.tokens["empty-data-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "empty-data-token",
		Platform: "android",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Empty Data",
		Body:  "Test",
		Data:  map[string]interface{}{},
	})
	if err != nil {
		t.Fatalf("SendPush: %v", err)
	}

	if len(fcm.calls) != 1 {
		t.Fatalf("expected 1 FCM call, got %d", len(fcm.calls))
	}
	// convertDataToStringMap returns nil for empty maps.
	if fcm.calls[0].Data != nil {
		t.Errorf("Data should be nil for empty payload Data, got %v", fcm.calls[0].Data)
	}
}

func TestFCMAdapter_ComplexDataPayload(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	userID := "complex-data-user"
	repo.tokens["complex-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "complex-token",
		Platform: "ios",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Complex Data",
		Body:  "Test",
		Data: map[string]interface{}{
			"string_val": "hello",
			"int_val":    42,
			"float_val":  3.14,
			"bool_val":   true,
			"nil_val":    nil,
		},
	})
	if err != nil {
		t.Fatalf("SendPush: %v", err)
	}

	if len(fcm.calls) != 1 {
		t.Fatalf("expected 1 FCM call, got %d", len(fcm.calls))
	}

	data := fcm.calls[0].Data
	tests := []struct {
		key  string
		want string
	}{
		{"string_val", "hello"},
		{"int_val", "42"},
		{"float_val", "3.14"},
		{"bool_val", "true"},
		{"nil_val", "<nil>"},
	}
	for _, tt := range tests {
		if data[tt.key] != tt.want {
			t.Errorf("Data[%q] = %q, want %q", tt.key, data[tt.key], tt.want)
		}
	}
}

// ---------------------------------------------------------------------------
// Concurrency tests
// ---------------------------------------------------------------------------

func TestFCMAdapter_ConcurrentSend(t *testing.T) {
	// Verify that concurrent SendPush calls do not panic.
	// We use separate repos per goroutine to avoid data races on the
	// shared map in the mock repo, and assert only that each call
	// completes without error.
	var wg sync.WaitGroup
	const goroutines = 10
	errCh := make(chan error, goroutines)

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			repo := newMockDeviceTokenRepo()
			svc := NewPushService(repo, nil) // log-only to avoid mock data races

			userID := fmt.Sprintf("concurrent-user-%d", idx)
			repo.tokens[userID+"-token"] = DeviceTokenEntry{
				ID:       uuid.New(),
				UserID:   userID,
				Token:    userID + "-token",
				Platform: "android",
			}

			if err := svc.SendPush(context.Background(), userID, PushPayload{
				Title: fmt.Sprintf("Concurrent %d", idx),
				Body:  "Test",
			}); err != nil {
				errCh <- err
			}
		}(i)
	}
	wg.Wait()
	close(errCh)

	for err := range errCh {
		t.Errorf("concurrent SendPush error: %v", err)
	}
}

// ---------------------------------------------------------------------------
// NewPushService constructor tests
// ---------------------------------------------------------------------------

func TestNewPushService_NilFCM_LogOnlyMode(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	svc := NewPushService(repo, nil)

	// Should not panic and should work in log-only mode.
	if svc == nil {
		t.Fatal("NewPushService returned nil")
	}

	userID := "log-only-user"
	repo.tokens["log-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "log-token",
		Platform: "android",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "Log Only",
		Body:  "No FCM",
	})
	if err != nil {
		t.Fatalf("SendPush log-only mode: %v", err)
	}
}

func TestNewPushService_WithFCM(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	fcm := newMockFCMClient()
	svc := NewPushService(repo, fcm)

	if svc == nil {
		t.Fatal("NewPushService returned nil")
	}

	userID := "fcm-user"
	repo.tokens["fcm-token"] = DeviceTokenEntry{
		ID:       uuid.New(),
		UserID:   userID,
		Token:    "fcm-token",
		Platform: "ios",
	}

	err := svc.SendPush(context.Background(), userID, PushPayload{
		Title: "FCM Mode",
		Body:  "Active",
	})
	if err != nil {
		t.Fatalf("SendPush FCM mode: %v", err)
	}

	if len(fcm.calls) != 1 {
		t.Errorf("expected 1 FCM call, got %d", len(fcm.calls))
	}
}

// ---------------------------------------------------------------------------
// isUnregisteredError additional edge cases
// ---------------------------------------------------------------------------

func TestIsUnregisteredError_EdgeCases(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{
			name: "wrapped UNREGISTERED",
			err:  fmt.Errorf("push failed: %w", errors.New("UNREGISTERED")),
			want: true,
		},
		{
			name: "invalid-registration-token uppercase",
			err:  fmt.Errorf("INVALID-REGISTRATION-TOKEN"),
			want: false, // case-sensitive substring match
		},
		{
			name: "mixed case NotRegistered",
			err:  fmt.Errorf("notregistered"),
			want: false, // lowercase 'notregistered' does not match 'NotRegistered'
		},
		{
			name: "registration-not-unique",
			err:  fmt.Errorf("registration-not-unique"),
			want: false,
		},
		{
			name: "empty error",
			err:  errors.New(""),
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isUnregisteredError(tt.err)
			if got != tt.want {
				t.Errorf("isUnregisteredError(%v) = %v, want %v", tt.err, got, tt.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// convertDataToStringMap additional edge cases
// ---------------------------------------------------------------------------

func TestConvertDataToStringMap_EdgeCases(t *testing.T) {
	tests := []struct {
		name string
		in   map[string]interface{}
		want map[string]string
	}{
		{
			name: "nil value in map",
			in:   map[string]interface{}{"key": nil},
			want: map[string]string{"key": "<nil>"},
		},
		{
			name: "float value",
			in:   map[string]interface{}{"ratio": 2.718},
			want: map[string]string{"ratio": "2.718"},
		},
		{
			name: "negative integer",
			in:   map[string]interface{}{"delta": -1},
			want: map[string]string{"delta": "-1"},
		},
		{
			name: "single key value",
			in:   map[string]interface{}{"only": "one"},
			want: map[string]string{"only": "one"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := convertDataToStringMap(tt.in)
			for k, v := range tt.want {
				if got[k] != v {
					t.Errorf("got[%q] = %q, want %q", k, got[k], v)
				}
			}
		})
	}
}

// ---------------------------------------------------------------------------
// tokenPrefix additional edge cases
// ---------------------------------------------------------------------------

func TestTokenPrefix_EdgeCases(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"single char", "a", "a"},
		{"seven chars", "1234567", "1234567"},
		{"eight chars exactly", "12345678", "12345678"},
		{"nine chars", "123456789", "12345678..."},
		{"unicode chars", "日本語テストtest", "日本語テストtest"[0:8] + "..."},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tokenPrefix(tt.input)
			if got != tt.want {
				t.Errorf("tokenPrefix(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}
