//go:build integration

package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// E2E Share Integration: create -> retrieve -> react
// ---------------------------------------------------------------------------
// These tests exercise the full handler -> service -> repository -> PostgreSQL
// stack for the shared notes feature using testcontainers.
// ---------------------------------------------------------------------------

// TestE2EIntegration_ShareLifecycle exercises the share lifecycle:
//  1. Create a shared note (POST /api/v1/share, authenticated) -> 201
//  2. Retrieve the shared note (GET /api/v1/share/{id}, public) -> 200
//  3. Add a heart reaction (POST /api/v1/share/{id}/react, authenticated) -> 200
//  4. Verify the reaction count in the database
func TestE2EIntegration_ShareLifecycle(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	var shareID string

	// -- Step 1: Create a shared note --
	t.Run("step1_create_share", func(t *testing.T) {
		body, _ := json.Marshal(domain.CreateShareRequest{
			EncryptedContent: "int-test-encrypted-content-blob-data",
			EncryptedTitle:   "int-test-encrypted-title-blob-data",
			ShareKeyHash:     "integration-test-share-key-hash-value",
			HasPassword:      false,
		})

		req, err := http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/share", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("create: new request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+srv.Token)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("create: request failed: %v", err)
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
			t.Fatal("create: ID is empty")
		}
		if createResp.URL == "" {
			t.Fatal("create: URL is empty")
		}

		shareID = createResp.ID

		// Verify the shared note exists in the database.
		var count int
		err = srv.Pool.QueryRow(context.Background(),
			"SELECT COUNT(*) FROM shared_notes WHERE id = $1", shareID,
		).Scan(&count)
		if err != nil {
			t.Fatalf("create: db check: %v", err)
		}
		if count != 1 {
			t.Errorf("create: shared_notes count = %d, want 1", count)
		}
	})

	// -- Step 2: Retrieve the shared note (no auth required) --
	t.Run("step2_get_share", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/share/"+shareID, nil)
		if err != nil {
			t.Fatalf("get: new request: %v", err)
		}

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("get: request failed: %v", err)
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
		if getResp.EncryptedContent == "" {
			t.Error("get: EncryptedContent is empty")
		}
		if getResp.EncryptedTitle == "" {
			t.Error("get: EncryptedTitle is empty")
		}
		// View count should have been incremented by the get.
		if getResp.ViewCount < 1 {
			t.Errorf("get: ViewCount = %d, want >= 1", getResp.ViewCount)
		}
	})

	// -- Step 3: Add a heart reaction (authenticated) --
	t.Run("step3_add_reaction", func(t *testing.T) {
		body, _ := json.Marshal(domain.ReactRequest{ReactionType: "heart"})

		req, err := http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/share/"+shareID+"/react", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("react: new request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+srv.Token)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("react: request failed: %v", err)
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
			t.Error("react: Active should be true on first toggle")
		}
		if reactResp.Count < 1 {
			t.Errorf("react: Count = %d, want >= 1", reactResp.Count)
		}
	})

	// -- Step 4: Verify reaction count in DB --
	t.Run("step4_verify_reaction_in_db", func(t *testing.T) {
		var heartCount int
		err := srv.Pool.QueryRow(context.Background(),
			"SELECT reaction_heart FROM shared_notes WHERE id = $1", shareID,
		).Scan(&heartCount)
		if err != nil {
			t.Fatalf("db check: %v", err)
		}
		if heartCount != 1 {
			t.Errorf("reaction_heart in db = %d, want 1", heartCount)
		}
	})
}

// TestE2EIntegration_ShareWithExpiration verifies that creating a share with
// an expiration works correctly and the expired_at column is set.
func TestE2EIntegration_ShareWithExpiration(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	expiresHours := 24

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "expiring-content-blob",
		EncryptedTitle:   "expiring-title-blob",
		ShareKeyHash:     "hash-for-expiring-share",
		ExpiresHours:     &expiresHours,
	})

	req, err := http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/share", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+srv.Token)

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusCreated)
	}

	var createResp domain.CreateShareResponse
	if err := json.NewDecoder(resp.Body).Decode(&createResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if createResp.ID == "" {
		t.Fatal("ID is empty")
	}

	// Verify expires_at is set in the database.
	var expiresAtSet bool
	err = srv.Pool.QueryRow(context.Background(),
		"SELECT expires_at IS NOT NULL FROM shared_notes WHERE id = $1",
		createResp.ID,
	).Scan(&expiresAtSet)
	if err != nil {
		t.Fatalf("db check: %v", err)
	}
	if !expiresAtSet {
		t.Error("expires_at should be set but is NULL")
	}
}

