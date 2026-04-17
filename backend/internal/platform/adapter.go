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

// Adapter defines the interface for platform publishing adapters.
type Adapter interface {
	Name() string
	Authenticate(ctx context.Context, authData []byte) error
	Publish(ctx context.Context, params PublishParams) (*PublishResult, error)
	CheckStatus(ctx context.Context, platformID string) (string, error)
	RevokeAuth(ctx context.Context) error
}
