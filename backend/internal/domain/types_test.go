package domain_test

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/anynote/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// Sentinel errors
// ---------------------------------------------------------------------------

func TestErrInvalidReaction_IsNonNil(t *testing.T) {
	t.Parallel()
	if domain.ErrInvalidReaction == nil {
		t.Error("ErrInvalidReaction should be non-nil")
	}
}

func TestErrInvalidReaction_Message(t *testing.T) {
	t.Parallel()
	want := "invalid reaction type"
	if got := domain.ErrInvalidReaction.Error(); got != want {
		t.Errorf("ErrInvalidReaction.Error() = %q, want %q", got, want)
	}
}

// ---------------------------------------------------------------------------
// Plan constants and ValidPlans
// ---------------------------------------------------------------------------

func TestPlanConstants(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name  string
		plan  domain.Plan
		value string
	}{
		{"free", domain.PlanFree, "free"},
		{"pro", domain.PlanPro, "pro"},
		{"lifetime", domain.PlanLifetime, "lifetime"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if string(tc.plan) != tc.value {
				t.Errorf("Plan = %q, want %q", tc.plan, tc.value)
			}
		})
	}
}

func TestValidPlans_ContainsAllPlans(t *testing.T) {
	t.Parallel()
	for _, p := range []domain.Plan{domain.PlanFree, domain.PlanPro, domain.PlanLifetime} {
		if !domain.ValidPlans[p] {
			t.Errorf("ValidPlans[%q] = false, want true", p)
		}
	}
}

func TestValidPlans_RejectsUnknown(t *testing.T) {
	t.Parallel()
	if domain.ValidPlans[domain.Plan("enterprise")] {
		t.Error("ValidPlans should be false for unknown plan")
	}
	if domain.ValidPlans[domain.Plan("")] {
		t.Error("ValidPlans should be false for empty plan")
	}
}

// ---------------------------------------------------------------------------
// GetPlanLimits
// ---------------------------------------------------------------------------

func TestGetPlanLimits_KnownPlans(t *testing.T) {
	t.Parallel()
	tests := []struct {
		plan       domain.Plan
		maxNotes   int
		maxColl    int
		aiQuota    int
		maxStorage int64
		maxDevices int
		collab     bool
		publish    bool
	}{
		{
			plan: domain.PlanFree, maxNotes: 500, maxColl: 20,
			aiQuota: 50, maxStorage: 100 * 1024 * 1024,
			maxDevices: 2, collab: false, publish: true,
		},
		{
			plan: domain.PlanPro, maxNotes: 10_000, maxColl: 100,
			aiQuota: 500, maxStorage: 5 * 1024 * 1024 * 1024,
			maxDevices: 5, collab: true, publish: true,
		},
		{
			plan: domain.PlanLifetime, maxNotes: -1, maxColl: -1,
			aiQuota: -1, maxStorage: -1,
			maxDevices: -1, collab: true, publish: true,
		},
	}
	for _, tc := range tests {
		t.Run(string(tc.plan), func(t *testing.T) {
			t.Parallel()
			got := domain.GetPlanLimits(tc.plan)
			assertPlanLimits(t, got, tc)
		})
	}
}

func TestGetPlanLimits_UnknownDefaultsToFree(t *testing.T) {
	t.Parallel()
	got := domain.GetPlanLimits(domain.Plan("unknown"))
	freeLimits := domain.PlanLimitsMap[domain.PlanFree]
	if got != freeLimits {
		t.Errorf("GetPlanLimits(unknown) = %+v, want %+v", got, freeLimits)
	}
}

func TestGetPlanLimits_EmptyDefaultsToFree(t *testing.T) {
	t.Parallel()
	got := domain.GetPlanLimits(domain.Plan(""))
	freeLimits := domain.PlanLimitsMap[domain.PlanFree]
	if got != freeLimits {
		t.Errorf("GetPlanLimits('') = %+v, want %+v", got, freeLimits)
	}
}

func assertPlanLimits(t *testing.T, got domain.PlanLimits, want struct {
	plan       domain.Plan
	maxNotes   int
	maxColl    int
	aiQuota    int
	maxStorage int64
	maxDevices int
	collab     bool
	publish    bool
}) {
	t.Helper()
	if got.MaxNotes != want.maxNotes {
		t.Errorf("MaxNotes = %d, want %d", got.MaxNotes, want.maxNotes)
	}
	if got.MaxCollections != want.maxColl {
		t.Errorf("MaxCollections = %d, want %d", got.MaxCollections, want.maxColl)
	}
	if got.AIDailyQuota != want.aiQuota {
		t.Errorf("AIDailyQuota = %d, want %d", got.AIDailyQuota, want.aiQuota)
	}
	if got.MaxStorageBytes != want.maxStorage {
		t.Errorf("MaxStorageBytes = %d, want %d", got.MaxStorageBytes, want.maxStorage)
	}
	if got.MaxDevices != want.maxDevices {
		t.Errorf("MaxDevices = %d, want %d", got.MaxDevices, want.maxDevices)
	}
	if got.CanCollaborate != want.collab {
		t.Errorf("CanCollaborate = %v, want %v", got.CanCollaborate, want.collab)
	}
	if got.CanPublish != want.publish {
		t.Errorf("CanPublish = %v, want %v", got.CanPublish, want.publish)
	}
}

