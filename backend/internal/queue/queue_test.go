package queue

import (
	"context"
	"testing"

	"github.com/alicebob/miniredis/v2"
	"github.com/hibiken/asynq"
)

// ---------------------------------------------------------------------------
// Tests: queue.Service with miniredis
// ---------------------------------------------------------------------------

func TestService_New(t *testing.T) {
	mr := miniredis.RunT(t)
	defer mr.Close()

	svc := New(mr.Addr())
	if svc == nil {
		t.Fatal("New returned nil")
	}
	if svc.client == nil {
		t.Error("client should not be nil")
	}
	if svc.mux == nil {
		t.Error("mux should not be nil")
	}

	// Clean up the client connection.
	svc.Shutdown()
}

func TestService_EnqueueAIJob(t *testing.T) {
	mr := miniredis.RunT(t)
	defer mr.Close()

	svc := New(mr.Addr())
	defer svc.Shutdown()

	jobID, err := svc.EnqueueAIJob(context.Background(), "user-123", map[string]string{
		"prompt": "hello",
	}, 1)
	if err != nil {
		t.Fatalf("EnqueueAIJob: %v", err)
	}
	if jobID == "" {
		t.Error("jobID should not be empty")
	}
}

func TestService_EnqueuePublishJob(t *testing.T) {
	mr := miniredis.RunT(t)
	defer mr.Close()

	svc := New(mr.Addr())
	defer svc.Shutdown()

	jobID, err := svc.EnqueuePublishJob(context.Background(), "user-123", "xiaohongshu", map[string]string{
		"title":   "Test",
		"content": "Content",
	})
	if err != nil {
		t.Fatalf("EnqueuePublishJob: %v", err)
	}
	if jobID == "" {
		t.Error("jobID should not be empty")
	}
}

func TestService_EnqueueAIJob_InvalidRedis(t *testing.T) {
	// Use an unreachable address to test error handling.
	svc := New("127.0.0.1:1")
	defer svc.Shutdown()

	_, err := svc.EnqueueAIJob(context.Background(), "user-123", map[string]string{}, 1)
	if err == nil {
		t.Error("expected error when Redis is unreachable")
	}
}

func TestService_EnqueuePublishJob_InvalidRedis(t *testing.T) {
	svc := New("127.0.0.1:1")
	defer svc.Shutdown()

	_, err := svc.EnqueuePublishJob(context.Background(), "user-123", "mock", map[string]string{})
	if err == nil {
		t.Error("expected error when Redis is unreachable")
	}
}

func TestService_HandleFunc(t *testing.T) {
	mr := miniredis.RunT(t)
	defer mr.Close()

	svc := New(mr.Addr())
	defer svc.Shutdown()

	called := false
	svc.HandleFunc(TaskTypeAIProxy, func(ctx context.Context, t *asynq.Task) error {
		called = true
		return nil
	})

	// HandleFunc just registers on the mux; we verify it doesn't panic.
	// The actual invocation happens via asynq server which is tested separately.
	if called {
		t.Error("HandleFunc should not invoke the handler immediately")
	}
}

func TestService_RegisterHandlers(t *testing.T) {
	mr := miniredis.RunT(t)
	defer mr.Close()

	svc := New(mr.Addr())
	defer svc.Shutdown()

	aiHandler := &AIJobHandler{}
	publishHandler := &PublishJobHandler{}

	// RegisterHandlers should not panic.
	svc.RegisterHandlers(aiHandler, publishHandler)
}

func TestService_Shutdown(t *testing.T) {
	mr := miniredis.RunT(t)
	defer mr.Close()

	svc := New(mr.Addr())

	// Shutdown should not panic.
	svc.Shutdown()

	// Double shutdown should also be safe.
	svc.Shutdown()
}
