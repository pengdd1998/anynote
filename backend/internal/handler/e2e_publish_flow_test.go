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

// ---------------------------------------------------------------------------
// E2E Publish Flow: verify platform connection -> publish -> check history
// ---------------------------------------------------------------------------

// TestE2EPublishFlow exercises the publish lifecycle:
// verify a platform connection, publish content, and check history.
//
// The Connect endpoint uses SSE streaming which is difficult to exercise in a
// standard httptest.Server E2E flow, so this test uses Verify to confirm the
// connection state and focuses on the publish -> history round-trip.
func TestE2EPublishFlow(t *testing.T) {
	userID := uuid.New()
	connID := uuid.New()
	publishLogID := uuid.New()
	platformName := "xiaohongshu"

	// ------ shared state across mock calls ------

	connectionVerified := false
	contentItemID := uuid.New()
	publishedAt := time.Now()

	// ------ mock platform service (for verify) ------

	platSvc := &mockPlatformService{
		verifyFn: func(ctx context.Context, uid uuid.UUID, pName string) (*domain.PlatformConnection, error) {
			if uid != userID {
				t.Errorf("verify: userID = %v, want %v", uid, userID)
			}
			if pName != platformName {
				t.Errorf("verify: platform = %q, want %q", pName, platformName)
			}
			connectionVerified = true
			return &domain.PlatformConnection{
				ID:          connID,
				UserID:      userID,
				Platform:    platformName,
				Status:      "active",
				DisplayName: "xhs_test_user",
				LastVerified: &publishedAt,
				CreatedAt:   time.Now(),
				UpdatedAt:   time.Now(),
			}, nil
		},
	}

	// ------ mock publish service ------

	publishSvc := &mockPublishService{
		publishFn: func(ctx context.Context, uid uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
			if uid != userID {
				t.Errorf("publish: userID = %v, want %v", uid, userID)
			}
			if req.Platform != platformName {
				t.Errorf("publish: platform = %q, want %q", req.Platform, platformName)
			}
			return &domain.PublishLog{
				ID:            publishLogID,
				UserID:        userID,
				Platform:      platformName,
				PlatformConnID: &connID,
				ContentItemID: &contentItemID,
				Title:         req.Title,
				Content:       req.Content,
				Status:        "pending",
				CreatedAt:     time.Now(),
			}, nil
		},
		historyFn: func(ctx context.Context, uid uuid.UUID) ([]domain.PublishLog, error) {
			if uid != userID {
				t.Errorf("history: userID = %v, want %v", uid, userID)
			}
			return []domain.PublishLog{
				{
					ID:            publishLogID,
					UserID:        userID,
					Platform:      platformName,
					PlatformConnID: &connID,
					ContentItemID: &contentItemID,
					Title:         "E2E Test Note",
					Content:       "Published from E2E test",
					Status:        "published",
					PlatformURL:   "https://xiaohongshu.com/post/e2e-test",
					PublishedAt:   &publishedAt,
					CreatedAt:     time.Now(),
				},
			}, nil
		},
	}

	// ------ build router combining platform + publish handlers ------

	platHandler := NewPlatformHandler(platSvc, []byte("test-master-key-16"))
	pubHandler := &PublishHandler{publishService: publishSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)

	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))

		// Platform routes.
		authR.Post("/api/v1/platforms/{platform}/verify", platHandler.Verify)
		authR.Get("/api/v1/platforms", platHandler.List)

		// Publish routes.
		authR.Post("/api/v1/publish", pubHandler.Publish)
		authR.Get("/api/v1/publish/history", pubHandler.History)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	client := server.Client()
	authHeader := "Bearer " + generateTestToken(userID.String())

	// ------ Step 1: POST /api/v1/platforms/xiaohongshu/verify (expect 200) ------

	t.Run("step1_verify_connection", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/platforms/xiaohongshu/verify", nil)
		if err != nil {
			t.Fatalf("verify: new request: %v", err)
		}
		req.Header.Set("Authorization", authHeader)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("verify request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("verify: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var conn domain.PlatformConnection
		if err := json.NewDecoder(resp.Body).Decode(&conn); err != nil {
			t.Fatalf("verify: decode: %v", err)
		}
		if conn.Status != "active" {
			t.Errorf("verify: status = %q, want %q", conn.Status, "active")
		}
		if conn.Platform != platformName {
			t.Errorf("verify: platform = %q, want %q", conn.Platform, platformName)
		}
		if !connectionVerified {
			t.Error("verify: expected connection to be verified in mock")
		}
	})

	// ------ Step 2: POST /api/v1/publish (expect 202) ------

	t.Run("step2_publish", func(t *testing.T) {
		body, _ := json.Marshal(publishRequest{
			Platform:      platformName,
			ContentItemID: contentItemID.String(),
			Title:         "E2E Test Note",
			Content:       "Published from E2E test",
			Tags:          []string{"test", "e2e"},
		})

		req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/publish", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("publish: new request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", authHeader)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("publish request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusAccepted {
			t.Fatalf("publish: status = %d, want %d", resp.StatusCode, http.StatusAccepted)
		}

		var pubLog domain.PublishLog
		if err := json.NewDecoder(resp.Body).Decode(&pubLog); err != nil {
			t.Fatalf("publish: decode: %v", err)
		}
		if pubLog.ID != publishLogID {
			t.Errorf("publish: ID = %v, want %v", pubLog.ID, publishLogID)
		}
		if pubLog.Status != "pending" {
			t.Errorf("publish: status = %q, want %q", pubLog.Status, "pending")
		}
		if pubLog.Platform != platformName {
			t.Errorf("publish: platform = %q, want %q", pubLog.Platform, platformName)
		}
	})

	// ------ Step 3: GET /api/v1/publish/history (expect 200) ------

	t.Run("step3_history", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/publish/history", nil)
		if err != nil {
			t.Fatalf("history: new request: %v", err)
		}
		req.Header.Set("Authorization", authHeader)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("history request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("history: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var logs []domain.PublishLog
		if err := json.NewDecoder(resp.Body).Decode(&logs); err != nil {
			t.Fatalf("history: decode: %v", err)
		}
		if len(logs) != 1 {
			t.Fatalf("history: len(logs) = %d, want 1", len(logs))
		}
		if logs[0].ID != publishLogID {
			t.Errorf("history: logs[0].ID = %v, want %v", logs[0].ID, publishLogID)
		}
		if logs[0].Status != "published" {
			t.Errorf("history: logs[0].Status = %q, want %q", logs[0].Status, "published")
		}
		if logs[0].PlatformURL != "https://xiaohongshu.com/post/e2e-test" {
			t.Errorf("history: PlatformURL = %q, want %q", logs[0].PlatformURL, "https://xiaohongshu.com/post/e2e-test")
		}
	})
}

