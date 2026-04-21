package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

// ── Sentinels ─────────────────────────────────────

var ErrInvalidReaction = errors.New("invalid reaction type")

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
	APIKey        string    `json:"api_key,omitempty"` // Input field for create/update; not stored
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
	EncryptedAuth []byte     `json:"-"`                        // AES-256-GCM encrypted auth data (cookies/tokens)
	Status        string     `json:"status"`
	LastVerified  *time.Time `json:"last_verified,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

// ── Platform Auth ─────────────────────────────────

// AuthStartResult is returned when starting a platform authentication flow.
type AuthStartResult struct {
	QRCodePNG   []byte            `json:"-"`              // QR code image bytes (sent as binary)
	AuthRef     string            `json:"auth_ref"`       // Reference ID for polling auth status
	Status      string            `json:"status"`         // "qr_ready", "polling", "done", "failed"
	DisplayName string            `json:"display_name"`   // Platform display name (set on success)
	PlatformUID string            `json:"platform_uid"`   // Platform user ID (set on success)
	Extra       map[string]string `json:"extra,omitempty"`
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
	Blobs         []SyncBlob `json:"blobs"`
	LatestVersion int        `json:"latest_version"`
	HasMore       bool       `json:"has_more"`
	NextCursor    int        `json:"next_cursor"`
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
	ItemID        uuid.UUID `json:"item_id"`
	ItemType      string    `json:"item_type"`
	ServerVersion int       `json:"server_version"`
	ClientVersion int       `json:"client_version"`
}

type SyncStatusResponse struct {
	LatestVersion  int       `json:"latest_version"`
	TotalItems     int       `json:"total_items"`
	LastSyncedAt   time.Time `json:"last_synced_at"`
}

// SyncStatusSummary is the raw status data returned by the repository layer.
type SyncStatusSummary struct {
	LatestVersion int
	TotalItems    int
	LastUpdated   time.Time
}

// BatchUpsertResult holds the outcome for a single item in a batch upsert.
type BatchUpsertResult struct {
	ItemID        uuid.UUID `json:"item_id"`
	ItemType      string    `json:"item_type"`
	ClientVersion int       `json:"client_version"`
	Accepted      bool      `json:"accepted"`
	ServerVersion int       `json:"server_version"`
	Error         error     `json:"-"`
}

// ── Sync Operation Log ────────────────────────────

// SyncOperationLog records a single sync push/pull operation for debugging and history.
type SyncOperationLog struct {
	ID            uuid.UUID `json:"id"`
	UserID        uuid.UUID `json:"user_id"`
	OperationType string    `json:"operation_type"` // "push" or "pull"
	ItemType      string    `json:"item_type"`
	ItemID        uuid.UUID `json:"item_id"`
	Version       int       `json:"version"`
	CreatedAt     time.Time `json:"created_at"`
}

// SyncStatsResponse returns aggregate sync statistics for a user.
type SyncStatsResponse struct {
	TotalItems     int                `json:"total_items"`
	ItemsByType    map[string]int     `json:"items_by_type"`
	LastSyncedAt   time.Time          `json:"last_synced_at"`
	TotalConflicts int64              `json:"total_conflicts"`
}

// ── Tag Listing ───────────────────────────────────

// TagListItem represents a single tag item from the user's sync blobs.
// Since tag data is encrypted, only metadata is returned by the server.
type TagListItem struct {
	ItemID    uuid.UUID `json:"item_id"`
	Version   int       `json:"version"`
	BlobSize  int       `json:"blob_size"`
	UpdatedAt time.Time `json:"updated_at"`
}

// ListTagsResponse is the response for listing tag items.
type ListTagsResponse struct {
	Tags []TagListItem `json:"tags"`
}

// ── Batch Delete ──────────────────────────────────

// BatchDeleteRequest is the payload for deleting multiple sync blobs at once.
type BatchDeleteRequest struct {
	ItemIDs []uuid.UUID `json:"item_ids"`
}

// BatchDeleteResponse is the response for a batch delete operation.
type BatchDeleteResponse struct {
	Deleted int `json:"deleted"`
}

// ── Sync Progress ─────────────────────────────────

// SyncProgressResponse returns the current sync state and health information.
type SyncProgressResponse struct {
	TotalItems       int       `json:"total_items"`
	LatestVersion    int       `json:"latest_version"`
	LastSyncedAt     time.Time `json:"last_synced_at"`
	PendingCount     int64     `json:"pending_count"`      // operation logs awaiting processing
	ConflictCount    int64     `json:"conflict_count"`     // total logged conflicts
	HealthStatus     string    `json:"health_status"`      // "ok", "warnings", or "errors"
	PushCount24h     int64     `json:"push_count_24h"`     // push operations in last 24 hours
	PullCount24h     int64     `json:"pull_count_24h"`     // pull operations in last 24 hours
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

// ErrorDetail contains the machine-readable code and human-readable message.
type ErrorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// ErrorResponse is the standard error envelope for all API responses.
type ErrorResponse struct {
	Error     ErrorDetail `json:"error"`
	RequestID string      `json:"request_id,omitempty"`
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

// ── Shared Notes ──────────────────────────────────

type SharedNote struct {
	ID               string     `json:"id"`
	EncryptedContent string     `json:"encrypted_content"`
	EncryptedTitle   string     `json:"encrypted_title"`
	ShareKeyHash     string     `json:"-"`
	HasPassword      bool       `json:"has_password"`
	IsPublic         bool       `json:"is_public"`
	ExpiresAt        *time.Time `json:"expires_at,omitempty"`
	ViewCount        int        `json:"view_count"`
	MaxViews         *int       `json:"max_views,omitempty"`
	ReactionHeart    int        `json:"reaction_heart"`
	ReactionBookmark int        `json:"reaction_bookmark"`
	CreatedBy        uuid.UUID  `json:"-"`
	CreatedAt        time.Time  `json:"created_at"`
}

type CreateShareRequest struct {
	EncryptedContent string `json:"encrypted_content"`
	EncryptedTitle   string `json:"encrypted_title"`
	ShareKeyHash     string `json:"share_key_hash"`
	HasPassword      bool   `json:"has_password"`
	IsPublic         *bool  `json:"is_public,omitempty"`
	ExpiresHours     *int   `json:"expires_hours,omitempty"`
	MaxViews         *int   `json:"max_views,omitempty"`
}

type CreateShareResponse struct {
	ID  string `json:"id"`
	URL string `json:"url"`
}

type GetShareResponse struct {
	ID               string     `json:"id"`
	EncryptedContent string     `json:"encrypted_content"`
	EncryptedTitle   string     `json:"encrypted_title"`
	HasPassword      bool       `json:"has_password"`
	ShareKeyHash     string     `json:"-"` // Server-side only: used for password verification
	ExpiresAt        *time.Time `json:"expires_at,omitempty"`
	ViewCount        int        `json:"view_count"`
	MaxViews         *int       `json:"max_views,omitempty"`
}

// DiscoverFeedItem is a public shared note in the discovery feed.
type DiscoverFeedItem struct {
	ID               string    `json:"id"`
	EncryptedTitle   string    `json:"encrypted_title"`
	HasPassword      bool      `json:"has_password"`
	ViewCount        int       `json:"view_count"`
	ReactionHeart    int       `json:"reaction_heart"`
	ReactionBookmark int       `json:"reaction_bookmark"`
	CreatedAt        time.Time `json:"created_at"`
}

// ReactRequest is the payload for reacting to a shared note.
type ReactRequest struct {
	ReactionType string `json:"reaction_type"` // "heart" or "bookmark"
}

// ReactResponse confirms a reaction toggle.
type ReactResponse struct {
	ReactionType string `json:"reaction_type"`
	Active       bool   `json:"active"` // true = added, false = removed
	Count        int    `json:"count"`  // new total count for this reaction type
}

// ── Comments ─────────────────────────────────────────

// Comment represents an encrypted comment on a shared note.
type Comment struct {
	ID               uuid.UUID  `json:"id"`
	SharedNoteID     string     `json:"shared_note_id"`
	UserID           uuid.UUID  `json:"user_id"`
	EncryptedContent string     `json:"encrypted_content"`
	ParentID         *uuid.UUID `json:"parent_id,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

// CreateCommentRequest is the payload for creating a comment.
type CreateCommentRequest struct {
	EncryptedContent string `json:"encrypted_content"`
	ParentID         string `json:"parent_id,omitempty"` // optional, for replies
}

// ListCommentsResponse is the paginated response for listing comments.
type ListCommentsResponse struct {
	Comments []Comment `json:"comments"`
	Total    int       `json:"total"`
}