// ---------------------------------------------------------------------------
// PlanLimitsMap completeness
// ---------------------------------------------------------------------------

func TestPlanLimitsMap_ContainsAllValidPlans(t *testing.T) {
	t.Parallel()
	for p := range domain.ValidPlans {
		if _, ok := domain.PlanLimitsMap[p]; !ok {
			t.Errorf("PlanLimitsMap missing entry for %q", p)
		}
	}
}

func TestPlanLimitsMap_LifetimeIsUnlimited(t *testing.T) {
	t.Parallel()
	lim := domain.PlanLimitsMap[domain.PlanLifetime]
	unlimitedFields := []struct {
		name  string
		value int
	}{
		{"MaxNotes", lim.MaxNotes},
		{"MaxCollections", lim.MaxCollections},
		{"AIDailyQuota", lim.AIDailyQuota},
	}
	for _, f := range unlimitedFields {
		if f.value != -1 {
			t.Errorf("Lifetime %s = %d, want -1 (unlimited)", f.name, f.value)
		}
	}
	if lim.MaxStorageBytes != -1 {
		t.Errorf("Lifetime MaxStorageBytes = %d, want -1 (unlimited)", lim.MaxStorageBytes)
	}
	if lim.MaxDevices != -1 {
		t.Errorf("Lifetime MaxDevices = %d, want -1 (unlimited)", lim.MaxDevices)
	}
}

func TestPlanLimitsMap_FreePlanHasNoCollaboration(t *testing.T) {
	t.Parallel()
	lim := domain.PlanLimitsMap[domain.PlanFree]
	if lim.CanCollaborate {
		t.Error("Free plan CanCollaborate should be false")
	}
}

func TestPlanLimitsMap_ProAndLifetimeCanCollaborate(t *testing.T) {
	t.Parallel()
	for _, p := range []domain.Plan{domain.PlanPro, domain.PlanLifetime} {
		lim := domain.PlanLimitsMap[p]
		if !lim.CanCollaborate {
			t.Errorf("%s plan CanCollaborate should be true", p)
		}
	}
}

func TestPlanLimitsMap_AllPlansCanPublish(t *testing.T) {
	t.Parallel()
	for p, lim := range domain.PlanLimitsMap {
		if !lim.CanPublish {
			t.Errorf("%s plan CanPublish should be true", p)
		}
	}
}

// ---------------------------------------------------------------------------
// PlanLimits JSON serialization
// ---------------------------------------------------------------------------

func TestPlanLimits_JSONRoundTrip(t *testing.T) {
	t.Parallel()
	original := domain.PlanLimits{
		MaxNotes:        500,
		MaxCollections:  20,
		AIDailyQuota:    50,
		MaxStorageBytes: 104857600,
		MaxDevices:      2,
		CanCollaborate:  false,
		CanPublish:      true,
	}

	data, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.PlanLimits
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded != original {
		t.Errorf("round-trip mismatch: got %+v, want %+v", decoded, original)
	}
}

// ---------------------------------------------------------------------------
// Struct zero-value and field tests
// ---------------------------------------------------------------------------

func TestUser_ZeroValue(t *testing.T) {
	t.Parallel()
	var u domain.User
	if u.ID != (uuid.UUID{}) {
		t.Error("zero User.ID should be nil UUID")
	}
	if u.Email != "" {
		t.Error("zero User.Email should be empty")
	}
	if u.Plan != "" {
		t.Error("zero User.Plan should be empty")
	}
}

func TestSyncBlob_ZeroValue(t *testing.T) {
	t.Parallel()
	var b domain.SyncBlob
	if b.Version != 0 {
		t.Error("zero SyncBlob.Version should be 0")
	}
	if b.BlobSize != 0 {
		t.Error("zero SyncBlob.BlobSize should be 0")
	}
	if b.EncryptedData != nil {
		t.Error("zero SyncBlob.EncryptedData should be nil")
	}
}

func TestLLMConfig_ZeroValue(t *testing.T) {
	t.Parallel()
	var c domain.LLMConfig
	if c.Temperature != 0 {
		t.Error("zero LLMConfig.Temperature should be 0")
	}
	if c.IsDefault {
		t.Error("zero LLMConfig.IsDefault should be false")
	}
	if c.DecryptedKey != "" {
		t.Error("zero LLMConfig.DecryptedKey should be empty")
	}
	if c.EncryptedKey != nil {
		t.Error("zero LLMConfig.EncryptedKey should be nil")
	}
}