// TestE2EPublishFlow_SSEConnect verifies that the SSE-based Connect endpoint
// can be exercised end-to-end. This test uses a direct handler call approach
// (not httptest.Server) to properly handle the streaming response and context
// cancellation, matching the existing pattern in platform_handler_test.go.
func TestE2EPublishFlow_SSEConnect(t *testing.T) {
	userID := uuid.New()
	qrPNG := []byte("fake-qr-png-data")
	callCount := 0

	platSvc := &mockPlatformService{
		startAuthFn: func(ctx context.Context, uid uuid.UUID, pName string, masterKey []byte) (string, []byte, error) {
			return "e2e-auth-ref", qrPNG, nil
		},
		pollAuthFn: func(ctx context.Context, uid uuid.UUID, pName string, authRef string, masterKey []byte) ([]byte, error) {
			callCount++
			if callCount == 1 {
				// Still waiting on first poll.
				return nil, nil
			}
			// Second poll succeeds.
			return []byte("encrypted-auth-data"), nil
		},
	}

	platHandler := NewPlatformHandler(platSvc, []byte("test-master-key-16"))

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.With(AuthMiddleware(testJWTSecret)).Post("/api/v1/platforms/{platform}/connect", platHandler.Connect)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	req := httptest.NewRequest(http.MethodPost, "/api/v1/platforms/xiaohongshu/connect", nil).WithContext(ctx)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	body := rec.Body.String()

	if !strings.Contains(body, "event: qr_code") {
		t.Errorf("expected qr_code event in SSE stream, got: %s", body)
	}
	if !strings.Contains(body, "e2e-auth-ref") {
		t.Error("expected auth_ref in SSE stream")
	}
	if !strings.Contains(body, `"status":"waiting"`) {
		t.Error("expected waiting status in SSE stream")
	}
	if !strings.Contains(body, `"status":"done"`) {
		t.Error("expected done status in SSE stream")
	}
}

