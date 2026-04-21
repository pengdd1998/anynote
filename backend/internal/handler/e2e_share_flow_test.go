package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// E2E Share Flow: create share -> get share -> reactions -> discover
// ---------------------------------------------------------------------------

// TestE2EShareFlow exercises the complete share lifecycle:
// create a shared note, retrieve it, toggle reactions, and list the discover feed.
func TestE2EShareFlow(t *testing.T) {
	userID := uuid.New()
	shareID := "e2eshare1234567890abcdef1234"
	now := time.Now().UTC()

	// ------ mock service ------

	shareSvc := &mockShareService{
		createShareFn: func(ctx context.Context, uid uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
			if uid != userID {
				t.Errorf("createShare: userID = %v, want %v", uid, userID)
			}
			return &domain.CreateShareResponse{
				ID:  shareID,
				URL: "/share/" + shareID,
			}, nil
		},
		getShareFn: func(ctx context.Context, id string) (*domain.GetShareResponse, error) {
			if id != shareID {
				t.Errorf("getShare: id = %q, want %q", id, shareID)
			}
			return &domain.GetShareResponse{
				ID:               id,
				EncryptedContent: "e2e-encrypted-content-blob",
				EncryptedTitle:   "e2e-encrypted-title-blob",
				HasPassword:      false,
				ViewCount:        1,
			}, nil
		},
		discoverFeedFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			return []domain.DiscoverFeedItem{
				{
					ID:             shareID,
					EncryptedTitle: "e2e-encrypted-title-blob",
					ViewCount:      1,
					ReactionHeart:  1,
					CreatedAt:      now,
				},
			}, nil
		},
		toggleReactionFn: func(ctx context.Context, uid uuid.UUID, sid string, reactionType string) (*domain.ReactResponse, error) {
			if uid != userID {
				t.Errorf("toggleReaction: userID = %v, want %v", uid, userID)
			}
			if sid != shareID {
				t.Errorf("toggleReaction: shareID = %q, want %q", sid, shareID)
			}
			return &domain.ReactResponse{
				ReactionType: reactionType,
				Active:       true,
				Count:        1,
			}, nil
		},
	}

	// ------ build router ------

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)

	// Public routes.
	r.Get("/api/v1/share/{id}", h.GetShare)
	r.Get("/api/v1/share/discover", h.DiscoverFeed)

	// Authenticated routes.
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/share", h.CreateShare)
		authR.Post("/api/v1/share/{id}/react", h.ToggleReaction)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	client := server.Client()
	authHeader := "Bearer " + generateTestToken(userID.String())

	// ------ Step 1: POST /api/v1/share (expect 201) ------

	t.Run("step1_create_share", func(t *testing.T) {
		body, _ := json.Marshal(domain.CreateShareRequest{
			EncryptedContent: "e2e-encrypted-content-blob",
			EncryptedTitle:   "e2e-encrypted-title-blob",
			ShareKeyHash:     "e2e-share-key-hash",
		})

		req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/share", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("create: new request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", authHeader)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("create request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("create: status = %d, want %d", resp.StatusCode, http.StatusCreated)
		}

		var createResp domain.CreateShareResponse
		if err := json.NewDecoder(resp.Body).Decode(&createResp); err != nil {
			t.Fatalf("create: decode: %v", err)
		}
		if createResp.ID == "" {
			t.Error("create: ID is empty")
		}
		if createResp.URL == "" {
			t.Error("create: URL is empty")
		}
	})

	// ------ Step 2: GET /api/v1/share/{id} (expect 200) ------

	t.Run("step2_get_share", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/share/"+shareID, nil)
		if err != nil {
			t.Fatalf("get: new request: %v", err)
		}

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("get request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("get: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var getResp domain.GetShareResponse
		if err := json.NewDecoder(resp.Body).Decode(&getResp); err != nil {
			t.Fatalf("get: decode: %v", err)
		}
		if getResp.ID != shareID {
			t.Errorf("get: ID = %q, want %q", getResp.ID, shareID)
		}
		if getResp.EncryptedContent != "e2e-encrypted-content-blob" {
			t.Errorf("get: EncryptedContent = %q, want encrypted content", getResp.EncryptedContent)
		}
	})

	// ------ Step 3: POST /api/v1/share/{id}/react (heart, expect 200) ------

	t.Run("step3_toggle_heart", func(t *testing.T) {
		body, _ := json.Marshal(domain.ReactRequest{ReactionType: "heart"})

		req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/share/"+shareID+"/react", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("react: new request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", authHeader)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("react request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("react: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var reactResp domain.ReactResponse
		if err := json.NewDecoder(resp.Body).Decode(&reactResp); err != nil {
			t.Fatalf("react: decode: %v", err)
		}
		if reactResp.ReactionType != "heart" {
			t.Errorf("react: ReactionType = %q, want %q", reactResp.ReactionType, "heart")
		}
		if !reactResp.Active {
			t.Error("react: Active should be true")
		}
	})

	// ------ Step 4: GET /api/v1/share/discover (expect 200) ------

	t.Run("step4_discover_feed", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/share/discover", nil)
		if err != nil {
			t.Fatalf("discover: new request: %v", err)
		}

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("discover request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("discover: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var items []domain.DiscoverFeedItem
		if err := json.NewDecoder(resp.Body).Decode(&items); err != nil {
			t.Fatalf("discover: decode: %v", err)
		}
		if len(items) != 1 {
			t.Fatalf("discover: len(items) = %d, want 1", len(items))
		}
		if items[0].ID != shareID {
			t.Errorf("discover: items[0].ID = %q, want %q", items[0].ID, shareID)
		}
	})
}

