package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Mock LLMConfigService
// ---------------------------------------------------------------------------

type mockLLMConfigService struct {
	listFn          func(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error)
	createFn        func(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error)
	updateFn        func(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error)
	deleteFn        func(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error
	testConnFn      func(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error
	getDefaultFn    func(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error)
	listProvidersFn func() []string
}

func (m *mockLLMConfigService) List(ctx context.Context, userID uuid.UUID) ([]domain.LLMConfig, error) {
	if m.listFn != nil {
		return m.listFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockLLMConfigService) Create(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
	if m.createFn != nil {
		return m.createFn(ctx, userID, cfg)
	}
	return nil, errors.New("not implemented")
}

func (m *mockLLMConfigService) Update(ctx context.Context, userID uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
	if m.updateFn != nil {
		return m.updateFn(ctx, userID, cfg)
	}
	return nil, errors.New("not implemented")
}

func (m *mockLLMConfigService) Delete(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error {
	if m.deleteFn != nil {
		return m.deleteFn(ctx, userID, configID)
	}
	return errors.New("not implemented")
}

func (m *mockLLMConfigService) TestConnection(ctx context.Context, userID uuid.UUID, configID uuid.UUID) error {
	if m.testConnFn != nil {
		return m.testConnFn(ctx, userID, configID)
	}
	return errors.New("not implemented")
}

func (m *mockLLMConfigService) GetDefault(ctx context.Context, userID uuid.UUID) (*domain.LLMConfig, error) {
	if m.getDefaultFn != nil {
		return m.getDefaultFn(ctx, userID)
	}
	return nil, errors.New("not implemented")
}

func (m *mockLLMConfigService) ListProviders() []string {
	if m.listProvidersFn != nil {
		return m.listProvidersFn()
	}
	return []string{"openai", "deepseek", "qwen", "anthropic", "custom"}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func setupLLMConfigRouter(svc *mockLLMConfigService) *chi.Mux {
	r := chi.NewRouter()
	r.Use(RequestLogger)

	h := &LLMConfigHandler{llmService: svc}

	r.Group(func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		r.Get("/api/v1/llm/configs", h.List)
		r.Post("/api/v1/llm/configs", h.Create)
		r.Put("/api/v1/llm/configs/{id}", h.Update)
		r.Delete("/api/v1/llm/configs/{id}", h.Delete)
		r.Post("/api/v1/llm/configs/{id}/test", h.TestConnection)
		r.Get("/api/v1/llm/providers", h.ListProviders)
	})

	return r
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/llm/configs
// ---------------------------------------------------------------------------

func TestLLMConfigHandler_List_Success(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{
		listFn: func(ctx context.Context, uid uuid.UUID) ([]domain.LLMConfig, error) {
			return []domain.LLMConfig{
				{
					ID:        cfgID,
					UserID:    userID,
					Name:      "My OpenAI",
					Provider:  "openai",
					BaseURL:   "https://api.openai.com",
					Model:     "gpt-4",
					IsDefault: true,
					CreatedAt: time.Now(),
					UpdatedAt: time.Now(),
				},
			}, nil
		},
	}

	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/llm/configs", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var configs []domain.LLMConfig
	if err := json.NewDecoder(rec.Body).Decode(&configs); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if len(configs) != 1 {
		t.Fatalf("len(configs) = %d, want 1", len(configs))
	}
	if configs[0].Name != "My OpenAI" {
		t.Errorf("Name = %q, want %q", configs[0].Name, "My OpenAI")
	}
}

func TestLLMConfigHandler_List_Empty(t *testing.T) {
	userID := uuid.New()

	svc := &mockLLMConfigService{
		listFn: func(ctx context.Context, uid uuid.UUID) ([]domain.LLMConfig, error) {
			return []domain.LLMConfig{}, nil
		},
	}

	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/llm/configs", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}

func TestLLMConfigHandler_List_Unauthorized(t *testing.T) {
	svc := &mockLLMConfigService{}
	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/llm/configs", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestLLMConfigHandler_List_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockLLMConfigService{
		listFn: func(ctx context.Context, uid uuid.UUID) ([]domain.LLMConfig, error) {
			return nil, errors.New("database error")
		},
	}

	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/llm/configs", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/llm/configs
// ---------------------------------------------------------------------------

func TestLLMConfigHandler_Create_Success(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{
		createFn: func(ctx context.Context, uid uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
			cfg.ID = cfgID
			cfg.UserID = uid
			return &cfg, nil
		},
	}

	router := setupLLMConfigRouter(svc)

	body, _ := json.Marshal(domain.LLMConfig{
		Name:         "My OpenAI",
		Provider:     "openai",
		BaseURL:      "https://api.openai.com",
		DecryptedKey: "", // not serialized (json:"-")
		APIKey:       "sk-test-key",
		Model:        "gpt-4",
		MaxTokens:    4096,
		Temperature:  0.7,
		IsDefault:    true,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/configs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusCreated, rec.Body.String())
	}

	var resp domain.LLMConfig
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.ID != cfgID {
		t.Errorf("ID = %v, want %v", resp.ID, cfgID)
	}
	if resp.Name != "My OpenAI" {
		t.Errorf("Name = %q, want %q", resp.Name, "My OpenAI")
	}
}

func TestLLMConfigHandler_Create_MissingFields(t *testing.T) {
	userID := uuid.New()
	svc := &mockLLMConfigService{}
	router := setupLLMConfigRouter(svc)

	// Send a config with missing required fields.
	body, _ := json.Marshal(domain.LLMConfig{
		Name: "Incomplete Config",
		// Missing: Provider, BaseURL, APIKey, Model
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/configs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(rec.Body).Decode(&errResp)
	if errResp.Error != "validation_error" {
		t.Errorf("error type = %q, want %q", errResp.Error, "validation_error")
	}
}

func TestLLMConfigHandler_Create_InvalidBody(t *testing.T) {
	userID := uuid.New()
	svc := &mockLLMConfigService{}
	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/configs", bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestLLMConfigHandler_Create_ServiceError(t *testing.T) {
	userID := uuid.New()

	svc := &mockLLMConfigService{
		createFn: func(ctx context.Context, uid uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
			return nil, errors.New("encryption failed")
		},
	}

	router := setupLLMConfigRouter(svc)

	body, _ := json.Marshal(domain.LLMConfig{
		Name:         "Test",
		Provider:     "openai",
		BaseURL:      "https://api.openai.com",
		DecryptedKey: "", // not serialized (json:"-")
		APIKey:       "sk-key",
		Model:        "gpt-4",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/configs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: PUT /api/v1/llm/configs/{id}
// ---------------------------------------------------------------------------

func TestLLMConfigHandler_Update_Success(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{
		updateFn: func(ctx context.Context, uid uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
			if cfg.ID != cfgID {
				t.Errorf("config ID = %v, want %v", cfg.ID, cfgID)
			}
			return &cfg, nil
		},
	}

	router := setupLLMConfigRouter(svc)

	body, _ := json.Marshal(domain.LLMConfig{
		Name:     "Updated Config",
		Provider: "openai",
		BaseURL:  "https://api.openai.com",
		Model:    "gpt-4-turbo",
	})

	req := httptest.NewRequest(http.MethodPut, "/api/v1/llm/configs/"+cfgID.String(), bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp domain.LLMConfig
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if resp.Name != "Updated Config" {
		t.Errorf("Name = %q, want %q", resp.Name, "Updated Config")
	}
}

func TestLLMConfigHandler_Update_InvalidBody(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{}
	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodPut, "/api/v1/llm/configs/"+cfgID.String(), bytes.NewReader([]byte("not-json")))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestLLMConfigHandler_Update_ServiceError(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{
		updateFn: func(ctx context.Context, uid uuid.UUID, cfg domain.LLMConfig) (*domain.LLMConfig, error) {
			return nil, errors.New("config not found")
		},
	}

	router := setupLLMConfigRouter(svc)

	body, _ := json.Marshal(domain.LLMConfig{Name: "Test"})

	req := httptest.NewRequest(http.MethodPut, "/api/v1/llm/configs/"+cfgID.String(), bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: DELETE /api/v1/llm/configs/{id}
// ---------------------------------------------------------------------------

func TestLLMConfigHandler_Delete_Success(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{
		deleteFn: func(ctx context.Context, uid uuid.UUID, id uuid.UUID) error {
			if id != cfgID {
				t.Errorf("configID = %v, want %v", id, cfgID)
			}
			return nil
		},
	}

	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/llm/configs/"+cfgID.String(), nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusNoContent)
	}
}

func TestLLMConfigHandler_Delete_ServiceError(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{
		deleteFn: func(ctx context.Context, uid uuid.UUID, id uuid.UUID) error {
			return errors.New("not found")
		},
	}

	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/llm/configs/"+cfgID.String(), nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusInternalServerError, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/llm/configs/{id}/test
// ---------------------------------------------------------------------------

func TestLLMConfigHandler_TestConnection_Success(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{
		testConnFn: func(ctx context.Context, uid uuid.UUID, id uuid.UUID) error {
			return nil // success
		},
	}

	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/configs/"+cfgID.String()+"/test", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var resp map[string]interface{}
	json.NewDecoder(rec.Body).Decode(&resp)

	if success, _ := resp["success"].(bool); !success {
		t.Error("success should be true")
	}
}

func TestLLMConfigHandler_Delete_EmptyID(t *testing.T) {
	userID := uuid.New()
	svc := &mockLLMConfigService{}

	h := &LLMConfigHandler{llmService: svc}

	// Invoke handler directly with an authenticated context but no chi route context,
	// so chi.URLParam returns "".
	ctx := context.WithValue(context.Background(), userIDKey, userID.String())
	req := httptest.NewRequest(http.MethodDelete, "/api/v1/llm/configs/", nil).
		WithContext(ctx)
	rec := httptest.NewRecorder()

	h.Delete(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

func TestLLMConfigHandler_TestConnection_Failure(t *testing.T) {
	userID := uuid.New()
	cfgID := uuid.New()

	svc := &mockLLMConfigService{
		testConnFn: func(ctx context.Context, uid uuid.UUID, id uuid.UUID) error {
			return errors.New("connection refused")
		},
	}

	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/configs/"+cfgID.String()+"/test", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}

	var resp map[string]interface{}
	json.NewDecoder(rec.Body).Decode(&resp)

	if success, _ := resp["success"].(bool); success {
		t.Error("success should be false")
	}
	if _, ok := resp["error"]; !ok {
		t.Error("response should contain error field")
	}
}

func TestLLMConfigHandler_TestConnection_EmptyID(t *testing.T) {
	userID := uuid.New()
	svc := &mockLLMConfigService{}

	h := &LLMConfigHandler{llmService: svc}

	ctx := context.WithValue(context.Background(), userIDKey, userID.String())
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/configs//test", nil).
		WithContext(ctx)
	rec := httptest.NewRecorder()

	h.TestConnection(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

func TestLLMConfigHandler_Update_EmptyID(t *testing.T) {
	userID := uuid.New()
	svc := &mockLLMConfigService{}

	h := &LLMConfigHandler{llmService: svc}

	ctx := context.WithValue(context.Background(), userIDKey, userID.String())
	body, _ := json.Marshal(domain.LLMConfig{Name: "Test"})
	req := httptest.NewRequest(http.MethodPut, "/api/v1/llm/configs/", bytes.NewReader(body)).
		WithContext(ctx)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	h.Update(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/llm/providers
// ---------------------------------------------------------------------------

func TestLLMConfigHandler_ListProviders(t *testing.T) {
	svc := &mockLLMConfigService{
		listProvidersFn: func() []string {
			return []string{"openai", "deepseek", "qwen", "anthropic", "custom"}
		},
	}

	router := setupLLMConfigRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/llm/providers", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(uuid.New().String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}

	var providers []string
	if err := json.NewDecoder(rec.Body).Decode(&providers); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if len(providers) != 5 {
		t.Errorf("len(providers) = %d, want 5", len(providers))
	}

	// Verify expected providers are present.
	expected := map[string]bool{
		"openai": true, "deepseek": true, "qwen": true, "anthropic": true, "custom": true,
	}
	for _, p := range providers {
		if !expected[p] {
			t.Errorf("unexpected provider %q", p)
		}
	}
}