// TestE2EPublishFlow_ListPlatforms verifies listing platform connections
// after establishing one.
func TestE2EPublishFlow_ListPlatforms(t *testing.T) {
	userID := uuid.New()
	connID := uuid.New()

	platSvc := &mockPlatformService{
		listFn: func(ctx context.Context, uid uuid.UUID) ([]domain.PlatformConnection, error) {
			return []domain.PlatformConnection{
				{
					ID:          connID,
					UserID:      userID,
					Platform:    "xiaohongshu",
					Status:      "active",
					DisplayName: "xhs_user",
					CreatedAt:   time.Now(),
					UpdatedAt:   time.Now(),
				},
			}, nil
		},
	}

	platHandler := NewPlatformHandler(platSvc, []byte("test-master-key-16"))

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Get("/api/v1/platforms", platHandler.List)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/platforms", nil)
	if err != nil {
		t.Fatalf("list: new request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("list request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("list: status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var conns []domain.PlatformConnection
	if err := json.NewDecoder(resp.Body).Decode(&conns); err != nil {
		t.Fatalf("list: decode: %v", err)
	}
	if len(conns) != 1 {
		t.Fatalf("list: len(conns) = %d, want 1", len(conns))
	}
	if conns[0].Platform != "xiaohongshu" {
		t.Errorf("list: platform = %q, want %q", conns[0].Platform, "xiaohongshu")
	}
	if conns[0].Status != "active" {
		t.Errorf("list: status = %q, want %q", conns[0].Status, "active")
	}
}

// TestE2EPublishFlow_Unauthorized verifies that publish endpoints
// return 401 without authentication.
func TestE2EPublishFlow_Unauthorized(t *testing.T) {
	publishSvc := &mockPublishService{}
	pubHandler := &PublishHandler{publishService: publishSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/publish", pubHandler.Publish)
		authR.Get("/api/v1/publish/history", pubHandler.History)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	t.Run("publish_no_auth", func(t *testing.T) {
		body, _ := json.Marshal(publishRequest{
			Platform: "xiaohongshu",
			Title:    "Test",
			Content:  "Content",
		})
		resp, err := server.Client().Post(server.URL+"/api/v1/publish", "application/json", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("request: %v", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("publish no auth: status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
		}
	})

	t.Run("history_no_auth", func(t *testing.T) {
		resp, err := server.Client().Get(server.URL + "/api/v1/publish/history")
		if err != nil {
			t.Fatalf("request: %v", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("history no auth: status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
		}
	})
}

// TestE2EPublishFlow_PublishError verifies that a service error during
// publish returns 500.
func TestE2EPublishFlow_PublishError(t *testing.T) {
	userID := uuid.New()

	publishSvc := &mockPublishService{
		publishFn: func(ctx context.Context, uid uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
			return nil, errors.New("queue unavailable")
		},
	}

	pubHandler := &PublishHandler{publishService: publishSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/publish", pubHandler.Publish)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(publishRequest{
		Platform: "xiaohongshu",
		Title:    "Test",
		Content:  "Content",
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/publish", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusInternalServerError)
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(resp.Body).Decode(&errResp)
	if errResp.Error.Code != "publish_error" {
		t.Errorf("error = %q, want %q", errResp.Error.Code, "publish_error")
	}
}