// TestE2EIntegration_ShareUnauthorizedCreate verifies that creating a share
// without authentication returns 401.
func TestE2EIntegration_ShareUnauthorizedCreate(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "content",
		EncryptedTitle:   "title",
		ShareKeyHash:     "hash",
	})

	resp, err := srv.Server.Client().Post(srv.Server.URL+"/api/v1/share", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}

// TestE2EIntegration_ShareToggleBookmark verifies toggling a bookmark reaction
// on a shared note.
func TestE2EIntegration_ShareToggleBookmark(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	// Create a shared note first.
	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: "bookmark-content-blob",
		EncryptedTitle:   "bookmark-title-blob",
		ShareKeyHash:     "bookmark-share-key-hash",
	})

	req, err := http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/share", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("create: new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+srv.Token)

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("create: request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create: status = %d, want %d", resp.StatusCode, http.StatusCreated)
	}

	var createResp domain.CreateShareResponse
	if err := json.NewDecoder(resp.Body).Decode(&createResp); err != nil {
		t.Fatalf("create: decode: %v", err)
	}

	// Toggle bookmark reaction.
	reactBody, _ := json.Marshal(domain.ReactRequest{ReactionType: "bookmark"})

	req, err = http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/share/"+createResp.ID+"/react", bytes.NewReader(reactBody))
	if err != nil {
		t.Fatalf("react: new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+srv.Token)

	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("react: request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("react: status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var reactResp domain.ReactResponse
	if err := json.NewDecoder(resp.Body).Decode(&reactResp); err != nil {
		t.Fatalf("react: decode: %v", err)
	}
	if reactResp.ReactionType != "bookmark" {
		t.Errorf("ReactionType = %q, want %q", reactResp.ReactionType, "bookmark")
	}
	if !reactResp.Active {
		t.Error("Active should be true")
	}

	// Verify bookmark count in database.
	var bookmarkCount int
	err = srv.Pool.QueryRow(context.Background(),
		"SELECT reaction_bookmark FROM shared_notes WHERE id = $1", createResp.ID,
	).Scan(&bookmarkCount)
	if err != nil {
		t.Fatalf("db check: %v", err)
	}
	if bookmarkCount != 1 {
		t.Errorf("reaction_bookmark in db = %d, want 1", bookmarkCount)
	}
}

// TestE2EIntegration_ShareReactionToggleOff verifies that toggling a reaction
// a second time removes it (toggle off behavior).
func TestE2EIntegration_ShareReactionToggleOff(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	// Create a shared note.
	body, _ := json.Marshal(domain.CreateShareRequest{
		EncryptedContent: fmt.Sprintf("toggle-content-%s", uuid.New().String()[:8]),
		EncryptedTitle:   "toggle-title",
		ShareKeyHash:     "toggle-hash",
	})

	req, err := http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/share", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("create: new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+srv.Token)

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("create: request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create: status = %d, want %d", resp.StatusCode, http.StatusCreated)
	}

	var createResp domain.CreateShareResponse
	if err := json.NewDecoder(resp.Body).Decode(&createResp); err != nil {
		t.Fatalf("create: decode: %v", err)
	}

	// Toggle heart on (first toggle).
	reactBody, _ := json.Marshal(domain.ReactRequest{ReactionType: "heart"})
	req, _ = http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/share/"+createResp.ID+"/react", bytes.NewReader(reactBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+srv.Token)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("react1: request failed: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("react1: status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	// Toggle heart off (second toggle).
	req, _ = http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/share/"+createResp.ID+"/react", bytes.NewReader(reactBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+srv.Token)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("react2: request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("react2: status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var reactResp domain.ReactResponse
	if err := json.NewDecoder(resp.Body).Decode(&reactResp); err != nil {
		t.Fatalf("react2: decode: %v", err)
	}
	if reactResp.Active {
		t.Error("Active should be false after second toggle (removal)")
	}
	if reactResp.Count != 0 {
		t.Errorf("Count = %d, want 0 after toggle off", reactResp.Count)
	}
}