// TestE2EShareFlow_CreateWithExpiration verifies that creating a share
// with an expiration works correctly.
func TestE2EShareFlow_CreateWithExpiration(t *testing.T) {
	userID := uuid.New()
	shareID := "expshare1234567890abcdef12345"
	expiresHours := 24

	shareSvc := &mockShareService{
		createShareFn: func(ctx context.Context, uid uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
			if req.ExpiresHours == nil || *req.ExpiresHours != expiresHours {
				t.Errorf("createShare: ExpiresHours = %v, want %d", req.ExpiresHours, expiresHours)
			}
			return &domain.CreateShareResponse{
				ID:  shareID,
				URL: "/share/" + shareID,
			}, nil
		},
	}

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/share", h.CreateShare)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "expiring-content",
		EncryptedTitle:   "expiring-title",
		ShareKeyHash:     "hash",
		ExpiresHours:     &expiresHours,
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/share", bytes.NewReader(body))
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

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusCreated)
	}

	var createResp domain.CreateShareResponse
	if err := json.NewDecoder(resp.Body).Decode(&createResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if createResp.ID != shareID {
		t.Errorf("ID = %q, want %q", createResp.ID, shareID)
	}
}

// TestE2EShareFlow_CreateWithMaxViews verifies that creating a share
// with a max-views limit works correctly.
func TestE2EShareFlow_CreateWithMaxViews(t *testing.T) {
	userID := uuid.New()
	shareID := "maxvshare1234567890abcdef1234"
	maxViews := 10

	shareSvc := &mockShareService{
		createShareFn: func(ctx context.Context, uid uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
			if req.MaxViews == nil || *req.MaxViews != maxViews {
				t.Errorf("createShare: MaxViews = %v, want %d", req.MaxViews, maxViews)
			}
			return &domain.CreateShareResponse{
				ID:  shareID,
				URL: "/share/" + shareID,
			}, nil
		},
	}

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/share", h.CreateShare)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "max-views-content",
		EncryptedTitle:   "max-views-title",
		ShareKeyHash:     "hash",
		MaxViews:         &maxViews,
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/share", bytes.NewReader(body))
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

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusCreated)
	}
}

// TestE2EShareFlow_CreateWithPassword verifies that creating a share
// with password protection works correctly.
func TestE2EShareFlow_CreateWithPassword(t *testing.T) {
	userID := uuid.New()
	shareID := "pwdshare1234567890abcdef12345"

	shareSvc := &mockShareService{
		createShareFn: func(ctx context.Context, uid uuid.UUID, req domain.CreateShareRequest) (*domain.CreateShareResponse, error) {
			if !req.HasPassword {
				t.Error("createShare: HasPassword = false, want true")
			}
			return &domain.CreateShareResponse{
				ID:  shareID,
				URL: "/share/" + shareID,
			}, nil
		},
	}

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/share", h.CreateShare)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "password-protected-content",
		EncryptedTitle:   "password-protected-title",
		ShareKeyHash:     "hash",
		HasPassword:      true,
	})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/share", bytes.NewReader(body))
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

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusCreated)
	}
}

// TestE2EShareFlow_ExpiredShare verifies that accessing an expired share
// returns 410 Gone.
func TestE2EShareFlow_ExpiredShare(t *testing.T) {
	shareSvc := &mockShareService{
		getShareFn: func(ctx context.Context, id string) (*domain.GetShareResponse, error) {
			return nil, service.ErrShareExpired
		},
	}

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Get("/api/v1/share/{id}", h.GetShare)

	server := httptest.NewServer(r)
	defer server.Close()

	resp, err := server.Client().Get(server.URL + "/api/v1/share/expired-share-id")
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusGone {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusGone)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&errResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if errResp.Error.Code != "expired" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "expired")
	}
}

