package queue

import (
	"context"
	"encoding/json"

	"github.com/hibiken/asynq"
)

const (
	TaskTypeAIProxy           = "ai:proxy"
	TaskTypePublish           = "publish:execute"
	TaskCleanupExpiredShares  = "cleanup:expired_shares"
)

// Service manages the asynq task queue.
type Service struct {
	client *asynq.Client
	mux    *asynq.ServeMux
	server *asynq.Server
}

// New creates a new queue service.
func New(redisURL string) *Service {
	client := asynq.NewClient(asynq.RedisClientOpt{Addr: redisURL})
	mux := asynq.NewServeMux()

	return &Service{
		client: client,
		mux:    mux,
	}
}

// EnqueueAIJob enqueues an AI proxy job for shared LLM processing.
func (s *Service) EnqueueAIJob(ctx context.Context, userID string, payload interface{}, priority int) (string, error) {
	data, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	task := asynq.NewTask(TaskTypeAIProxy, data)
	info, err := s.client.EnqueueContext(ctx, task,
		asynq.Queue("ai"),
		asynq.MaxRetry(2),
		asynq.Timeout(120*1e9), // 120s
	)
	if err != nil {
		return "", err
	}

	return info.ID, nil
}

// EnqueuePublishJob enqueues a publish job. The payload is expected to contain
// all fields required by PublishJobPayload (user_id, platform, publish_log_id, etc.).
func (s *Service) EnqueuePublishJob(ctx context.Context, userID string, platform string, payload interface{}) (string, error) {
	data, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	task := asynq.NewTask(TaskTypePublish, data)
	info, err := s.client.EnqueueContext(ctx, task,
		asynq.Queue("publish"),
		asynq.MaxRetry(3),
	)
	if err != nil {
		return "", err
	}

	return info.ID, nil
}

// HandleFunc registers a handler for a task type.
func (s *Service) HandleFunc(taskType string, handler func(ctx context.Context, t *asynq.Task) error) {
	s.mux.HandleFunc(taskType, handler)
}

// RegisterHandlers registers all task handlers using the provided handler instances.
// This is the preferred way to wire up handlers with full dependency injection.
func (s *Service) RegisterHandlers(aiHandler *AIJobHandler, publishHandler *PublishJobHandler) {
	s.mux.HandleFunc(TaskTypeAIProxy, aiHandler.HandleTask)
	s.mux.HandleFunc(TaskTypePublish, publishHandler.HandleTask)
}

// Run starts the worker process.
func (s *Service) Run(redisURL string) error {
	srv := asynq.NewServer(
		asynq.RedisClientOpt{Addr: redisURL},
		asynq.Config{
			Concurrency: 10,
			Queues: map[string]int{
				"ai":      2,
				"publish": 1,
			},
		},
	)

	return srv.Run(s.mux)
}

// Start starts the asynq worker server in the background. Call Stop to shut it
// down gracefully. The caller should handle the error returned by Start (e.g.
// if the Redis connection fails).
func (s *Service) Start(redisURL string) error {
	s.server = asynq.NewServer(
		asynq.RedisClientOpt{Addr: redisURL},
		asynq.Config{
			Concurrency: 10,
			Queues: map[string]int{
				"ai":      2,
				"publish": 1,
			},
		},
	)

	if err := s.server.Start(s.mux); err != nil {
		return err
	}

	return nil
}

// Stop gracefully shuts down the asynq worker server. In-progress tasks are
// given time to complete before the server stops.
func (s *Service) Stop() {
	if s.server != nil {
		s.server.Stop()
		s.server = nil
	}
}

// Shutdown closes the queue client. Call Stop first to shut down the worker server.
func (s *Service) Shutdown() {
	s.client.Close()
}
