package handler

import (
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

// ---------------------------------------------------------------------------
// registerPprofRoutes tests
// ---------------------------------------------------------------------------

func TestPprofRoutes_NotRegisteredByDefault(t *testing.T) {
	os.Unsetenv("PPROF_ENABLED")
	os.Unsetenv("DEBUG")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("GET /api/v1/debug/pprof/ without env: got %d, want %d", w.Code, http.StatusNotFound)
	}
}

func TestPprofRoutes_RegisteredWithPprofEnabled(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	pprofEndpoints := []struct {
		path        string
		description string
	}{
		{"/api/v1/debug/pprof/", "index"},
		{"/api/v1/debug/pprof/cmdline", "cmdline"},
		{"/api/v1/debug/pprof/symbol", "symbol"},
	}

	for _, ep := range pprofEndpoints {
		t.Run(ep.description, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, ep.path, nil)
			req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)

			if w.Code == http.StatusNotFound {
				t.Errorf("GET %s returned 404 (pprof not registered)", ep.path)
			}
		})
	}
}

func TestPprofRoutes_RegisteredWithDebugEnv(t *testing.T) {
	os.Unsetenv("PPROF_ENABLED")
	os.Setenv("DEBUG", "true")
	defer os.Unsetenv("DEBUG")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("GET /api/v1/debug/pprof/ returned 404 when DEBUG env is set")
	}
}

func TestPprofRoutes_ProfileEndpointRegistered(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/profile?seconds=1", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("GET /api/v1/debug/pprof/profile returned 404")
	}
}

func TestPprofRoutes_TraceEndpointRegistered(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/trace", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("GET /api/v1/debug/pprof/trace returned 404")
	}
}

func TestPprofRoutes_SymbolPostMethod(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/debug/pprof/symbol", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("POST /api/v1/debug/pprof/symbol returned 404")
	}
}

// ---------------------------------------------------------------------------
// JWT authentication tests
// ---------------------------------------------------------------------------

// TestPprofRoutes_JWTRequired verifies that pprof endpoints reject requests
// without a JWT token and accept requests with a valid access token.
func TestPprofRoutes_JWTRequired(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	// Request without token should get 401.
	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("GET /api/v1/debug/pprof/ without token: got %d, want %d", w.Code, http.StatusUnauthorized)
	}

	// Request with valid access token should succeed.
	req = httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound || w.Code == http.StatusUnauthorized {
		t.Errorf("GET /api/v1/debug/pprof/ with valid token: got %d, expected success", w.Code)
	}
}

// TestPprofRoutes_InvalidTokenRejected verifies that pprof endpoints reject
// requests with an invalid JWT token.
func TestPprofRoutes_InvalidTokenRejected(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	req.Header.Set("Authorization", "Bearer invalid-token-value")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("GET /api/v1/debug/pprof/ with invalid token: got %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

// TestPprofRoutes_RefreshTokenRejected verifies that pprof endpoints reject
// requests using a refresh token instead of an access token.
func TestPprofRoutes_RefreshTokenRejected(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestRefreshToken("test-user"))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("GET /api/v1/debug/pprof/ with refresh token: got %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

// ---------------------------------------------------------------------------
// Pprof integration with full Router
// ---------------------------------------------------------------------------

func TestRouter_PprofNotRegisteredInProduction(t *testing.T) {
	os.Unsetenv("PPROF_ENABLED")
	os.Unsetenv("DEBUG")

	cfg, services, healthH := newTestRouterServices()
	router := Router(cfg, services, healthH)

	pprofPaths := []string{
		"/api/v1/debug/pprof/",
		"/api/v1/debug/pprof/cmdline",
		"/api/v1/debug/pprof/profile",
		"/api/v1/debug/pprof/symbol",
		"/api/v1/debug/pprof/trace",
	}

	for _, path := range pprofPaths {
		t.Run(path, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, path, nil)
			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)

			if w.Code != http.StatusNotFound {
				t.Errorf("GET %s without pprof env: got %d, want %d", path, w.Code, http.StatusNotFound)
			}
		})
	}
}

func TestRouter_PprofRegisteredWhenEnabled(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	cfg, services, healthH := newTestRouterServices()
	router := Router(cfg, services, healthH)

	// Without JWT: should get 401.
	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("GET /api/v1/debug/pprof/ without token: got %d, want %d", w.Code, http.StatusUnauthorized)
	}

	// With valid JWT: should succeed (not 404, not 401).
	req = httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("GET /api/v1/debug/pprof/ returned 404 when PPROF_ENABLED is set")
	}
	if w.Code == http.StatusUnauthorized {
		t.Error("GET /api/v1/debug/pprof/ returned 401 with valid JWT")
	}
}

