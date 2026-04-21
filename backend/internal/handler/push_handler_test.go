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

	"github.com/anynote/backend/internal/domain"
	"github.com/anynote/backend/internal/service"
)

// ---------------------------------------------------------------------------
// Mock PushService
// ---------------------------------------------------------------------------

type mockPushService struct {
	registeredDevices []struct {
		userID, token, platform string
	}
	unregisteredEntries []struct {
		userID, token string
	}
	registerErr   error
	unregisterErr error
}

func (m *mockPushService) SendPush(ctx context.Context, userID string, payload service.PushPayload) error {
	return nil
}

func (m *mockPushService) RegisterDevice(ctx context.Context, userID string, token string, platform string) error {
	if m.registerErr != nil {
		return m.registerErr
	}
	m.registeredDevices = append(m.registeredDevices, struct {
		userID, token, platform string
	}{userID, token, platform})
	return nil
}

func (m *mockPushService) UnregisterDevice(ctx context.Context, userID string, token string) error {
	if m.unregisterErr != nil {
		return m.unregisterErr
	}
	m.unregisteredEntries = append(m.unregisteredEntries, struct {
		userID, token string
	}{userID, token})
	return nil
}

// ctxWithUserID creates a context with the user_id value set, simulating
// what AuthMiddleware does for authenticated requests.
func ctxWithUserID(userID string) context.Context {
	return context.WithValue(context.Background(), contextKey("user_id"), userID)
}

// ---------------------------------------------------------------------------
// RegisterDeviceToken tests
// ---------------------------------------------------------------------------

func TestRegisterDeviceToken_Success(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token":    "device-token-abc",
		"platform": "android",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/register", bytes.NewReader(body))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.RegisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	if len(mockSvc.registeredDevices) != 1 {
		t.Fatalf("registered %d devices, want 1", len(mockSvc.registeredDevices))
	}
	d := mockSvc.registeredDevices[0]
	if d.userID != "550e8400-e29b-41d4-a716-446655440000" {
		t.Errorf("userID = %q, want %q", d.userID, "550e8400-e29b-41d4-a716-446655440000")
	}
	if d.token != "device-token-abc" {
		t.Errorf("token = %q, want %q", d.token, "device-token-abc")
	}
	if d.platform != "android" {
		t.Errorf("platform = %q, want %q", d.platform, "android")
	}
}

func TestRegisterDeviceToken_NoAuth(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token":    "device-token",
		"platform": "ios",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/register", bytes.NewReader(body))
	// No user_id in context.
	w := httptest.NewRecorder()

	h.RegisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}

func TestRegisterDeviceToken_InvalidJSON(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/register", strings.NewReader("not-json"))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.RegisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(resp.Body).Decode(&errResp)
	if errResp.Error.Code != "invalid_request" {
		t.Errorf("error = %q, want %q", errResp.Error.Code, "invalid_request")
	}
}

func TestRegisterDeviceToken_EmptyToken(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token":    "",
		"platform": "android",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/register", bytes.NewReader(body))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.RegisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(resp.Body).Decode(&errResp)
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

func TestRegisterDeviceToken_EmptyPlatform(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token":    "valid-token",
		"platform": "",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/register", bytes.NewReader(body))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.RegisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}
}

func TestRegisterDeviceToken_InvalidPlatform(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token":    "valid-token",
		"platform": "windows",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/register", bytes.NewReader(body))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.RegisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(resp.Body).Decode(&errResp)
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

func TestRegisterDeviceToken_ValidPlatforms(t *testing.T) {
	for _, platform := range []string{"android", "ios", "web"} {
		t.Run(platform, func(t *testing.T) {
			mockSvc := &mockPushService{}
			h := &PushHandler{pushService: mockSvc}

			body, _ := json.Marshal(map[string]string{
				"token":    "token-" + platform,
				"platform": platform,
			})

			req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/register", bytes.NewReader(body))
			req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
			w := httptest.NewRecorder()

			h.RegisterDeviceToken(w, req)

			resp := w.Result()
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				t.Errorf("platform %q: status = %d, want %d", platform, resp.StatusCode, http.StatusOK)
			}
		})
	}
}

func TestRegisterDeviceToken_ServiceError(t *testing.T) {
	mockSvc := &mockPushService{registerErr: errors.New("db error")}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token":    "valid-token",
		"platform": "android",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/register", bytes.NewReader(body))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.RegisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusInternalServerError)
	}
}

// ---------------------------------------------------------------------------
// UnregisterDeviceToken tests
// ---------------------------------------------------------------------------

func TestUnregisterDeviceToken_Success(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token": "device-token-to-remove",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/unregister", bytes.NewReader(body))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.UnregisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	if len(mockSvc.unregisteredEntries) != 1 {
		t.Fatalf("unregistered %d entries, want 1", len(mockSvc.unregisteredEntries))
	}
	if mockSvc.unregisteredEntries[0].token != "device-token-to-remove" {
		t.Errorf("token = %q, want %q", mockSvc.unregisteredEntries[0].token, "device-token-to-remove")
	}
}

func TestUnregisterDeviceToken_NoAuth(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token": "some-token",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/unregister", bytes.NewReader(body))
	// No user_id in context.
	w := httptest.NewRecorder()

	h.UnregisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusUnauthorized)
	}
}

func TestUnregisterDeviceToken_InvalidJSON(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/unregister", strings.NewReader("not-json"))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.UnregisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}
}

func TestUnregisterDeviceToken_EmptyToken(t *testing.T) {
	mockSvc := &mockPushService{}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token": "",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/unregister", bytes.NewReader(body))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.UnregisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusBadRequest)
	}

	var errResp domain.ErrorResponse
	json.NewDecoder(resp.Body).Decode(&errResp)
	if errResp.Error.Code != "validation_error" {
		t.Errorf("error = %q, want %q", errResp.Error.Code, "validation_error")
	}
}

func TestUnregisterDeviceToken_ServiceError(t *testing.T) {
	mockSvc := &mockPushService{unregisterErr: errors.New("db error")}
	h := &PushHandler{pushService: mockSvc}

	body, _ := json.Marshal(map[string]string{
		"token": "valid-token",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/v1/devices/unregister", bytes.NewReader(body))
	req = req.WithContext(ctxWithUserID("550e8400-e29b-41d4-a716-446655440000"))
	w := httptest.NewRecorder()

	h.UnregisterDeviceToken(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusInternalServerError)
	}
}
