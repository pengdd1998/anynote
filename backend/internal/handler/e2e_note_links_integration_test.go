//go:build integration

package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// E2E Note Links Integration: create -> backlinks -> outbound -> graph -> delete
// ---------------------------------------------------------------------------
// These tests exercise the full handler -> service -> repository -> PostgreSQL
// stack for the note links feature using testcontainers.
// ---------------------------------------------------------------------------

// TestE2EIntegration_NoteLinksLifecycle exercises the note links lifecycle:
//  1. Create links (POST /api/v1/notes/links) -> 200
//  2. Get backlinks (GET /api/v1/notes/{noteId}/backlinks) -> 200
//  3. Get outbound links (GET /api/v1/notes/{noteId}/links) -> 200
//  4. Get graph (GET /api/v1/notes/graph) -> 200
//  5. Delete link (DELETE /api/v1/notes/links/{sourceId}/{targetId}) -> 200
func TestE2EIntegration_NoteLinksLifecycle(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	noteA := uuid.New()
	noteB := uuid.New()
	noteC := uuid.New()

	// -- Step 1: Create links A->B and A->C --
	t.Run("step1_create_links", func(t *testing.T) {
		body, _ := json.Marshal(domain.CreateNoteLinksRequest{
			Links: []domain.NoteLinkItem{
				{SourceID: noteA, TargetID: noteB, LinkType: "reference"},
				{SourceID: noteA, TargetID: noteC, LinkType: "reference"},
			},
		})

		req, err := http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/notes/links", bytes.NewReader(body))
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

		// Note: handler returns 200 for CreateLinks (not 201).
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("create: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var linksResp domain.NoteLinksResponse
		if err := json.NewDecoder(resp.Body).Decode(&linksResp); err != nil {
			t.Fatalf("create: decode: %v", err)
		}
		if len(linksResp.Links) != 2 {
			t.Fatalf("create: len(Links) = %d, want 2", len(linksResp.Links))
		}
		for _, link := range linksResp.Links {
			if link.SourceID != noteA {
				t.Errorf("create: SourceID = %v, want %v", link.SourceID, noteA)
			}
			if link.UserID != srv.UserID {
				t.Errorf("create: UserID = %v, want %v", link.UserID, srv.UserID)
			}
			if link.LinkType != "reference" {
				t.Errorf("create: LinkType = %q, want %q", link.LinkType, "reference")
			}
		}
	})

	// -- Step 2: Get backlinks for note B (should find A->B) --
	t.Run("step2_backlinks", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/notes/"+noteB.String()+"/backlinks", nil)
		if err != nil {
			t.Fatalf("backlinks: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+srv.Token)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("backlinks: request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("backlinks: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var linksResp domain.NoteLinksResponse
		if err := json.NewDecoder(resp.Body).Decode(&linksResp); err != nil {
			t.Fatalf("backlinks: decode: %v", err)
		}
		if len(linksResp.Links) != 1 {
			t.Fatalf("backlinks: len(Links) = %d, want 1", len(linksResp.Links))
		}
		if linksResp.Links[0].SourceID != noteA {
			t.Errorf("backlinks: SourceID = %v, want %v (A links to B)", linksResp.Links[0].SourceID, noteA)
		}
		if linksResp.Links[0].TargetID != noteB {
			t.Errorf("backlinks: TargetID = %v, want %v", linksResp.Links[0].TargetID, noteB)
		}
	})

	// -- Step 3: Get outbound links from note A (should find A->B and A->C) --
	t.Run("step3_outbound_links", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/notes/"+noteA.String()+"/links", nil)
		if err != nil {
			t.Fatalf("outbound: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+srv.Token)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("outbound: request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("outbound: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var linksResp domain.NoteLinksResponse
		if err := json.NewDecoder(resp.Body).Decode(&linksResp); err != nil {
			t.Fatalf("outbound: decode: %v", err)
		}
		if len(linksResp.Links) != 2 {
			t.Fatalf("outbound: len(Links) = %d, want 2", len(linksResp.Links))
		}

		// Verify both targets are present.
		foundB, foundC := false, false
		for _, link := range linksResp.Links {
			if link.TargetID == noteB {
				foundB = true
			}
			if link.TargetID == noteC {
				foundC = true
			}
		}
		if !foundB {
			t.Error("outbound: link to noteB not found")
		}
		if !foundC {
			t.Error("outbound: link to noteC not found")
		}
	})

	// -- Step 4: Get graph --
	t.Run("step4_graph", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/notes/graph", nil)
		if err != nil {
			t.Fatalf("graph: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+srv.Token)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("graph: request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("graph: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var graphResp domain.NoteGraphResponse
		if err := json.NewDecoder(resp.Body).Decode(&graphResp); err != nil {
			t.Fatalf("graph: decode: %v", err)
		}

		// Should have 3 nodes (A, B, C) and 2 edges (A->B, A->C).
		if len(graphResp.Nodes) != 3 {
			t.Errorf("graph: len(Nodes) = %d, want 3", len(graphResp.Nodes))
		}
		if len(graphResp.Edges) != 2 {
			t.Errorf("graph: len(Edges) = %d, want 2", len(graphResp.Edges))
		}
	})

	// -- Step 5: Delete link A->B --
	t.Run("step5_delete_link", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodDelete,
			srv.Server.URL+"/api/v1/notes/links/"+noteA.String()+"/"+noteB.String(), nil)
		if err != nil {
			t.Fatalf("delete: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+srv.Token)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("delete: request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("delete: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var result map[string]string
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			t.Fatalf("delete: decode: %v", err)
		}
		if result["status"] != "deleted" {
			t.Errorf("delete: status = %q, want %q", result["status"], "deleted")
		}
	})

	// -- Step 5b: Verify deletion by checking backlinks again --
	t.Run("step5b_verify_deletion", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/notes/"+noteB.String()+"/backlinks", nil)
		if err != nil {
			t.Fatalf("backlinks-after-delete: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+srv.Token)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("backlinks-after-delete: request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("backlinks-after-delete: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var linksResp domain.NoteLinksResponse
		if err := json.NewDecoder(resp.Body).Decode(&linksResp); err != nil {
			t.Fatalf("backlinks-after-delete: decode: %v", err)
		}
		if len(linksResp.Links) != 0 {
			t.Errorf("backlinks-after-delete: len(Links) = %d, want 0 (link was deleted)", len(linksResp.Links))
		}
	})

	// -- Step 5c: Verify A->C still exists --
	t.Run("step5c_remaining_link", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/notes/"+noteA.String()+"/links", nil)
		if err != nil {
			t.Fatalf("outbound-after-delete: new request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+srv.Token)

		resp, err := client.Do(req)
		if err != nil {
			t.Fatalf("outbound-after-delete: request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Fatalf("outbound-after-delete: status = %d, want %d", resp.StatusCode, http.StatusOK)
		}

		var linksResp domain.NoteLinksResponse
		if err := json.NewDecoder(resp.Body).Decode(&linksResp); err != nil {
			t.Fatalf("outbound-after-delete: decode: %v", err)
		}
		if len(linksResp.Links) != 1 {
			t.Fatalf("outbound-after-delete: len(Links) = %d, want 1 (A->C remains)", len(linksResp.Links))
		}
		if linksResp.Links[0].TargetID != noteC {
			t.Errorf("outbound-after-delete: TargetID = %v, want %v", linksResp.Links[0].TargetID, noteC)
		}
	})
}

// TestE2EIntegration_NoteLinksEmptyGraph verifies that getting the graph for a
// user with no links returns an empty response.
func TestE2EIntegration_NoteLinksEmptyGraph(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	req, err := http.NewRequest(http.MethodGet, srv.Server.URL+"/api/v1/notes/graph", nil)
	if err != nil {
		t.Fatalf("graph: new request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+srv.Token)

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("graph: request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("graph: status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var graphResp domain.NoteGraphResponse
	if err := json.NewDecoder(resp.Body).Decode(&graphResp); err != nil {
		t.Fatalf("graph: decode: %v", err)
	}
	if len(graphResp.Nodes) != 0 {
		t.Errorf("graph: len(Nodes) = %d, want 0 for empty graph", len(graphResp.Nodes))
	}
	if len(graphResp.Edges) != 0 {
		t.Errorf("graph: len(Edges) = %d, want 0 for empty graph", len(graphResp.Edges))
	}
}

// TestE2EIntegration_NoteLinksUnauthorized verifies that note link endpoints
// require authentication.
func TestE2EIntegration_NoteLinksUnauthorized(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	endpoints := []struct {
		name   string
		method string
		path   string
	}{
		{"create_links", http.MethodPost, "/api/v1/notes/links"},
		{"graph", http.MethodGet, "/api/v1/notes/graph"},
		{"backlinks", http.MethodGet, "/api/v1/notes/" + uuid.New().String() + "/backlinks"},
		{"outbound", http.MethodGet, "/api/v1/notes/" + uuid.New().String() + "/links"},
		{"delete", http.MethodDelete, "/api/v1/notes/links/" + uuid.New().String() + "/" + uuid.New().String()},
	}

	for _, ep := range endpoints {
		t.Run(ep.name, func(t *testing.T) {
			var body *bytes.Reader
			if ep.method == http.MethodPost {
				b, _ := json.Marshal(domain.CreateNoteLinksRequest{
					Links: []domain.NoteLinkItem{
						{SourceID: uuid.New(), TargetID: uuid.New(), LinkType: "reference"},
					},
				})
				body = bytes.NewReader(b)
			} else {
				body = bytes.NewReader(nil)
			}

			req, err := http.NewRequest(ep.method, srv.Server.URL+ep.path, body)
			if err != nil {
				t.Fatalf("new request: %v", err)
			}
			if ep.method == http.MethodPost {
				req.Header.Set("Content-Type", "application/json")
			}

			resp, err := srv.Server.Client().Do(req)
			if err != nil {
				t.Fatalf("request failed: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusUnauthorized {
				t.Errorf("%s: status = %d, want %d", ep.name, resp.StatusCode, http.StatusUnauthorized)
			}
		})
	}
}

// TestE2EIntegration_NoteLinksValidation verifies that creating links with an
// empty links array returns 400.
func TestE2EIntegration_NoteLinksValidation(t *testing.T) {
	srv := setupFullServer(t)
	defer srv.Server.Close()

	client := srv.Server.Client()

	body, _ := json.Marshal(domain.CreateNoteLinksRequest{
		Links: []domain.NoteLinkItem{},
	})

	req, err := http.NewRequest(http.MethodPost, srv.Server.URL+"/api/v1/notes/links", bytes.NewReader(body))
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

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(resp.Body).Decode(&errResp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "validation_error")
	}
}
