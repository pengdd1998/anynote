package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Helpers for the JSON payloads of the publish rules endpoints
// ---------------------------------------------------------------------------

type guidePayload struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	TitleMax     int      `json:"title_max"`
	ContentMax   int      `json:"content_max"`
	MaxTags      int      `json:"max_tags"`
	LinksAllowed bool     `json:"links_allowed"`
	Guidance     []string `json:"guidance"`
}

type validationPayload struct {
	Valid    bool                       `json:"valid"`
	Problems []domain.ValidationProblem `json:"problems"`
}

func authedRequest(method, target string, body []byte) *http.Request {
	req := httptest.NewRequest(method, target, bytes.NewReader(body))
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("Authorization", "Bearer "+generateTestToken(uuid.New().String()))
	return req
}

func serve(t *testing.T, router http.Handler, req *http.Request) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func decodeInto(t *testing.T, rec *httptest.ResponseRecorder, target any) {
	t.Helper()
	if err := json.NewDecoder(rec.Body).Decode(target); err != nil {
		t.Fatalf("decode response: %v; body: %s", err, rec.Body.String())
	}
}

func validateBody(t *testing.T, payload map[string]any) []byte {
	t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal request: %v", err)
	}
	return body
}

// ---------------------------------------------------------------------------
// Tests: GET /api/v1/publish/platforms
// ---------------------------------------------------------------------------

