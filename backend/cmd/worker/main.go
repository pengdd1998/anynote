package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/anynote/backend/internal/config"
	"github.com/anynote/backend/internal/queue"
)

func main() {
	cfgPath := "config.yaml"
	if p := os.Getenv("CONFIG_PATH"); p != "" {
		cfgPath = p
	}

	cfg, err := config.Load(cfgPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Connect to PostgreSQL
	pool, err := pgxpool.New(context.Background(), cfg.Database.URL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	// Initialize queue service
	qSvc, err := queue.New(cfg.Redis.URL)
	if err != nil {
		log.Fatalf("Failed to create queue: %v", err)
	}
	defer qSvc.Shutdown()

	// Register task handlers
	qSvc.HandleFunc(queue.TaskTypeAIProxy, handleAIProxy)
	qSvc.HandleFunc(queue.TaskTypePublish, handlePublish)

	log.Println("Worker starting...")
	if err := qSvc.Run(cfg.Redis.URL); err != nil {
		log.Fatalf("Worker error: %v", err)
	}
}

func handleAIProxy(ctx context.Context, t *queue.Task) error {
	var payload map[string]interface{}
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		return err
	}

	log.Printf("Processing AI proxy job: %v", payload["user_id"])
	// TODO: Execute AI request via LLM Gateway
	// Store result in Redis for client pickup
	return nil
}

func handlePublish(ctx context.Context, t *queue.Task) error {
	var payload map[string]interface{}
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		return err
	}

	log.Printf("Processing publish job: %v for platform: %v", payload["user_id"], payload["platform"])
	// TODO: Execute publish via platform adapter
	return nil
}
