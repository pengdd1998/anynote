package domain

import (
	"encoding/json"
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
	RecoverySalt []byte    `json:"-"`
	Plan         string    `json:"plan"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// ── Device ────────────────────────────────────────

type Device struct {
	ID         string    `json:"id"`
	UserID     string    `json:"user_id"`
	DeviceID   string    `json:"device_id"`
	DeviceName string    `json:"device_name"`
	Platform   string    `json:"platform"`
	LastSeen   time.Time `json:"last_seen"`
	CreatedAt  time.Time `json:"created_at"`
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
	DeviceID      string    `json:"device_id" db:"device_id"`
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
	DeviceID      string    `json:"device_id"`
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
	Email        string `json:"email"`
	Username     string `json:"username"`
	AuthKeyHash  []byte `json:"auth_key_hash"`   // Client-derived: HKDF(master_key, "auth")
	Salt         []byte `json:"salt"`
	RecoveryKey  []byte `json:"recovery_key"`    // Encrypted recovery key
	RecoverySalt []byte `json:"recovery_salt"`   // Random 32-byte salt for recovery key derivation
}

type LoginRequest struct {
	Email       string `json:"email"`
	AuthKeyHash []byte `json:"auth_key_hash"`
}

// RecoverySaltResponse is returned by GET /api/v1/auth/recovery-salt.
// RecoverySalt is nil for legacy accounts that registered before this field
// was added.  The client falls back to deterministic salt derivation in
// that case.
type RecoverySaltResponse struct {
	RecoverySalt []byte `json:"recovery_salt"`
}

type AuthResponse struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
	User         User      `json:"user"`
}

// RecoverRequest is the payload for account recovery via recovery key.
type RecoverRequest struct {
	Email       string `json:"email"`
	RecoveryKey string `json:"recovery_key"`
	NewPassword string `json:"new_password"`
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

// ── Note Links ──────────────────────────────────────

// NoteLink represents a bidirectional link between two notes.
// The server stores link metadata; link extraction from encrypted
// content is performed client-side.
type NoteLink struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	SourceID  uuid.UUID `json:"source_id"`
	TargetID  uuid.UUID `json:"target_id"`
	LinkType  string    `json:"link_type"`
	CreatedAt time.Time `json:"created_at"`
}

// CreateNoteLinksRequest is the payload for batch-creating note links.
type CreateNoteLinksRequest struct {
	Links []NoteLinkItem `json:"links"`
}

// NoteLinkItem represents a single link to create.
type NoteLinkItem struct {
	SourceID uuid.UUID `json:"source_id"`
	TargetID uuid.UUID `json:"target_id"`
	LinkType string    `json:"link_type"`
}

// NoteLinksResponse contains a list of note links.
type NoteLinksResponse struct {
	Links []NoteLink `json:"links"`
}

// NoteGraphResponse contains nodes and edges for the user's note graph.
type NoteGraphResponse struct {
	Nodes []NoteGraphNode `json:"nodes"`
	Edges []NoteLink      `json:"edges"`
}

// NoteGraphNode represents a note in the knowledge graph.
type NoteGraphNode struct {
	ItemID uuid.UUID `json:"item_id"`
}

// ── Collab Rooms ──────────────────────────────────

// CollabRoom represents a collaboration room with an invite code.
type CollabRoom struct {
	ID          string     `json:"id"`
	CreatorID   string     `json:"creator_id"`
	InviteCode  string     `json:"invite_code"`
	RoomName    string     `json:"room_name"`
	MaxMembers  int        `json:"max_members"`
	CreatedAt   time.Time  `json:"created_at"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
	IsActive    bool       `json:"is_active"`
	MemberCount int        `json:"member_count,omitempty"`
}

// CollabRoomMember represents a user's membership in a collab room.
type CollabRoomMember struct {
	ID       string    `json:"id"`
	RoomID   string    `json:"room_id"`
	UserID   string    `json:"user_id"`
	Role     string    `json:"role"`
	JoinedAt time.Time `json:"joined_at"`
}

// CreateRoomRequest is the payload for creating a collab room.
type CreateRoomRequest struct {
	RoomName string `json:"room_name"`
	MaxMembers int  `json:"max_members"`
}

// JoinRoomRequest is the payload for joining a collab room via invite code.
type JoinRoomRequest struct {
	InviteCode string `json:"invite_code"`
}

// ── Collab Operations (CRDT persistence) ───────────

// CollabOperation represents a persisted CRDT operation for a collab room.
// Operations are stored as encrypted blobs -- the server never inspects payloads.
type CollabOperation struct {
	ID            string     `json:"id"`
	RoomID        string     `json:"room_id"`
	SiteID        string     `json:"site_id"`
	Clock         int        `json:"clock"`
	OperationType string     `json:"operation_type"` // "insert" or "delete"
	Payload       []byte     `json:"payload"`        // JSONB, opaque to server
	CreatedAt     time.Time  `json:"created_at"`
}

// ── AI Agent ────────────────────────────────────────

// AIAgentRequest is the payload for requesting an AI agent action.
type AIAgentRequest struct {
	Action     string                 `json:"action"`
	Context    map[string]interface{} `json:"context"`
	NoteIDs    []uuid.UUID            `json:"note_ids,omitempty"`
	Parameters map[string]interface{} `json:"parameters,omitempty"`
}

// AIAgentResponse contains the result of an AI agent action.
type AIAgentResponse struct {
	Action  string                 `json:"action"`
	Status  string                 `json:"status"`
	Result  map[string]interface{} `json:"result"`
	Message string                 `json:"message,omitempty"`
}

// ── Payment ────────────────────────────────────────

// Payment represents a payment transaction record.
type Payment struct {
	ID               string     `json:"id"`
	UserID           string     `json:"user_id"`
	StripeSessionID  string     `json:"stripe_session_id"`
	AmountCents      int        `json:"amount_cents"`
	Currency         string     `json:"currency"`
	Status           string     `json:"status"`
	Plan             string     `json:"plan"`
	CreatedAt        time.Time  `json:"created_at"`
	CompletedAt      *time.Time `json:"completed_at,omitempty"`
}

// CreateCheckoutRequest is the payload for initiating a Stripe checkout session.
type CreateCheckoutRequest struct {
	Plan       string `json:"plan"`
	SuccessURL string `json:"success_url"`
	CancelURL  string `json:"cancel_url"`
}

// CheckoutResponse is returned after successfully creating a checkout session.
type CheckoutResponse struct {
	SessionURL string `json:"session_url"`
}

// ── Notification ───────────────────────────────────

// Notification represents a persistent user notification.
type Notification struct {
	ID        string          `json:"id"`
	UserID    string          `json:"user_id"`
	Type      string          `json:"type"`
	Title     string          `json:"title"`
	Body      string          `json:"body"`
	Data      json.RawMessage `json:"data"`
	IsRead    bool            `json:"is_read"`
	CreatedAt time.Time       `json:"created_at"`
}
