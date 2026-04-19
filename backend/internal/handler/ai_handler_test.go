package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// flushableRecorder wraps httptest.ResponseRecorder and adds http.Flusher support.
type flushableRecorder struct {
	*httptest.ResponseRecorder
}

func (f *flushableRecorder) Flush() {
	// No-op: the buffered body is already written.
}

// ---------------------------------------------------------------------------
// Mock AIProxyService
// ---------------------------------------------------------------------------

type mockAIProxyService struct {
	proxyFn func(ctx context.Context, userID string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error)
}

func (m *mockAIProxyService) Proxy(ctx context.Context, userID string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
	if m.proxyFn != nil {
		return m.proxyFn(ctx, userID, req)
	}
	return nil, errors.New("not implemented")
}

// mockQuotaSvcForHandler is a handler-level mock for QuotaService.
type mockQuotaSvcForHandler struct {
	getQuotaFn func(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error)
}

func (m *mockQuotaSvcForHandler) GetQuota(ctx context.Context, userID uuid.UUID) (*domain.QuotaResponse, error) {
	if m.getQuotaFn != nil {
		return m.getQuotaFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockQuotaSvcForHandler) IncrementUsage(ctx context.Context, userID uuid.UUID) error {
	return nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// setupAIRouter creates a chi router wired with AIHandler behind AuthMiddleware.
func setupAIRouter(aiSvc *mockAIProxyService, quotaSvc *mockQuotaSvcForHandler) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestLogger)

	// Cast the mock to satisfy the QuotaService interface.
	// Since AIHandler.quotaSvc is service.QuotaService, we need the mock
	// to satisfy that interface. Our mockQuotaSvcForHandler does.
	h := &AIHandler{
		aiService: aiSvc,
		quotaSvc:  quotaSvc,
	}

	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		r.Post("/api/v1/ai/proxy", h.Proxy)
		r.Get("/api/v1/ai/quota", h.GetQuota)
	})

	return r
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/ai/proxy (non-streaming)
// ---------------------------------------------------------------------------

func TestAIHandler_Proxy_NonStream_Success(t *testing.T) {
	userID := uuid.New()

	svc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			if uid != userID.String() {
				t.Errorf("userID = %q, want %q", uid, userID.String())
			}
			ch := make(chan domain.StreamChunk, 2)
			ch <- domain.StreamChunk{Content: "Hello "}
			ch <- domain.StreamChunk{Content: "world", Done: true}
			close(ch)
			return ch, nil
		},
	}

	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hi"},
		},
		Stream: false,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp map[string]interface{}
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	content, _ := resp["content"].(string)
	if content != "Hello world" {
		t.Errorf("content = %q, want %q", content, "Hello world")
	}
	done, _ := resp["done"].(bool)
	if !done {
		t.Error("done should be true")
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/ai/proxy (streaming SSE)
// ---------------------------------------------------------------------------

func TestAIHandler_Proxy_Stream_Success(t *testing.T) {
	userID := uuid.New()

	svc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			ch := make(chan domain.StreamChunk, 3)
			ch <- domain.StreamChunk{Content: "chunk1"}
			ch <- domain.StreamChunk{Content: "chunk2"}
			ch <- domain.StreamChunk{Done: true}
			close(ch)
			return ch, nil
		},
	}

	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hi"},
		},
		Stream: true,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := &flushableRecorder{httptest.NewRecorder()}

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	ct := rec.Header().Get("Content-Type")
	if ct != "text/event-stream" {
		t.Errorf("Content-Type = %q, want %q", ct, "text/event-stream")
	}

	respBody := rec.Body.String()

	// Verify we got SSE data lines.
	if !strings.Contains(respBody, "data:") {
		t.Error("response should contain SSE data lines")
	}

	// Count data events -- should have at least 2 (chunk1, chunk2, done).
	dataCount := strings.Count(respBody, "data:")
	if dataCount < 2 {
		t.Errorf("expected at least 2 data events, got %d", dataCount)
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/ai/proxy (quota exceeded)
// ---------------------------------------------------------------------------

func TestAIHandler_Proxy_QuotaExceeded(t *testing.T) {
	userID := uuid.New()

	svc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return nil, service.ErrQuotaExceeded
		},
	}

	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "Hi"},
		},
		Stream: false,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusTooManyRequests, rec.Body.String())
	}

	var resp domain.QuotaExceededResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.Error != "quota_exceeded" {
		t.Errorf("error = %q, want %q", resp.Error, "quota_exceeded")
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/ai/proxy (validation)
// ---------------------------------------------------------------------------

func TestAIHandler_Proxy_NoMessages(t *testing.T) {
	userID := uuid.New()
	svc := &mockAIProxyService{}
	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{},
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error, "validation_error")
	}
}

