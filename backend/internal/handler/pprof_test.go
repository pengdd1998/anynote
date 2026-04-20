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
	// Ensure neither env var is set.
	os.Unsetenv("PPROF_ENABLED")
	os.Unsetenv("DEBUG")

	r := chi.NewRouter()
	registerPprofRoutes(r)

	// Pprof index should return 404 when not enabled.
	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("GET /debug/pprof/ without env: got %d, want %d", w.Code, http.StatusNotFound)
	}
}

func TestPprofRoutes_RegisteredWithPprofEnabled(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	registerPprofRoutes(r)

	pprofEndpoints := []struct {
		path        string
		description string
	}{
		{"/debug/pprof/", "index"},
		{"/debug/pprof/cmdline", "cmdline"},
		{"/debug/pprof/symbol", "symbol"},
	}

	for _, ep := range pprofEndpoints {
		t.Run(ep.description, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, ep.path, nil)
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)

			// Should not return 404 when pprof is enabled.
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
	registerPprofRoutes(r)

	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// Should not return 404 when DEBUG is set.
	if w.Code == http.StatusNotFound {
		t.Error("GET /debug/pprof/ returned 404 when DEBUG env is set")
	}
}

func TestPprofRoutes_ProfileEndpointRegistered(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	registerPprofRoutes(r)

	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/profile?seconds=1", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// The profile endpoint should be registered (not 404).
	// It may return 200 with profile data or another status, but not 404.
	if w.Code == http.StatusNotFound {
		t.Error("GET /debug/pprof/profile returned 404")
	}
}

func TestPprofRoutes_TraceEndpointRegistered(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	registerPprofRoutes(r)

	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/trace", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// The trace endpoint should be registered (not 404).
	if w.Code == http.StatusNotFound {
		t.Error("GET /debug/pprof/trace returned 404")
	}
}

func TestPprofRoutes_SymbolPostMethod(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	registerPprofRoutes(r)

	// The symbol endpoint also supports POST for resolving program counters.
	req := httptest.NewRequest(http.MethodPost, "/debug/pprof/symbol", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("POST /debug/pprof/symbol returned 404")
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
		"/debug/pprof/",
		"/debug/pprof/cmdline",
		"/debug/pprof/profile",
		"/debug/pprof/symbol",
		"/debug/pprof/trace",
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

	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("GET /debug/pprof/ returned 404 when PPROF_ENABLED is set")
	}
}

// ---------------------------------------------------------------------------
// Pprof content type verification
// ---------------------------------------------------------------------------

func TestPprofRoutes_ContentType(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	registerPprofRoutes(r)

	// The pprof index page serves HTML.
	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	ct := w.Header().Get("Content-Type")
	if ct == "" {
		t.Error("Content-Type header should not be empty for pprof index")
	}
	// net/http/pprof typically serves text/html for the index page.
	if !strings.Contains(ct, "text/html") {
		t.Errorf("Content-Type = %q, expected it to contain text/html", ct)
	}
}

func TestPprofRoutes_CmdlineContentType(t *testing.T) {
	os.Setenv("PPROF_ENABLED", "1")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	registerPprofRoutes(r)

	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/cmdline", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// cmdline should not return 404 and should have a non-empty content type.
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
	registerPprofRoutes(r)

	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code == http.StatusNotFound {
		t.Error("pprof should be registered when both env vars are set")
	}
}

func TestPprofRoutes_PprofEnabledEmptyString(t *testing.T) {
	// Empty string should still trigger registration (os.Getenv returns "" but
	// the check is != "" so empty string does NOT trigger).
	os.Unsetenv("DEBUG")
	os.Setenv("PPROF_ENABLED", "")
	defer os.Unsetenv("PPROF_ENABLED")

	r := chi.NewRouter()
	registerPprofRoutes(r)

	req := httptest.NewRequest(http.MethodGet, "/debug/pprof/", nil)
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

	// When PPROF_ENABLED is set, /debug/pprof/* routes should appear.
	expectedPatterns := []string{
		"GET /debug/pprof/",
		"GET /debug/pprof/cmdline",
		"GET /debug/pprof/profile",
		"GET /debug/pprof/symbol",
		"GET /debug/pprof/trace",
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

	// Health routes should still function normally.
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