// ---------------------------------------------------------------------------
// Pprof content type verification
// ---------------------------------------------------------------------------

func TestPprofRoutes_ContentType(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	ct := w.Header().Get("Content-Type")
	if ct == "" {
		t.Error("Content-Type header should not be empty for pprof index")
	}
	if !strings.Contains(ct, "text/html") {
		t.Errorf("Content-Type = %q, expected it to contain text/html", ct)
	}
}

func TestPprofRoutes_CmdlineContentType(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/cmdline", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Fatal("cmdline endpoint returned 404")
	}
	ct := w.Header().Get("Content-Type")
	if ct == "" {
		t.Error("Content-Type header should not be empty for cmdline endpoint")
	}
}

// ---------------------------------------------------------------------------
// Pprof env precedence
// ---------------------------------------------------------------------------

func TestPprofRoutes_BothEnvsSet(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	os.Setenv("DEBUG", "1")
	defer os.Unsetenv("PPROF_ENABLED")
	defer os.Unsetenv("DEBUG")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(testJWTSecret))
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken("test-user"))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("pprof should be registered when both env vars are set")
	}
}

func TestPprofRoutes_PprofEnabledEmptyString(t *testing.T) {
	os.Unsetenv("DEBUG")
	os.Setenv("PPROF_ENABLED", "")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	r.Route("/api/v1", func(r chi.Router) {
		registerPprofRoutes(r)
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/debug/pprof/", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Error("pprof should NOT be registered when PPROF_ENABLED is empty string")
	}
}

// ---------------------------------------------------------------------------
// Pprof route walk verification
// ---------------------------------------------------------------------------

func TestPprofRoutes_ChiWalk(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	cfg, services, healthH := newTestRouterServices()
	router := Router(cfg, services, healthH)

	chiRouter, ok := router.(chi.Routes)
	if !ok {
		t.Fatal("Router did not return a chi.Routes implementor")
	}

	routes := []string{}
	chi.Walk(chiRouter, func(method, route string, handler http.Handler, middlewares ...func(http.Handler) http.Handler) error {
		routes = append(routes, method+" "+route)
		return nil
	})

	expectedPatterns := []string{
		"GET /api/v1/debug/pprof/",
		"GET /api/v1/debug/pprof/cmdline",
		"GET /api/v1/debug/pprof/profile",
		"GET /api/v1/debug/pprof/symbol",
		"GET /api/v1/debug/pprof/trace",
	}

	for _, expected := range expectedPatterns {
		found := false
		for _, r := range routes {
			if r == expected {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("expected route %q not found in registered routes", expected)
		}
	}
}

func TestPprofRoutes_ChiWalkNotEnabled(t *testing.T) {
	os.Unsetenv("PPROF_ENABLED")
	os.Unsetenv("DEBUG")

	cfg, services, healthH := newTestRouterServices()
	router := Router(cfg, services, healthH)

	chiRouter, ok := router.(chi.Routes)
	if !ok {
		t.Fatal("Router did not return a chi.Routes implementor")
	}

	routes := []string{}
	chi.Walk(chiRouter, func(method, route string, handler http.Handler, middlewares ...func(http.Handler) http.Handler) error {
		routes = append(routes, method+" "+route)
		return nil
	})

	for _, r := range routes {
		if strings.Contains(r, "/debug/pprof") {
			t.Errorf("pprof route %q should not be registered when env vars not set", r)
		}
	}
}

// ---------------------------------------------------------------------------
// Config integration: verify other routes still work with pprof enabled
// ---------------------------------------------------------------------------

func TestRouter_HealthRoutesWorkWithPprofEnabled(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	cfg, services, healthH := newTestRouterServices()
	router := Router(cfg, services, healthH)

	routes := []struct {
		method string
		path   string
	}{
		{"GET", "/health"},
		{"GET", "/ready"},
		{"GET", "/metrics"},
	}

	for _, route := range routes {
		t.Run(route.method+" "+route.path, func(t *testing.T) {
			req := httptest.NewRequest(route.method, route.path, nil)
			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)

			if w.Code == http.StatusNotFound {
				t.Errorf("route %s %s returned 404", route.method, route.path)
			}
		})
	}
}