func TestAIHandler_Proxy_InvalidBody(t *testing.T) {
	userID := uuid.New()
	svc := &mockAIProxyService{}
	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestAIHandler_Proxy_Unauthorized(t *testing.T) {
	svc := &mockAIProxyService{}
	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/ai/proxy (stream error propagation)
// ---------------------------------------------------------------------------

func TestAIHandler_Proxy_StreamError(t *testing.T) {
	userID := uuid.New()

	svc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			ch := make(chan domain.StreamChunk, 1)
			ch <- domain.StreamChunk{Error: "upstream provider error"}
			close(ch)
			return ch, nil
		},
	}

	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
		Stream:   true,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := &flushableRecorder{httptest.NewRecorder()}

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	respBody := rec.Body.String()
	if !strings.Contains(respBody, "event: error") {
		t.Error("SSE response should contain error event")
	}
	if !strings.Contains(respBody, "upstream provider error") {
		t.Error("SSE response should contain the error message")
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/ai/proxy (service error, non-quota)
// ---------------------------------------------------------------------------

func TestAIHandler_Proxy_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			return nil, errors.New("internal AI failure")
		},
	}

	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/ai/quota
// ---------------------------------------------------------------------------

func TestAIHandler_GetQuota_Success(t *testing.T) {
	userID := uuid.New()

	quotaSvc := &mockQuotaSvcForHandler{
		getQuotaFn: func(ctx context.Context, uid uuid.UUID) (*domain.QuotaResponse, error) {
			return &domain.QuotaResponse{
				Plan:       "free",
				DailyLimit: 50,
				DailyUsed:  10,
				ResetAt:    time.Now().Add(24 * time.Hour),
			}, nil
		},
	}

	router := setupAIRouter(&mockAIProxyService{}, quotaSvc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/ai/quota", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.QuotaResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.Plan != "free" {
		t.Errorf("Plan = %q, want %q", resp.Plan, "free")
	}
	if resp.DailyLimit != 50 {
		t.Errorf("DailyLimit = %d, want 50", resp.DailyLimit)
	}
	if resp.DailyUsed != 10 {
		t.Errorf("DailyUsed = %d, want 10", resp.DailyUsed)
	}
}

func TestAIHandler_GetQuota_Unauthorized(t *testing.T) {
	router := setupAIRouter(&mockAIProxyService{}, &mockQuotaSvcForHandler{})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/ai/quota", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestAIHandler_GetQuota_ServiceError(t *testing.T) {
	userID := uuid.New()

	quotaSvc := &mockQuotaSvcForHandler{
		getQuotaFn: func(ctx context.Context, uid uuid.UUID) (*domain.QuotaResponse, error) {
			return nil, errors.New("database error")
		},
	}

	router := setupAIRouter(&mockAIProxyService{}, quotaSvc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/ai/quota", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: stream ending without Done marker
// ---------------------------------------------------------------------------

func TestAIHandler_Proxy_StreamEndsWithoutDone(t *testing.T) {
	userID := uuid.New()

	svc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			// Channel closes without ever sending a chunk with Done=true.
			ch := make(chan domain.StreamChunk, 1)
			ch <- domain.StreamChunk{Content: "partial"}
			close(ch)
			return ch, nil
		},
	}

	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
		Stream:   true,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := &flushableRecorder{httptest.NewRecorder()}

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	respBody := rec.Body.String()

	// Should contain the partial chunk data and the final done=true marker.
	if !strings.Contains(respBody, "partial") {
		t.Error("response should contain partial content")
	}
	if !strings.Contains(respBody, `"done":true`) {
		t.Error("response should contain final done:true marker when stream ends without Done")
	}
}

// ---------------------------------------------------------------------------
// Tests: non-stream error chunk
// ---------------------------------------------------------------------------

func TestAIHandler_Proxy_NonStream_ErrorChunk(t *testing.T) {
	userID := uuid.New()

	svc := &mockAIProxyService{
		proxyFn: func(ctx context.Context, uid string, req domain.AIProxyRequest) (<-chan domain.StreamChunk, error) {
			ch := make(chan domain.StreamChunk, 1)
			ch <- domain.StreamChunk{Error: "model overloaded"}
			close(ch)
			return ch, nil
		},
	}

	router := setupAIRouter(svc, &mockQuotaSvcForHandler{})

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: []domain.ChatMessage{{Role: "user", Content: "Hi"}},
		Stream:   false,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if errResp.Error != "ai_error" {
		t.Errorf("error type = %q, want %q", errResp.Error, "ai_error")
	}
	if errResp.Message != "model overloaded" {
		t.Errorf("error message = %q, want %q", errResp.Message, "model overloaded")
	}
}