// TestE2EShareFlow_MaxViewsReached verifies that accessing a share at
// its maximum view count returns 410 Gone.
func TestE2EShareFlow_MaxViewsReached(t *testing.T) {
	shareSvc := &mockShareService{
		getShareFn: func(ctx context.Context, id string) (*domain.GetShareResponse, error) {
			return nil, service.ErrShareMaxViews
		},
	}

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Get("/api/v1/share/{id}", h.GetShare)

	server := httptest.NewServer(r)
	defer server.Close()

	resp, err := server.Client().Get(server.URL + "/api/v1/share/maxed-share-id")
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusGone {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusGone)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&errResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if errResp.Error.Code != "max_views" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "max_views")
	}
}

// TestE2EShareFlow_ToggleBookmark verifies toggling a bookmark reaction.
func TestE2EShareFlow_ToggleBookmark(t *testing.T) {
	userID := uuid.New()
	shareID := "bmshare1234567890abcdef123456"

	shareSvc := &mockShareService{
		toggleReactionFn: func(ctx context.Context, uid uuid.UUID, sid string, reactionType string) (*domain.ReactResponse, error) {
			if reactionType != "bookmark" {
				t.Errorf("toggleReaction: reactionType = %q, want %q", reactionType, "bookmark")
			}
			return &domain.ReactResponse{
				ReactionType: "bookmark",
				Active:       true,
				Count:        1,
			}, nil
		},
	}

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/share/{id}/react", h.ToggleReaction)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.ReactRequest{ReactionType: "bookmark"})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/share/"+shareID+"/react", bytes.NewReader(body))
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

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var reactResp domain.ReactResponse
	if err := json.NewDecoder(resp.Body).Decode(&reactResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if reactResp.ReactionType != "bookmark" {
		t.Errorf("ReactionType = %q, want %q", reactResp.ReactionType, "bookmark")
	}
	if !reactResp.Active {
		t.Error("Active should be true")
	}
}

// TestE2EShareFlow_InvalidReaction verifies that an invalid reaction type
// returns 400 Bad Request.
func TestE2EShareFlow_InvalidReaction(t *testing.T) {
	userID := uuid.New()

	shareSvc := &mockShareService{
		toggleReactionFn: func(ctx context.Context, uid uuid.UUID, sid string, reactionType string) (*domain.ReactResponse, error) {
			return nil, service.ErrInvalidReaction
		},
	}

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/share/{id}/react", h.ToggleReaction)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.ReactRequest{ReactionType: "invalid"})

	req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/share/some-share/react", bytes.NewReader(body))
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

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&errResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if errResp.Error.Code != "invalid_reaction" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "invalid_reaction")
	}
}

// TestE2EShareFlow_DiscoverFeedWithPagination verifies that the discover
// feed accepts pagination query parameters.
func TestE2EShareFlow_DiscoverFeedWithPagination(t *testing.T) {
	var capturedLimit, capturedOffset int

	shareSvc := &mockShareService{
		discoverFeedFn: func(ctx context.Context, limit, offset int) ([]domain.DiscoverFeedItem, error) {
			capturedLimit = limit
			capturedOffset = offset
			return []domain.DiscoverFeedItem{
				{ID: "share1", EncryptedTitle: "title1", CreatedAt: time.Now()},
				{ID: "share2", EncryptedTitle: "title2", CreatedAt: time.Now()},
			}, nil
		},
	}

	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Get("/api/v1/share/discover", h.DiscoverFeed)

	server := httptest.NewServer(r)
	defer server.Close()

	req, err := http.NewRequest(http.MethodGet, server.URL+"/api/v1/share/discover?limit=5&offset=10", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}

	resp, err := server.Client().Do(req)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	if capturedLimit != 5 {
		t.Errorf("limit = %d, want 5", capturedLimit)
	}
	if capturedOffset != 10 {
		t.Errorf("offset = %d, want 10", capturedOffset)
	}

	var items []domain.DiscoverFeedItem
	if err := json.NewDecoder(resp.Body).Decode(&items); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(items) != 2 {
		t.Errorf("len(items) = %d, want 2", len(items))
	}
}

// TestE2EShareFlow_UnauthorizedCreate verifies that creating a share
// without authentication returns 401.
func TestE2EShareFlow_UnauthorizedCreate(t *testing.T) {
	shareSvc := &mockShareService{}
	h := &ShareHandler{shareService: shareSvc}

	r := chi.NewRouter()
	r.Use(RequestLogger)
	r.Group(func(authR chi.Router) {
		authR.Use(AuthMiddleware(testJWTSecret))
		authR.Post("/api/v1/share", h.CreateShare)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "content",
		EncryptedTitle:   "title",
		ShareKeyHash:     "hash",
	})

	resp, err := server.Client().Post(server.URL+"/api/v1/share", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}