func TestPublishHandler_Platforms(t *testing.T) {
	router := setupPublishRouter(&mockPublishService{})

	rec := serve(t, router, authedRequest(http.MethodGet, "/api/v1/publish/platforms", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
	}
	var guides []guidePayload
	decodeInto(t, rec, &guides)

	wantOrder := []string{"xiaohongshu", "wechat", "zhihu", "medium", "wordpress", "webhook"}
	if len(guides) != len(wantOrder) {
		t.Fatalf("got %d platforms, want %d: %+v", len(guides), len(wantOrder), guides)
	}
	for i, want := range wantOrder {
		g := guides[i]
		if g.ID != want {
			t.Errorf("platform %d = %q, want %q (the order is the client's contract)", i, g.ID, want)
		}
		if g.Name == "" {
			t.Errorf("%s: empty display name", g.ID)
		}
		if g.TitleMax <= 0 || g.ContentMax <= 0 {
			t.Errorf("%s: limits must be positive, got title %d / content %d", g.ID, g.TitleMax, g.ContentMax)
		}
		if len(g.Guidance) == 0 {
			t.Errorf("%s: no writing guidance, the composition step would have nothing to follow", g.ID)
		}
		for _, line := range g.Guidance {
			if strings.TrimSpace(line) == "" {
				t.Errorf("%s: blank guidance line", g.ID)
			}
		}
	}

	byID := map[string]guidePayload{}
	for _, g := range guides {
		byID[g.ID] = g
	}
	if got := byID["xiaohongshu"]; got.TitleMax != 20 || got.LinksAllowed {
		t.Errorf("xiaohongshu = %+v, want a 20-character title cap and no links", got)
	}
	if got := byID["wechat"]; !got.LinksAllowed {
		t.Errorf("wechat must allow links, got %+v", got)
	}
	if got := byID["medium"]; got.MaxTags != 5 {
		t.Errorf("medium max_tags = %d, want 5", got.MaxTags)
	}
}

func TestPublishHandler_Platforms_Unauthorized(t *testing.T) {
	router := setupPublishRouter(&mockPublishService{})

	rec := serve(t, router, httptest.NewRequest(http.MethodGet, "/api/v1/publish/platforms", nil))

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/publish/validate
// ---------------------------------------------------------------------------

func TestPublishHandler_Validate(t *testing.T) {
	t.Run("reports every blocking problem, then the advisory ones", func(t *testing.T) {
		svc := &mockPublishService{
			publishFn: func(ctx context.Context, uid uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
				t.Error("validate must never publish")
				return nil, nil
			},
		}
		router := setupPublishRouter(svc)
		body := validateBody(t, map[string]any{
			"platform": "xiaohongshu",
			"title":    strings.Repeat("标", 21),
			"content":  "看这里 https://example.com/a",
			"tags":     []string{strings.Repeat("长", 25)},
		})

		rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish/validate", body))

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
		}
		var resp validationPayload
		decodeInto(t, rec, &resp)

		if resp.Valid {
			t.Error("Valid = true, want false: an over-long title and a link both block publishing on xiaohongshu")
		}
		fields := map[string]int{}
		for _, p := range resp.Problems {
			if p.Message == "" {
				t.Errorf("problem on %q has no message", p.Field)
			}
			fields[p.Field+"/"+p.Severity]++
		}
		if fields["title/error"] != 1 {
			t.Errorf("want exactly one blocking title problem, got %+v", resp.Problems)
		}
		if fields["content/error"] != 1 {
			t.Errorf("want exactly one blocking link problem, got %+v", resp.Problems)
		}
		if fields["tags/warning"] != 1 {
			t.Errorf("want one advisory tag problem, got %+v", resp.Problems)
		}
		// Blocking findings come first so the client can stop at the first
		// warning when it only has room for errors.
		for i, p := range resp.Problems {
			if p.Severity == "warning" {
				for _, later := range resp.Problems[i:] {
					if later.Severity == "error" {
						t.Fatalf("an error follows a warning: %+v", resp.Problems)
					}
				}
			}
		}
	})

	t.Run("valid content passes", func(t *testing.T) {
		router := setupPublishRouter(&mockPublishService{})
		body := validateBody(t, map[string]any{
			"platform": "zhihu",
			"title":    "一个具体的问句",
			"content":  "先给结论，再给论证。参考 https://example.com/source",
			"tags":     []string{"笔记", "方法"},
		})

		rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish/validate", body))

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusOK, rec.Body.String())
		}
		var resp validationPayload
		decodeInto(t, rec, &resp)
		if !resp.Valid || len(resp.Problems) != 0 {
			t.Errorf("want valid with no problems, got %+v", resp)
		}
	})

	t.Run("a draft still being written is reported, not rejected", func(t *testing.T) {
		router := setupPublishRouter(&mockPublishService{})
		body := validateBody(t, map[string]any{"platform": "xiaohongshu"})

		rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish/validate", body))

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want %d (the editor calls this while typing); body: %s", rec.Code, http.StatusOK, rec.Body.String())
		}
		var resp validationPayload
		decodeInto(t, rec, &resp)
		if resp.Valid {
			t.Error("Valid = true for an empty draft, want false")
		}
		var sawTitle, sawContent bool
		for _, p := range resp.Problems {
			sawTitle = sawTitle || p.Field == "title"
			sawContent = sawContent || p.Field == "content"
		}
		if !sawTitle || !sawContent {
			t.Errorf("want a problem for both empty fields, got %+v", resp.Problems)
		}
	})

	t.Run("links are fine on a long-form platform", func(t *testing.T) {
		router := setupPublishRouter(&mockPublishService{})
		body := validateBody(t, map[string]any{
			"platform": "zhihu",
			"title":    "标题",
			"content":  "https://example.com",
		})
		var resp validationPayload
		decodeInto(t, serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish/validate", body)), &resp)
		if !resp.Valid {
			t.Errorf("zhihu allows links, got %+v", resp)
		}
	})

	t.Run("rejects an unknown platform", func(t *testing.T) {
		router := setupPublishRouter(&mockPublishService{isValidPlatformFn: func(string) bool { return false }})
		body := validateBody(t, map[string]any{"platform": "myspace", "title": "t", "content": "c"})

		rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish/validate", body))

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("rejects a missing platform", func(t *testing.T) {
		router := setupPublishRouter(&mockPublishService{})
		rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish/validate", validateBody(t, map[string]any{"title": "t"})))
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("unauthorized", func(t *testing.T) {
		router := setupPublishRouter(&mockPublishService{})
		rec := serve(t, router, httptest.NewRequest(http.MethodPost, "/api/v1/publish/validate", strings.NewReader("{}")))
		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})
}

// ---------------------------------------------------------------------------
// Tests: POST /api/v1/publish — the optional content_item_id
// ---------------------------------------------------------------------------

// Publishing from a note or a draft has no generated-content item to point
// at. Requiring one made every client publish fail before anything else was
// checked, which is why publishing had not worked from the app.
func TestPublishHandler_Publish_WithoutContentItemID(t *testing.T) {
	var got service.PublishRequest
	svc := &mockPublishService{
		publishFn: func(ctx context.Context, uid uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
			got = req
			return &domain.PublishLog{ID: uuid.New(), UserID: uid, Platform: req.Platform, Status: "pending"}, nil
		},
	}
	router := setupPublishRouter(svc)
	body := validateBody(t, map[string]any{
		"platform": "zhihu",
		"title":    "直接从笔记发布",
		"content":  "正文",
	})

	rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish", body))

	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusAccepted, rec.Body.String())
	}
	if got.ContentItemID != "" {
		t.Errorf("ContentItemID = %q, want it left empty", got.ContentItemID)
	}
}

func TestPublishHandler_Publish_MalformedContentItemID(t *testing.T) {
	router := setupPublishRouter(&mockPublishService{})
	body := validateBody(t, map[string]any{
		"platform":        "zhihu",
		"content_item_id": "not-a-uuid",
		"title":           "t",
		"content":         "c",
	})

	rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish", body))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

func TestPublishHandler_Publish_ReturnsFieldLevelProblems(t *testing.T) {
	router := setupPublishRouter(&mockPublishService{})
	body := validateBody(t, map[string]any{
		"platform": "xiaohongshu",
		"title":    strings.Repeat("标", 21),
		"content":  "正文",
	})

	rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish", body))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
	var resp struct {
		Error struct {
			Code     string                     `json:"code"`
			Message  string                     `json:"message"`
			Problems []domain.ValidationProblem `json:"problems"`
		} `json:"error"`
	}
	decodeInto(t, rec, &resp)
	if resp.Error.Code != "validation_error" {
		t.Errorf("code = %q, want validation_error", resp.Error.Code)
	}
	if len(resp.Error.Problems) != 1 || resp.Error.Problems[0].Field != "title" || resp.Error.Problems[0].Severity != "error" {
		t.Fatalf("want one blocking problem on the title, got %+v", resp.Error.Problems)
	}
	if !strings.Contains(resp.Error.Problems[0].Message, "21") {
		t.Errorf("the message should tell the user how long the title is, got %q", resp.Error.Problems[0].Message)
	}
}

func TestPublishHandler_Publish_AdvisoryProblemsRideAlong(t *testing.T) {
	svc := &mockPublishService{
		publishFn: func(ctx context.Context, uid uuid.UUID, req service.PublishRequest) (*domain.PublishLog, error) {
			return &domain.PublishLog{ID: uuid.New(), UserID: uid, Platform: req.Platform, Status: "pending"}, nil
		},
	}
	router := setupPublishRouter(svc)
	body := validateBody(t, map[string]any{
		"platform": "xiaohongshu",
		"title":    "标题",
		"content":  "正文",
		"tags":     []string{strings.Repeat("长", 25)},
	})

	rec := serve(t, router, authedRequest(http.MethodPost, "/api/v1/publish", body))

	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want %d (a warning must not block); body: %s", rec.Code, http.StatusAccepted, rec.Body.String())
	}
	var resp struct {
		Warnings []domain.ValidationProblem `json:"warnings"`
	}
	decodeInto(t, rec, &resp)
	if len(resp.Warnings) != 1 || resp.Warnings[0].Severity != "warning" {
		t.Errorf("want the advisory problem in the accepted response, got %+v", resp.Warnings)
	}
}
