package platform

import "context"

// PublishParams contains the content to publish.
type PublishParams struct {
	Title      string     `json:"title"`
	Content    string     `json:"content"`
	Tags       []string   `json:"tags"`
	Images     []ImageRef `json:"images"`
	ScheduleAt *string    `json:"schedule_at,omitempty"`
}

// ImageRef references an image to include in the post.
type ImageRef struct {
	URL      string `json:"url,omitempty"`
	FilePath string `json:"file_path,omitempty"`
}

// PublishResult is returned after a successful publish.
type PublishResult struct {
	PlatformURL string `json:"platform_url"`
	PlatformID  string `json:"platform_id"`
}

// AuthSession holds state for an in-progress authentication flow.
// It is created by StartAuth and passed to PollAuth until completion.
type AuthSession struct {
	// CDPContext is an opaque handle that allows the adapter to reuse the
	// browser tab across StartAuth and PollAuth calls.  The concrete type
	// is decided by the adapter implementation.
	CDPContext interface{} `json:"-"`

	// AuthRef is a unique identifier for this auth session, used for
	// correlating poll requests with the original StartAuth call.
	AuthRef string `json:"auth_ref"`
}

// Adapter defines the interface for platform publishing adapters.
type Adapter interface {
	Name() string

	// StartAuth initiates the platform authentication flow.
	// For QR-code-based flows (e.g. XHS), this navigates to the login page,
	// extracts the QR code image, and returns it as PNG bytes inside the
	// AuthStartResult.  The caller should send the PNG to the client.
	//
	// The returned AuthSession must be stored server-side so that subsequent
	// PollAuth calls can reference it.
	StartAuth(ctx context.Context, masterKey []byte) (*AuthSession, []byte, error)

	// PollAuth checks whether the user has completed the authentication
	// (e.g. scanned the QR code).  Returns (nil, nil) when auth is still
	// pending.  On success, returns the encrypted auth data (AES-256-GCM
	// sealed cookies/tokens) which the caller should persist.
	PollAuth(ctx context.Context, session *AuthSession, masterKey []byte) ([]byte, error)

	// Publish creates a new post on the platform.
	// encryptedAuth is the opaque blob previously returned by PollAuth;
	// the adapter decrypts it internally using masterKey.
	Publish(ctx context.Context, encryptedAuth []byte, masterKey []byte, params PublishParams) (*PublishResult, error)

	// CheckStatus checks if a published post is still live.
	// Returns a status string: "live", "removed", "unknown".
	CheckStatus(ctx context.Context, encryptedAuth []byte, masterKey []byte, platformID string) (string, error)

	// RevokeAuth validates that the auth data can no longer be used.
	// The caller is responsible for deleting persisted data regardless
	// of the return value; this hook lets the adapter perform
	// platform-specific cleanup (e.g. API-level session revocation).
	RevokeAuth(ctx context.Context, encryptedAuth []byte, masterKey []byte) error
}
