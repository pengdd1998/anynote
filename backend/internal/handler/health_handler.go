package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/redis/go-redis/v9"
)

// Version is set at build time via ldflags (e.g. -X handler.Version=v1.0.0).
var Version = "dev"

// Pinger is implemented by any dependency that supports a health-check ping.
// Both *pgxpool.Pool and *sql.DB satisfy this interface via their Ping methods.
type Pinger interface {
	Ping(ctx context.Context) error
}

// HealthHandler provides health check endpoints.
type HealthHandler struct {
	db          Pinger
	redisClient *redis.Client
}

// NewHealthHandler creates a new health check handler.
// The db parameter accepts any Pinger (pgxpool.Pool, sql.DB, etc.).
// The redisClient may be nil if Redis is not configured.
func NewHealthHandler(db Pinger, rdb *redis.Client) *HealthHandler {
	return &HealthHandler{
		db:          db,
		redisClient: rdb,
	}
}

// HealthCheck handles GET /health.
// Returns basic liveness information: status, timestamp, and version.
// This endpoint does not check downstream dependencies -- it only confirms
// the process is alive and can serve requests.
func (h *HealthHandler) HealthCheck(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status":    "ok",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"version":   Version,
	})
}

// ReadinessCheck handles GET /ready.
// Returns 200 if all dependencies (PostgreSQL, Redis) are reachable,
// 503 otherwise with details about which dependency failed.
func (h *HealthHandler) ReadinessCheck(w http.ResponseWriter, _ *http.Request) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	checks := map[string]string{}
	allHealthy := true

	// Check PostgreSQL connectivity.
	if err := h.db.Ping(ctx); err != nil {
		checks["db"] = fmt.Sprintf("unhealthy: %s", err.Error())
		allHealthy = false
	} else {
		checks["db"] = "ok"
	}

	// Check Redis connectivity.
	if h.redisClient != nil {
		if err := h.redisClient.Ping(ctx).Err(); err != nil {
			checks["redis"] = fmt.Sprintf("unhealthy: %s", err.Error())
			allHealthy = false
		} else {
			checks["redis"] = "ok"
		}
	} else {
		checks["redis"] = "not_configured"
	}

	status := http.StatusOK
	response := map[string]interface{}{
		"status":    "ok",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"version":   Version,
		"checks":    checks,
	}

	if !allHealthy {
		response["status"] = "degraded"
		status = http.StatusServiceUnavailable
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(response)
}