func TestPlatformConnection_NilableTime(t *testing.T) {
	t.Parallel()
	var pc domain.PlatformConnection
	if pc.LastVerified != nil {
		t.Error("zero PlatformConnection.LastVerified should be nil")
	}
}

func TestPublishLog_NilableFields(t *testing.T) {
	t.Parallel()
	var pl domain.PublishLog
	if pl.PlatformConnID != nil {
		t.Error("zero PublishLog.PlatformConnID should be nil")
	}
	if pl.ContentItemID != nil {
		t.Error("zero PublishLog.ContentItemID should be nil")
	}
	if pl.PublishedAt != nil {
		t.Error("zero PublishLog.PublishedAt should be nil")
	}
}

// ---------------------------------------------------------------------------
// JSON tag tests for key types
// ---------------------------------------------------------------------------

func TestAuthResponse_JSONFields(t *testing.T) {
	t.Parallel()
	now := time.Now().Truncate(time.Millisecond).UTC()
	resp := domain.AuthResponse{
		AccessToken:  "at-123",
		RefreshToken: "rt-456",
		ExpiresAt:    now,
		User: domain.User{
			ID:       uuid.New(),
			Email:    "test@example.com",
			Username: "tester",
			Plan:     "free",
		},
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	// Verify top-level fields exist with correct JSON keys.
	assertMapKey(t, parsed, "access_token")
	assertMapKey(t, parsed, "refresh_token")
	assertMapKey(t, parsed, "expires_at")
	assertMapKey(t, parsed, "user")

	// Verify User sub-object has expected keys.
	userObj, ok := parsed["user"].(map[string]interface{})
	if !ok {
		t.Fatal("user field is not an object")
	}
	assertMapKey(t, userObj, "id")
	assertMapKey(t, userObj, "email")
	assertMapKey(t, userObj, "username")
	assertMapKey(t, userObj, "plan")

	// AuthKeyHash and Salt should be omitted (json:"-").
	if _, exists := userObj["auth_key_hash"]; exists {
		t.Error("user.auth_key_hash should be omitted (json:\"-\")")
	}
	if _, exists := userObj["salt"]; exists {
		t.Error("user.salt should be omitted (json:\"-\")")
	}
}

func TestRegisterRequest_JSONFields(t *testing.T) {
	t.Parallel()
	req := domain.RegisterRequest{
		Email:        "a@b.com",
		Username:     "user1",
		AuthKeyHash:  []byte{1, 2, 3},
		Salt:         []byte{4, 5, 6},
		RecoveryKey:  []byte{7, 8, 9},
		RecoverySalt: []byte{10, 11, 12},
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	// Base64-encoded byte fields should be present.
	assertMapKey(t, parsed, "email")
	assertMapKey(t, parsed, "username")
	assertMapKey(t, parsed, "auth_key_hash")
	assertMapKey(t, parsed, "salt")
	assertMapKey(t, parsed, "recovery_key")
	assertMapKey(t, parsed, "recovery_salt")
}

func TestLLMConfig_SensitiveFieldsOmitted(t *testing.T) {
	t.Parallel()
	cfg := domain.LLMConfig{
		ID:           uuid.New(),
		UserID:       uuid.New(),
		Name:         "test-config",
		Provider:     "openai",
		EncryptedKey: []byte{1, 2, 3},
		DecryptedKey: "sk-secret-key",
		Model:        "gpt-4",
	}

	data, err := json.Marshal(cfg)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	// EncryptedKey and DecryptedKey use json:"-" and must not appear.
	if _, exists := parsed["encrypted_key"]; exists {
		t.Error("encrypted_key should be omitted (json:\"-\")")
	}
	if _, exists := parsed["decrypted_key"]; exists {
		t.Error("decrypted_key should be omitted (json:\"-\")")
	}

	// Regular fields should be present.
	assertMapKey(t, parsed, "id")
	assertMapKey(t, parsed, "name")
	assertMapKey(t, parsed, "provider")
	assertMapKey(t, parsed, "model")
}

func TestPlatformConnection_EncryptedAuthOmitted(t *testing.T) {
	t.Parallel()
	pc := domain.PlatformConnection{
		ID:            uuid.New(),
		UserID:        uuid.New(),
		Platform:      "xiaohongshu",
		EncryptedAuth: []byte{0xAA, 0xBB},
		Status:        "active",
	}

	data, err := json.Marshal(pc)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	if _, exists := parsed["encrypted_auth"]; exists {
		t.Error("encrypted_auth should be omitted (json:\"-\")")
	}
	assertMapKey(t, parsed, "platform")
	assertMapKey(t, parsed, "status")
}

func TestSharedNote_SensitiveFieldsOmitted(t *testing.T) {
	t.Parallel()
	note := domain.SharedNote{
		ID:           "abc123",
		ShareKeyHash: "hash-value",
		CreatedBy:    uuid.New(),
	}

	data, err := json.Marshal(note)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	if _, exists := parsed["share_key_hash"]; exists {
		t.Error("share_key_hash should be omitted (json:\"-\")")
	}
	if _, exists := parsed["created_by"]; exists {
		t.Error("created_by should be omitted (json:\"-\")")
	}
	assertMapKey(t, parsed, "id")
}

func TestGetShareResponse_ShareKeyHashOmitted(t *testing.T) {
	t.Parallel()
	resp := domain.GetShareResponse{
		ID:           "abc123",
		ShareKeyHash: "hash-value",
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	if _, exists := parsed["share_key_hash"]; exists {
		t.Error("share_key_hash should be omitted (json:\"-\")")
	}
}

// ---------------------------------------------------------------------------
// Sync types JSON tests
// ---------------------------------------------------------------------------

func TestSyncPullResponse_HasMoreFalse(t *testing.T) {
	t.Parallel()
	resp := domain.SyncPullResponse{
		Blobs:         []domain.SyncBlob{},
		LatestVersion: 42,
		HasMore:       false,
		NextCursor:    0,
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.SyncPullResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.LatestVersion != 42 {
		t.Errorf("LatestVersion = %d, want 42", decoded.LatestVersion)
	}
}

func TestSyncPushResponse_EmptyAccepted(t *testing.T) {
	t.Parallel()
	resp := domain.SyncPushResponse{
		Accepted:  []uuid.UUID{},
		Conflicts: nil,
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.SyncPushResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if len(decoded.Accepted) != 0 {
		t.Errorf("Accepted = %d items, want 0", len(decoded.Accepted))
	}
}

func TestSyncConflict_Fields(t *testing.T) {
	t.Parallel()
	c := domain.SyncConflict{
		ItemID:        uuid.New(),
		ItemType:      "note",
		ServerVersion: 10,
		ClientVersion: 8,
	}

	data, err := json.Marshal(c)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.SyncConflict
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.ItemType != "note" {
		t.Errorf("ItemType = %q, want %q", decoded.ItemType, "note")
	}
	if decoded.ServerVersion != 10 {
		t.Errorf("ServerVersion = %d, want 10", decoded.ServerVersion)
	}
	if decoded.ClientVersion != 8 {
		t.Errorf("ClientVersion = %d, want 8", decoded.ClientVersion)
	}
}

func TestBatchUpsertResult_ErrorFieldOmitted(t *testing.T) {
	t.Parallel()
	r := domain.BatchUpsertResult{
		ItemID:        uuid.New(),
		ItemType:      "note",
		ClientVersion: 5,
		Accepted:      true,
		ServerVersion: 6,
		Error:         nil,
	}

	data, err := json.Marshal(r)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	// Error field uses json:"-" so it should never appear in output.
	if _, exists := parsed["error"]; exists {
		t.Error("error field should be omitted (json:\"-\")")
	}
}

// ---------------------------------------------------------------------------
// Error response types
// ---------------------------------------------------------------------------

func TestErrorResponse_JSONStructure(t *testing.T) {
	t.Parallel()
	resp := domain.ErrorResponse{
		Error: domain.ErrorDetail{
			Code:    "forbidden",
			Message: "access denied",
		},
		RequestID: "req-001",
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	errObj, ok := parsed["error"].(map[string]interface{})
	if !ok {
		t.Fatal("error field should be an object")
	}
	if errObj["code"] != "forbidden" {
		t.Errorf("error.code = %v, want %q", errObj["code"], "forbidden")
	}
	if errObj["message"] != "access denied" {
		t.Errorf("error.message = %v, want %q", errObj["message"], "access denied")
	}
	if parsed["request_id"] != "req-001" {
		t.Errorf("request_id = %v, want %q", parsed["request_id"], "req-001")
	}
}

func TestErrorResponse_RequestIDOptional(t *testing.T) {
	t.Parallel()
	resp := domain.ErrorResponse{
		Error: domain.ErrorDetail{Code: "not_found", Message: "missing"},
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	// RequestID is omitempty; should not appear when empty.
	if _, exists := parsed["request_id"]; exists {
		t.Error("request_id should be omitted when empty")
	}
}

func TestQuotaExceededResponse_JSON(t *testing.T) {
	t.Parallel()
	resp := domain.QuotaExceededResponse{
		Error:         "quota_exceeded",
		RetryAfter:    3600,
		QueuePosition: 5,
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.QuotaExceededResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Error != "quota_exceeded" {
		t.Errorf("Error = %q, want %q", decoded.Error, "quota_exceeded")
	}
	if decoded.RetryAfter != 3600 {
		t.Errorf("RetryAfter = %d, want 3600", decoded.RetryAfter)
	}
}

func TestQuotaExceededResponse_QueuePositionOptional(t *testing.T) {
	t.Parallel()
	resp := domain.QuotaExceededResponse{
		Error:      "quota_exceeded",
		RetryAfter: 60,
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	if _, exists := parsed["queue_position"]; exists {
		t.Error("queue_position should be omitted when zero")
	}
}

// ---------------------------------------------------------------------------
// Share and reaction types
// ---------------------------------------------------------------------------

func TestCreateShareRequest_OmitemptyFields(t *testing.T) {
	t.Parallel()
	req := domain.CreateShareRequest{
		EncryptedContent: "enc-content",
		EncryptedTitle:   "enc-title",
		ShareKeyHash:     "hash",
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	// Optional fields should be omitted.
	if _, exists := parsed["is_public"]; exists {
		t.Error("is_public should be omitted when nil")
	}
	if _, exists := parsed["expires_hours"]; exists {
		t.Error("expires_hours should be omitted when nil")
	}
	if _, exists := parsed["max_views"]; exists {
		t.Error("max_views should be omitted when nil")
	}

	// Required fields should be present.
	assertMapKey(t, parsed, "encrypted_content")
	assertMapKey(t, parsed, "encrypted_title")
	assertMapKey(t, parsed, "share_key_hash")
}

func TestReactRequest_JSON(t *testing.T) {
	t.Parallel()
	req := domain.ReactRequest{ReactionType: "heart"}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.ReactRequest
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.ReactionType != "heart" {
		t.Errorf("ReactionType = %q, want %q", decoded.ReactionType, "heart")
	}
}

func TestReactResponse_JSON(t *testing.T) {
	t.Parallel()
	resp := domain.ReactResponse{
		ReactionType: "bookmark",
		Active:       false,
		Count:        12,
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.ReactResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Active {
		t.Error("Active should be false")
	}
	if decoded.Count != 12 {
		t.Errorf("Count = %d, want 12", decoded.Count)
	}
}

// ---------------------------------------------------------------------------
// Comment types
// ---------------------------------------------------------------------------

func TestCreateCommentRequest_OptionalParentID(t *testing.T) {
	t.Parallel()
	req := domain.CreateCommentRequest{
		EncryptedContent: "enc-comment",
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	if _, exists := parsed["parent_id"]; exists {
		t.Error("parent_id should be omitted when empty")
	}
}

func TestComment_NilableParentID(t *testing.T) {
	t.Parallel()
	now := time.Now()
	c := domain.Comment{
		ID:               uuid.New(),
		SharedNoteID:     "note-1",
		UserID:           uuid.New(),
		EncryptedContent: "enc",
		ParentID:         nil,
		CreatedAt:        now,
		UpdatedAt:        now,
	}

	if c.ParentID != nil {
		t.Error("ParentID should be nil for top-level comment")
	}
}

// ---------------------------------------------------------------------------
// Note link types
// ---------------------------------------------------------------------------

func TestNoteLinkItem_JSONRoundTrip(t *testing.T) {
	t.Parallel()
	src := uuid.New()
	tgt := uuid.New()
	item := domain.NoteLinkItem{
		SourceID: src,
		TargetID: tgt,
		LinkType: "reference",
	}

	data, err := json.Marshal(item)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.NoteLinkItem
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.SourceID != src {
		t.Errorf("SourceID = %v, want %v", decoded.SourceID, src)
	}
	if decoded.TargetID != tgt {
		t.Errorf("TargetID = %v, want %v", decoded.TargetID, tgt)
	}
	if decoded.LinkType != "reference" {
		t.Errorf("LinkType = %q, want %q", decoded.LinkType, "reference")
	}
}

func TestNoteGraphResponse_EmptyArrays(t *testing.T) {
	t.Parallel()
	resp := domain.NoteGraphResponse{
		Nodes: []domain.NoteGraphNode{},
		Edges: []domain.NoteLink{},
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.NoteGraphResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if len(decoded.Nodes) != 0 {
		t.Errorf("Nodes = %d items, want 0", len(decoded.Nodes))
	}
	if len(decoded.Edges) != 0 {
		t.Errorf("Edges = %d items, want 0", len(decoded.Edges))
	}
}

// ---------------------------------------------------------------------------
// AI types
// ---------------------------------------------------------------------------

func TestAIProxyRequest_StreamField(t *testing.T) {
	t.Parallel()
	req := domain.AIProxyRequest{
		Messages: []domain.ChatMessage{
			{Role: "user", Content: "hello"},
			{Role: "assistant", Content: "hi"},
		},
		Stream: true,
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.AIProxyRequest
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if !decoded.Stream {
		t.Error("Stream should be true")
	}
	if len(decoded.Messages) != 2 {
		t.Fatalf("Messages len = %d, want 2", len(decoded.Messages))
	}
	if decoded.Messages[0].Role != "user" {
		t.Errorf("Messages[0].Role = %q, want %q", decoded.Messages[0].Role, "user")
	}
}

func TestStreamChunk_DoneField(t *testing.T) {
	t.Parallel()
	chunk := domain.StreamChunk{
		Content: "partial",
		Done:    false,
	}

	data, err := json.Marshal(chunk)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.StreamChunk
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Done {
		t.Error("Done should be false")
	}
	if decoded.Content != "partial" {
		t.Errorf("Content = %q, want %q", decoded.Content, "partial")
	}
}

func TestStreamChunk_DoneWithContent(t *testing.T) {
	t.Parallel()
	chunk := domain.StreamChunk{
		Content: "",
		Done:    true,
	}

	data, err := json.Marshal(chunk)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.StreamChunk
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if !decoded.Done {
		t.Error("Done should be true")
	}
}

func TestStreamChunk_WithErrorMessage(t *testing.T) {
	t.Parallel()
	chunk := domain.StreamChunk{
		Error: "rate limited",
		Done:  true,
	}

	data, err := json.Marshal(chunk)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.StreamChunk
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Error != "rate limited" {
		t.Errorf("Error = %q, want %q", decoded.Error, "rate limited")
	}
}

func TestAIAgentRequest_JSON(t *testing.T) {
	t.Parallel()
	noteID := uuid.New()
	req := domain.AIAgentRequest{
		Action:  "summarize",
		Context: map[string]interface{}{"language": "en"},
		NoteIDs: []uuid.UUID{noteID},
		Parameters: map[string]interface{}{
			"max_length": 500,
		},
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.AIAgentRequest
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Action != "summarize" {
		t.Errorf("Action = %q, want %q", decoded.Action, "summarize")
	}
	if len(decoded.NoteIDs) != 1 {
		t.Errorf("NoteIDs len = %d, want 1", len(decoded.NoteIDs))
	}
}

func TestAIAgentResponse_JSON(t *testing.T) {
	t.Parallel()
	resp := domain.AIAgentResponse{
		Action:  "translate",
		Status:  "completed",
		Result:  map[string]interface{}{"translated": "bonjour"},
		Message: "Translation complete",
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.AIAgentResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Status != "completed" {
		t.Errorf("Status = %q, want %q", decoded.Status, "completed")
	}
}

// ---------------------------------------------------------------------------
// Batch delete types
// ---------------------------------------------------------------------------

func TestBatchDeleteRequest_JSON(t *testing.T) {
	t.Parallel()
	ids := []uuid.UUID{uuid.New(), uuid.New()}
	req := domain.BatchDeleteRequest{ItemIDs: ids}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.BatchDeleteRequest
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if len(decoded.ItemIDs) != 2 {
		t.Errorf("ItemIDs len = %d, want 2", len(decoded.ItemIDs))
	}
}

func TestBatchDeleteResponse_JSON(t *testing.T) {
	t.Parallel()
	resp := domain.BatchDeleteResponse{Deleted: 5}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.BatchDeleteResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Deleted != 5 {
		t.Errorf("Deleted = %d, want 5", decoded.Deleted)
	}
}

// ---------------------------------------------------------------------------
// Sync operation log and stats
// ---------------------------------------------------------------------------

func TestSyncOperationLog_Fields(t *testing.T) {
	t.Parallel()
	now := time.Now().UTC()
	log := domain.SyncOperationLog{
		ID:            uuid.New(),
		UserID:        uuid.New(),
		OperationType: "push",
		ItemType:      "note",
		ItemID:        uuid.New(),
		Version:       42,
		CreatedAt:     now,
	}

	if log.OperationType != "push" {
		t.Errorf("OperationType = %q, want %q", log.OperationType, "push")
	}
	if log.Version != 42 {
		t.Errorf("Version = %d, want 42", log.Version)
	}
}

func TestSyncStatsResponse_ItemsByType(t *testing.T) {
	t.Parallel()
	resp := domain.SyncStatsResponse{
		TotalItems: 100,
		ItemsByType: map[string]int{
			"note":       60,
			"tag":        20,
			"collection": 15,
			"content":    5,
		},
		TotalConflicts: 3,
	}

	total := 0
	for _, count := range resp.ItemsByType {
		total += count
	}
	if total != resp.TotalItems {
		t.Errorf("sum of ItemsByType = %d, TotalItems = %d", total, resp.TotalItems)
	}
}

func TestSyncProgressResponse_JSON(t *testing.T) {
	t.Parallel()
	resp := domain.SyncProgressResponse{
		TotalItems:    500,
		LatestVersion: 1234,
		HealthStatus:  "ok",
		PushCount24h:  50,
		PullCount24h:  30,
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.SyncProgressResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.HealthStatus != "ok" {
		t.Errorf("HealthStatus = %q, want %q", decoded.HealthStatus, "ok")
	}
	if decoded.PushCount24h != 50 {
		t.Errorf("PushCount24h = %d, want 50", decoded.PushCount24h)
	}
}

// ---------------------------------------------------------------------------
// Upgrade plan request
// ---------------------------------------------------------------------------

func TestUpgradePlanRequest_JSON(t *testing.T) {
	t.Parallel()
	req := domain.UpgradePlanRequest{
		Plan:       domain.PlanPro,
		PaymentRef: "pay-123",
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.UpgradePlanRequest
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Plan != domain.PlanPro {
		t.Errorf("Plan = %q, want %q", decoded.Plan, domain.PlanPro)
	}
}

func TestUpgradePlanRequest_PaymentRefOptional(t *testing.T) {
	t.Parallel()
	req := domain.UpgradePlanRequest{
		Plan: domain.PlanLifetime,
	}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	if _, exists := parsed["payment_ref"]; exists {
		t.Error("payment_ref should be omitted when empty")
	}
}

// ---------------------------------------------------------------------------
// Plan type string conversion
// ---------------------------------------------------------------------------

func TestPlan_StringConversion(t *testing.T) {
	t.Parallel()
	p := domain.Plan("custom")
	if string(p) != "custom" {
		t.Errorf("string(Plan) = %q, want %q", string(p), "custom")
	}
}

// ---------------------------------------------------------------------------
// Discover feed item
// ---------------------------------------------------------------------------

func TestDiscoverFeedItem_JSONRoundTrip(t *testing.T) {
	t.Parallel()
	now := time.Now().Truncate(time.Millisecond).UTC()
	item := domain.DiscoverFeedItem{
		ID:             "share-1",
		EncryptedTitle: "enc-title",
		HasPassword:    false,
		ViewCount:      100,
		ReactionHeart:  42,
		ReactionBookmark: 10,
		CreatedAt:      now,
	}

	data, err := json.Marshal(item)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.DiscoverFeedItem
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.ViewCount != 100 {
		t.Errorf("ViewCount = %d, want 100", decoded.ViewCount)
	}
	if decoded.ReactionHeart != 42 {
		t.Errorf("ReactionHeart = %d, want 42", decoded.ReactionHeart)
	}
	if decoded.ReactionBookmark != 10 {
		t.Errorf("ReactionBookmark = %d, want 10", decoded.ReactionBookmark)
	}
}

// ---------------------------------------------------------------------------
// PublicProfile
// ---------------------------------------------------------------------------

func TestPublicProfile_JSONRoundTrip(t *testing.T) {
	t.Parallel()
	profile := domain.PublicProfile{
		Username:      "johndoe",
		DisplayName:   "John Doe",
		Bio:           "Note enthusiast",
		Plan:          "pro",
		PublicEnabled: true,
	}

	data, err := json.Marshal(profile)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.PublicProfile
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Username != "johndoe" {
		t.Errorf("Username = %q, want %q", decoded.Username, "johndoe")
	}
	if !decoded.PublicEnabled {
		t.Error("PublicEnabled should be true")
	}
}

// ---------------------------------------------------------------------------
// AuthStartResult
// ---------------------------------------------------------------------------

func TestAuthStartResult_QRCodePNG_Omitted(t *testing.T) {
	t.Parallel()
	result := domain.AuthStartResult{
		QRCodePNG: []byte{0x89, 0x50, 0x4E, 0x47},
		AuthRef:   "ref-123",
		Status:    "qr_ready",
	}

	data, err := json.Marshal(result)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	// QRCodePNG uses json:"-" and must not appear.
	if _, exists := parsed["qr_code_png"]; exists {
		t.Error("qr_code_png should be omitted (json:\"-\")")
	}

	assertMapKey(t, parsed, "auth_ref")
	assertMapKey(t, parsed, "status")
}

func TestAuthStartResult_ExtraOptional(t *testing.T) {
	t.Parallel()
	result := domain.AuthStartResult{
		AuthRef: "ref-456",
		Status:  "done",
		Extra:   nil,
	}

	data, err := json.Marshal(result)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}

	if _, exists := parsed["extra"]; exists {
		t.Error("extra should be omitted when nil")
	}
}

// ---------------------------------------------------------------------------
// PlanInfo
// ---------------------------------------------------------------------------

func TestPlanInfo_JSONRoundTrip(t *testing.T) {
	t.Parallel()
	info := domain.PlanInfo{
		Plan: domain.PlanPro,
		Limits: domain.PlanLimits{
			MaxNotes:        10_000,
			MaxCollections:  100,
			AIDailyQuota:    500,
			MaxStorageBytes: 5 * 1024 * 1024 * 1024,
			MaxDevices:      5,
			CanCollaborate:  true,
			CanPublish:      true,
		},
		AIDailyUsed:  42,
		StorageBytes: 1024 * 1024,
		NoteCount:    250,
	}

	data, err := json.Marshal(info)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.PlanInfo
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Plan != domain.PlanPro {
		t.Errorf("Plan = %q, want %q", decoded.Plan, domain.PlanPro)
	}
	if decoded.AIDailyUsed != 42 {
		t.Errorf("AIDailyUsed = %d, want 42", decoded.AIDailyUsed)
	}
	if decoded.NoteCount != 250 {
		t.Errorf("NoteCount = %d, want 250", decoded.NoteCount)
	}
	if decoded.Limits.MaxNotes != 10_000 {
		t.Errorf("Limits.MaxNotes = %d, want 10000", decoded.Limits.MaxNotes)
	}
}

// ---------------------------------------------------------------------------
// RecoverySaltResponse
// ---------------------------------------------------------------------------

func TestRecoverySaltResponse_NilRecoverySalt(t *testing.T) {
	t.Parallel()
	resp := domain.RecoverySaltResponse{RecoverySalt: nil}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.RecoverySaltResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.RecoverySalt != nil {
		t.Error("RecoverySalt should remain nil for legacy accounts")
	}
}

// ---------------------------------------------------------------------------
// Tag listing
// ---------------------------------------------------------------------------

func TestListTagsResponse_EmptyTags(t *testing.T) {
	t.Parallel()
	resp := domain.ListTagsResponse{Tags: []domain.TagListItem{}}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.ListTagsResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if len(decoded.Tags) != 0 {
		t.Errorf("Tags len = %d, want 0", len(decoded.Tags))
	}
}

// ---------------------------------------------------------------------------
// SharedNote expiry
// ---------------------------------------------------------------------------

func TestSharedNote_ExpiresAt(t *testing.T) {
	t.Parallel()
	future := time.Now().Add(24 * time.Hour).UTC()
	note := domain.SharedNote{
		ID:        "exp-1",
		ExpiresAt: &future,
		MaxViews:  intPtr(100),
	}

	if note.ExpiresAt == nil {
		t.Fatal("ExpiresAt should not be nil")
	}
	if note.MaxViews == nil {
		t.Fatal("MaxViews should not be nil")
	}
	if *note.MaxViews != 100 {
		t.Errorf("MaxViews = %d, want 100", *note.MaxViews)
	}
}

func TestSharedNote_NoExpiry(t *testing.T) {
	t.Parallel()
	note := domain.SharedNote{
		ID:        "permanent-1",
		ExpiresAt: nil,
		MaxViews:  nil,
	}

	if note.ExpiresAt != nil {
		t.Error("ExpiresAt should be nil for permanent notes")
	}
	if note.MaxViews != nil {
		t.Error("MaxViews should be nil when no limit")
	}
}

// ---------------------------------------------------------------------------
// ListCommentsResponse
// ---------------------------------------------------------------------------

func TestListCommentsResponse_JSON(t *testing.T) {
	t.Parallel()
	resp := domain.ListCommentsResponse{
		Comments: []domain.Comment{},
		Total:    0,
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.ListCommentsResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.Total != 0 {
		t.Errorf("Total = %d, want 0", decoded.Total)
	}
}

// ---------------------------------------------------------------------------
// CreateNoteLinksRequest
// ---------------------------------------------------------------------------

func TestCreateNoteLinksRequest_EmptyLinks(t *testing.T) {
	t.Parallel()
	req := domain.CreateNoteLinksRequest{Links: []domain.NoteLinkItem{}}

	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.CreateNoteLinksRequest
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if len(decoded.Links) != 0 {
		t.Errorf("Links len = %d, want 0", len(decoded.Links))
	}
}

// ---------------------------------------------------------------------------
// SyncStatusSummary (repository-level type)
// ---------------------------------------------------------------------------

func TestSyncStatusSummary_Fields(t *testing.T) {
	t.Parallel()
	now := time.Now().UTC()
	summary := domain.SyncStatusSummary{
		LatestVersion: 999,
		TotalItems:    500,
		LastUpdated:   now,
	}

	if summary.LatestVersion != 999 {
		t.Errorf("LatestVersion = %d, want 999", summary.LatestVersion)
	}
	if summary.TotalItems != 500 {
		t.Errorf("TotalItems = %d, want 500", summary.TotalItems)
	}
}

// ---------------------------------------------------------------------------
// QuotaResponse
// ---------------------------------------------------------------------------

func TestQuotaResponse_JSONRoundTrip(t *testing.T) {
	t.Parallel()
	now := time.Now().Truncate(time.Millisecond).UTC()
	resp := domain.QuotaResponse{
		Plan:       "free",
		DailyLimit: 50,
		DailyUsed:  10,
		ResetAt:    now,
	}

	data, err := json.Marshal(resp)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var decoded domain.QuotaResponse
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}

	if decoded.DailyLimit != 50 {
		t.Errorf("DailyLimit = %d, want 50", decoded.DailyLimit)
	}
	if decoded.DailyUsed != 10 {
		t.Errorf("DailyUsed = %d, want 10", decoded.DailyUsed)
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// assertMapKey checks that a key exists in a JSON-decoded map.
func assertMapKey(t *testing.T, m map[string]interface{}, key string) {
	t.Helper()
	if _, exists := m[key]; !exists {
		t.Errorf("expected key %q in JSON output", key)
	}
}

// intPtr returns a pointer to the given int value.
func intPtr(v int) *int {
	return &v
}
