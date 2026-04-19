package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

// ---------------------------------------------------------------------------
// Mock Pinger
// ---------------------------------------------------------------------------

type mockPinger struct {
	err error
}

func (m *mockPinger) Ping(ctx context.Context) error {
	return m.err
}

// ---------------------------------------------------------------------------
// HealthCheck tests
// ---------------------------------------------------------------------------

func TestHealthCheck_ReturnsOK(t *testing.T) {
	h := NewHealthHandler(&mockPinger{}, nil)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()

	h.HealthCheck(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if body["status"] != "ok" {
		t.Errorf("status = %q, want %q", body["status"], "ok")
	}
	if body["version"] == "" {
		t.Error("version should not be empty")
	}
	if body["timestamp"] == "" {
		t.Error("timestamp should not be empty")
	}
}

// ---------------------------------------------------------------------------
// ReadinessCheck tests
// ---------------------------------------------------------------------------

func TestReadinessCheck_AllHealthy(t *testing.T) {
	h := NewHealthHandler(&mockPinger{}, nil)

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	w := httptest.NewRecorder()

	h.ReadinessCheck(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var body map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if body["status"] != "ok" {
		t.Errorf("status = %v, want %q", body["status"], "ok")
	}

	checks, ok := body["checks"].(map[string]interface{})
	if !ok {
		t.Fatal("checks should be a map")
	}
	if checks["db"] != "ok" {
		t.Errorf("checks[db] = %v, want %q", checks["db"], "ok")
	}
	if checks["redis"] != "not_configured" {
		t.Errorf("checks[redis] = %v, want %q", checks["redis"], "not_configured")
	}
}

func TestReadinessCheck_DBUnhealthy(t *testing.T) {
	h := NewHealthHandler(&mockPinger{err: errors.New("connection refused")}, nil)

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	w := httptest.NewRecorder()

	h.ReadinessCheck(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusServiceUnavailable)
	}

	var body map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if body["status"] != "degraded" {
		t.Errorf("status = %v, want %q", body["status"], "degraded")
	}

	checks, ok := body["checks"].(map[string]interface{})
	if !ok {
		t.Fatal("checks should be a map")
	}
	dbStatus, _ := checks["db"].(string)
	if dbStatus == "ok" {
		t.Error("db check should not be ok when ping fails")
	}
}

func TestReadinessCheck_WithRedisHealthy(t *testing.T) {
	mr := miniredis.RunT(t)
	defer mr.Close()

	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	h := NewHealthHandler(&mockPinger{}, rdb)

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	w := httptest.NewRecorder()

	h.ReadinessCheck(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var body map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	checks, ok := body["checks"].(map[string]interface{})
	if !ok {
		t.Fatal("checks should be a map")
	}
	if checks["db"] != "ok" {
		t.Errorf("checks[db] = %v, want %q", checks["db"], "ok")
	}
	if checks["redis"] != "ok" {
		t.Errorf("checks[redis] = %v, want %q", checks["redis"], "ok")
	}
}

func TestReadinessCheck_WithRedisUnhealthy(t *testing.T) {
	// Create a Redis client pointing to an unreachable address.
	rdb := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1"})
	defer rdb.Close()

	h := NewHealthHandler(&mockPinger{}, rdb)

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	w := httptest.NewRecorder()

	h.ReadinessCheck(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusServiceUnavailable)
	}

	var body map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if body["status"] != "degraded" {
		t.Errorf("status = %v, want %q", body["status"], "degraded")
	}

	checks, ok := body["checks"].(map[string]interface{})
	if !ok {
		t.Fatal("checks should be a map")
	}
	redisStatus, _ := checks["redis"].(string)
	if redisStatus == "ok" {
		t.Error("redis check should not be ok when Redis is unreachable")
	}
}
