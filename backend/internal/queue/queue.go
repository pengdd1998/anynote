package queue

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/hibiken/asynq"
)

const (
	TaskTypeAIProxy  = "ai:proxy"
	TaskTypePublish  = "publish:execute"
)

// Service manages the asynq task queue.
type Service struct {
	client *asynq.Client
	mux    *asynq.ServeMux
}

// New creates a new queue service.
func New(redisURL string) (*Service, error) {
	client, err := asynq.NewClient(asynq.RedisClientOpt{Addr: redisURL})
	if err != nil {
		return nil, fmt.Errorf("create asynq client: %w", err)
	}

	mux := asynq.NewServeMux()

	return &Service{
		client: client,
		mux:    mux,
	}, nil
}

// EnqueueAIJob enqueues an AI proxy job for shared LLM processing.
func (s *Service) EnqueueAIJob(ctx context.Context, userID string, payload interface{}, priority int) (string, error) {
	data, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	task := asynq.NewTask(TaskTypeAIProxy, data)
	info, err := s.client.EnqueueContext(ctx, task,
		asynq.QueueName("ai"),
		asynq.Priority(priority),
		asynq.MaxRetry(2),
		asynq.Timeout(120*1e9), // 120s
	)
	if err != nil {
		return "", err
	}

	return info.ID, nil
}

// EnqueuePublishJob enqueues a publish job.
func (s *Service) EnqueuePublishJob(ctx context.Context, userID string, platform string, payload interface{}) (string, error) {
	data, err := json.Marshal(map[string]interface{}{
		"user_id":  userID,
		"platform": platform,
		"payload":  payload,
	})
	if err != nil {
		return "", err
	}

	task := asynq.NewTask(TaskTypePublish, data)
	info, err := s.client.EnqueueContext(ctx, task,
		asynq.QueueName("publish"),
		asynq.Priority(PriorityNormal),
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

// Shutdown closes the queue client.
func (s *Service) Shutdown() {
	s.client.Close()
}
