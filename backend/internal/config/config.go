package config

import (
	"encoding/hex"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

// splitCSV splits a comma-separated string into trimmed, non-empty parts.
func splitCSV(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

// Config holds all application configuration.
type Config struct {
	Server   ServerConfig   `yaml:"server"`
	Database DatabaseConfig `yaml:"database"`
	Redis    RedisConfig    `yaml:"redis"`
	MinIO    MinIOConfig    `yaml:"minio"`
	Auth     AuthConfig     `yaml:"auth"`
	LLM      LLMConfig      `yaml:"llm"`
	Chrome   ChromeConfig   `yaml:"chrome"`
	Log      LogConfig      `yaml:"log"`
	Firebase FirebaseConfig `yaml:"firebase"`
	Stripe   StripeConfig   `yaml:"stripe"`
}

// MinIOConfig defaults — Bucket defaults to "anynote" when empty.
func (c MinIOConfig) BucketName() string {
	if c.Bucket == "" {
		return "anynote"
	}
	return c.Bucket
}

// LogConfig controls structured logging behaviour.
type LogConfig struct {
	Level  string `yaml:"level"`  // debug, info, warn, error (default: info)
	Format string `yaml:"format"` // json (default) or text
}

type ServerConfig struct {
	Port         int           `yaml:"port"`
	ReadTimeout  time.Duration `yaml:"read_timeout"`
	WriteTimeout time.Duration `yaml:"write_timeout"`
	AllowOrigins []string      `yaml:"allow_origins"`
}

type DatabaseConfig struct {
	URL             string        `yaml:"url"`
	MaxOpenConns    int           `yaml:"max_open_conns"`
	MaxIdleConns    int           `yaml:"max_idle_conns"`
	ConnMaxLifetime time.Duration `yaml:"conn_max_lifetime"`
}

type RedisConfig struct {
	URL string `yaml:"url"`
}

type MinIOConfig struct {
	Endpoint  string `yaml:"endpoint"`
	AccessKey string `yaml:"access_key"`
	SecretKey string `yaml:"secret_key"`
	Bucket    string `yaml:"bucket"`
	UseSSL    bool   `yaml:"use_ssl"`
}

type AuthConfig struct {
	JWTSecret          string        `yaml:"jwt_secret"`
	TokenExpiry        time.Duration `yaml:"token_expiry"`
	RefreshExpiry      time.Duration `yaml:"refresh_expiry"`
	MasterEncryptionKey string       `yaml:"master_encryption_key"`
}

type LLMConfig struct {
	Default  LLMProviderConfig `yaml:"default"`
	Fallback LLMProviderConfig `yaml:"fallback"`
}

type LLMProviderConfig struct {
	Provider     string        `yaml:"provider"`
	BaseURL      string        `yaml:"base_url"`
	APIKey       string        `yaml:"api_key"`
	Model        string        `yaml:"model"`
	MaxConcurrent int          `yaml:"max_concurrent"`
	Timeout      time.Duration `yaml:"timeout"`
}

type ChromeConfig struct {
	WSURL string `yaml:"ws_url"`
}

// FirebaseConfig holds Firebase Cloud Messaging credentials.
type FirebaseConfig struct {
	CredentialsFile string `yaml:"credentials_file"` // Path to Firebase service account JSON
}

// StripeConfig holds Stripe payment integration settings.
type StripeConfig struct {
	SecretKey      string `yaml:"secret_key"`       // Stripe secret API key
	WebhookSecret  string `yaml:"webhook_secret"`   // Stripe webhook signing secret
	ProPriceID     string `yaml:"pro_price_id"`     // Stripe Price ID for Pro plan
	LifetimePriceID string `yaml:"lifetime_price_id"` // Stripe Price ID for Lifetime plan
}

// Load reads config from file and environment variables.
func Load(path string) (*Config, error) {
	cfg := &Config{
		Server: ServerConfig{
			Port:         8080,
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 120 * time.Second, // Long for SSE streaming
			AllowOrigins: []string{},
		},
		Log: LogConfig{
			Level:  "info",
			Format: "json",
		},
		Database: DatabaseConfig{
			MaxOpenConns:    25,
			MaxIdleConns:    5,
			ConnMaxLifetime: 5 * time.Minute,
		},
		Auth: AuthConfig{
			TokenExpiry:   24 * time.Hour,
			RefreshExpiry: 30 * 24 * time.Hour,
		},
		LLM: LLMConfig{
			Default: LLMProviderConfig{
				MaxConcurrent: 50,
				Timeout:       120 * time.Second,
			},
			Fallback: LLMProviderConfig{
				MaxConcurrent: 25,
				Timeout:       120 * time.Second,
			},
		},
	}

	data, err := os.ReadFile(path)
	if err != nil {
		if !os.IsNotExist(err) {
			return nil, fmt.Errorf("read config file: %w", err)
		}
	} else {
		if err := yaml.Unmarshal(data, cfg); err != nil {
			return nil, fmt.Errorf("parse config file: %w", err)
		}
	}

	// Override with environment variables
	cfg.applyEnvOverrides()

	return cfg, nil
}

func (c *Config) applyEnvOverrides() {
	if v := os.Getenv("DATABASE_URL"); v != "" {
		c.Database.URL = v
	}
	if v := os.Getenv("REDIS_URL"); v != "" {
		c.Redis.URL = v
	}
	if v := os.Getenv("JWT_SECRET"); v != "" {
		c.Auth.JWTSecret = v
	}
	if v := os.Getenv("MASTER_ENCRYPTION_KEY"); v != "" {
		c.Auth.MasterEncryptionKey = v
	}
	if v := os.Getenv("DEEPSEEK_API_KEY"); v != "" {
		c.LLM.Default.APIKey = v
		if c.LLM.Default.BaseURL == "" {
			c.LLM.Default.Provider = "deepseek"
			c.LLM.Default.BaseURL = "https://api.deepseek.com/v1"
			c.LLM.Default.Model = "deepseek-chat"
		}
	}
	if v := os.Getenv("QWEN_API_KEY"); v != "" {
		c.LLM.Fallback.APIKey = v
		if c.LLM.Fallback.BaseURL == "" {
			c.LLM.Fallback.Provider = "qwen"
			c.LLM.Fallback.BaseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
			c.LLM.Fallback.Model = "qwen-plus"
		}
	}
	if v := os.Getenv("CHROME_WS_URL"); v != "" {
		c.Chrome.WSURL = v
	}
	if v := os.Getenv("MINIO_ENDPOINT"); v != "" {
		c.MinIO.Endpoint = v
	}
	if v := os.Getenv("MINIO_ACCESS_KEY"); v != "" {
		c.MinIO.AccessKey = v
	}
	if v := os.Getenv("MINIO_SECRET_KEY"); v != "" {
		c.MinIO.SecretKey = v
	}
	if v := os.Getenv("PORT"); v != "" {
		fmt.Sscanf(v, "%d", &c.Server.Port)
	}
	if v := os.Getenv("LOG_LEVEL"); v != "" {
		c.Log.Level = v
	}
	if v := os.Getenv("LOG_FORMAT"); v != "" {
		c.Log.Format = v
	}
	if v := os.Getenv("FIREBASE_CREDENTIALS_FILE"); v != "" {
		c.Firebase.CredentialsFile = v
	}
	if v := os.Getenv("WS_ALLOWED_ORIGINS"); v != "" {
		// Comma-separated list of allowed WebSocket origins, e.g. "https://app.example.com,https://web.example.com"
		c.Server.AllowOrigins = splitCSV(v)
	}
	if v := os.Getenv("STRIPE_SECRET_KEY"); v != "" {
		c.Stripe.SecretKey = v
	}
	if v := os.Getenv("STRIPE_WEBHOOK_SECRET"); v != "" {
		c.Stripe.WebhookSecret = v
	}
}

// LogLevel returns the configured log level as a string (debug, info, warn, error).
func (c *Config) LogLevel() string {
	if c.Log.Level == "" {
		return "info"
	}
	return c.Log.Level
}

// LogFormat returns the configured log format ("json" or "text").
// Defaults to "json" for production use.
func (c *Config) LogFormat() string {
	if c.Log.Format == "" {
		return "json"
	}
	return c.Log.Format
}

// Validate checks critical configuration values and returns an error if any are invalid or missing.
func (c *Config) Validate() error {
	if c.Auth.JWTSecret == "" {
		return fmt.Errorf("JWT_SECRET is required but not set")
	}
	if len(c.Auth.JWTSecret) < 16 {
		return fmt.Errorf("JWT_SECRET must be at least 16 characters, got %d", len(c.Auth.JWTSecret))
	}
	if c.Auth.MasterEncryptionKey == "" {
		return fmt.Errorf("MASTER_ENCRYPTION_KEY is required but not set")
	}
	if err := validateMasterKey(c.Auth.MasterEncryptionKey); err != nil {
		return err
	}
	if c.Database.URL == "" {
		return fmt.Errorf("DATABASE_URL is required but not set")
	}
	return nil
}

// Warn logs warnings for non-critical configuration issues.
// These are configuration values that are not strictly required for the server
// to start, but may indicate misconfiguration or missing optional features.
func (c *Config) Warn() {
	// Check Redis URL format.
	if c.Redis.URL != "" {
		if !strings.HasPrefix(c.Redis.URL, "redis://") && !strings.HasPrefix(c.Redis.URL, "rediss://") {
			slog.Warn("REDIS_URL should start with redis:// or rediss://", "url", c.Redis.URL)
		}
	}

	// Check Firebase credentials file exists (if configured).
	if c.Firebase.CredentialsFile != "" {
		if _, err := os.Stat(c.Firebase.CredentialsFile); err != nil {
			slog.Warn("FIREBASE_CREDENTIALS_FILE not found", "path", c.Firebase.CredentialsFile, "error", err)
		}
	}

	// Check LLM default BaseURL is a valid URL (if set).
	if c.LLM.Default.BaseURL != "" {
		if !strings.HasPrefix(c.LLM.Default.BaseURL, "http://") && !strings.HasPrefix(c.LLM.Default.BaseURL, "https://") {
			slog.Warn("LLM default base_url should start with http:// or https://", "base_url", c.LLM.Default.BaseURL)
		}
	}

	// Check LLM fallback BaseURL is a valid URL (if set).
	if c.LLM.Fallback.BaseURL != "" {
		if !strings.HasPrefix(c.LLM.Fallback.BaseURL, "http://") && !strings.HasPrefix(c.LLM.Fallback.BaseURL, "https://") {
			slog.Warn("LLM fallback base_url should start with http:// or https://", "base_url", c.LLM.Fallback.BaseURL)
		}
	}

	// Warn if server port is 0 or negative.
	if c.Server.Port <= 0 || c.Server.Port > 65535 {
		slog.Warn("server port is out of valid range (1-65535)", "port", c.Server.Port)
	}

	// Warn if CORS AllowOrigins is empty (no cross-origin access allowed).
	if len(c.Server.AllowOrigins) == 0 {
		slog.Warn("CORS AllowOrigins is empty; cross-origin requests will be rejected. Set WS_ALLOWED_ORIGINS or server.allow_origins in config to enable.")
	}
}

// MasterKeyBytes decodes the master encryption key into raw bytes suitable for
// AES-256. If the key string is a valid hex-encoded sequence of 64+ hex
// characters, it is hex-decoded to produce 32+ bytes. Otherwise the raw UTF-8
// bytes are returned (for backward compatibility with non-hex key strings).
// The result is validated to be exactly 32 bytes; an error is returned if the
// decoded length does not match.
func (a AuthConfig) MasterKeyBytes() ([]byte, error) {
	raw := a.MasterEncryptionKey

	// Try hex decoding: a 64-char hex string decodes to 32 bytes.
	if decoded, err := hex.DecodeString(raw); err == nil && len(decoded) >= 32 {
		if len(decoded) != 32 {
			return nil, fmt.Errorf("MASTER_ENCRYPTION_KEY hex-decoded to %d bytes, need exactly 32 bytes for AES-256", len(decoded))
		}
		return decoded, nil
	}

	// Not valid hex; treat as raw string. Must be exactly 32 bytes.
	b := []byte(raw)
	if len(b) != 32 {
		return nil, fmt.Errorf("MASTER_ENCRYPTION_KEY must be exactly 32 bytes (got %d); AES-256 requires a 32-byte key. Alternatively provide a 64-character hex-encoded string", len(b))
	}
	return b, nil
}

// validateMasterKey ensures the master encryption key provides at least 32 bytes
// of key material (required for AES-256). Accepts either:
//   - A raw string of 32+ characters
//   - A hex-encoded string of 64+ characters (decoded to 32+ bytes)
func validateMasterKey(key string) error {
	// Try hex decoding first.
	if decoded, err := hex.DecodeString(key); err == nil {
		if len(decoded) >= 32 {
			return nil
		}
		return fmt.Errorf("MASTER_ENCRYPTION_KEY hex-decoded to %d bytes, need at least 32 bytes for AES-256", len(decoded))
	}

	// Not valid hex; treat as raw string.
	if len(key) < 32 {
		return fmt.Errorf("MASTER_ENCRYPTION_KEY must be at least 32 bytes (got %d); AES-256 requires a 32-byte key. Alternatively provide a 64-character hex-encoded string", len(key))
	}
	return nil
}
