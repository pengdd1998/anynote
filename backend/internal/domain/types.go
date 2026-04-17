package domain

import (
	"time"

	"github.com/google/uuid"
)

// ── User ──────────────────────────────────────────

type User struct {
	ID           uuid.UUID `json:"id"`
	Email        string    `json:"email"`
	Username     string    `json:"username"`
	AuthKeyHash  []byte    `json:"-"`
	Salt         []byte    `json:"-"`
	RecoveryKey  []byte    `json:"-"`
	Plan         string    `json:"plan"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// ── Sync Blob ─────────────────────────────────────

type SyncBlob struct {
	ID            uuid.UUID `json:"id"`
	UserID        uuid.UUID `json:"user_id"`
	ItemType      string    `json:"item_type"`      // 'note', 'tag', 'collection', 'content'
	ItemID        uuid.UUID `json:"item_id"`
	Version       int       `json:"version"`
	EncryptedData []byte    `json:"encrypted_data"`
	BlobSize      int       `json:"blob_size"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// ── LLM Config ────────────────────────────────────

type LLMConfig struct {
	ID            uuid.UUID `json:"id"`
	UserID        uuid.UUID `json:"user_id"`
	Name          string    `json:"name"`
	Provider      string    `json:"provider"`
	BaseURL       string    `json:"base_url"`
	EncryptedKey  []byte    `json:"-"`                // AES-256-GCM encrypted API key (DB storage)
	DecryptedKey  string    `json:"-"`                // Decrypted API key (never serialized)
	Model         string    `json:"model"`
	IsDefault     bool      `json:"is_default"`
	MaxTokens     int       `json:"max_tokens"`
	Temperature   float32   `json:"temperature"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// ── Platform Connection ───────────────────────────

type PlatformConnection struct {
	ID            uuid.UUID  `json:"id"`
	UserID        uuid.UUID  `json:"user_id"`
	Platform      string     `json:"platform"`
	PlatformUID   string     `json:"platform_uid,omitempty"`
	DisplayName   string     `json:"display_name,omitempty"`
	Status        string     `json:"status"`
	LastVerified  *time.Time `json:"last_verified,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

// ── Publish Log ───────────────────────────────────

type PublishLog struct {
	ID             uuid.UUID  `json:"id"`
	UserID         uuid.UUID  `json:"user_id"`
	Platform       string     `json:"platform"`
	PlatformConnID *uuid.UUID `json:"platform_conn_id,omitempty"`
	ContentItemID  *uuid.UUID `json:"content_item_id,omitempty"`
	Title          string     `json:"title,omitempty"`
	Content        string     `json:"content,omitempty"`
	Status         string     `json:"status"`
	PlatformURL    string     `json:"platform_url,omitempty"`
	ErrorMessage   string     `json:"error_message,omitempty"`
	PublishedAt    *time.Time `json:"published_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}

// ── AI Proxy Request ──────────────────────────────

type AIProxyRequest struct {
	Model       string         `json:"model,omitempty"`
	Messages    []ChatMessage  `json:"messages"`
	Temperature *float32       `json:"temperature,omitempty"`
	MaxTokens   *int           `json:"max_tokens,omitempty"`
	Stream      bool           `json:"stream,omitempty"`
}

type ChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type StreamChunk struct {
	Content string `json:"content,omitempty"`
	Done    bool   `json:"done,omitempty"`
	Error   string `json:"error,omitempty"`
}

// ── Sync Request/Response ─────────────────────────

type SyncPullRequest struct {
	SinceVersion int `json:"since_version"`
}

type SyncPullResponse struct {
	Blobs       []SyncBlob `json:"blobs"`
	LatestVersion int       `json:"latest_version"`
}

type SyncPushRequest struct {
	Blobs []SyncPushItem `json:"blobs"`
}

type SyncPushItem struct {
	ItemID        uuid.UUID `json:"item_id"`
	ItemType      string    `json:"item_type"`
	Version       int       `json:"version"`
	EncryptedData []byte    `json:"encrypted_data"`
	BlobSize      int       `json:"blob_size"`
}

type SyncPushResponse struct {
	Accepted []uuid.UUID        `json:"accepted"`
	Conflicts []SyncConflict    `json:"conflicts,omitempty"`
}

type SyncConflict struct {
	ItemID  uuid.UUID `json:"item_id"`
	ServerVersion int  `json:"server_version"`
}

type SyncStatusResponse struct {
	LatestVersion  int       `json:"latest_version"`
	TotalItems     int       `json:"total_items"`
	LastSyncedAt   time.Time `json:"last_synced_at"`
}

// ── Auth ──────────────────────────────────────────

type RegisterRequest struct {
	Email       string `json:"email"`
	Username    string `json:"username"`
	AuthKeyHash []byte `json:"auth_key_hash"`  // Client-derived: HKDF(master_key, "auth")
	Salt        []byte `json:"salt"`
	RecoveryKey []byte `json:"recovery_key"`   // Encrypted recovery key
}

type LoginRequest struct {
	Email       string `json:"email"`
	AuthKeyHash []byte `json:"auth_key_hash"`
}

type AuthResponse struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
	User         User      `json:"user"`
}

// ── Quota ─────────────────────────────────────────

type QuotaResponse struct {
	Plan        string     `json:"plan"`
	DailyLimit  int        `json:"daily_limit"`
	DailyUsed   int        `json:"daily_used"`
	ResetAt     time.Time  `json:"reset_at"`
}

// ── Errors ────────────────────────────────────────

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}

type QuotaExceededResponse struct {
	Error          string `json:"error"`
	RetryAfter     int    `json:"retry_after"`
	QueuePosition  int    `json:"queue_position,omitempty"`
}

// ── User Quota ────────────────────────────────────

type UserQuota struct {
	UserID       uuid.UUID `json:"user_id"`
	Plan         string    `json:"plan"`
	DailyAILimit int       `json:"daily_ai_limit"`
	DailyAIUsed  int       `json:"daily_ai_used"`
	QuotaResetAt time.Time `json:"quota_reset_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}
