package config

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// ---------------------------------------------------------------------------
// Tests: Load
// ---------------------------------------------------------------------------

func TestLoad_Defaults(t *testing.T) {
	// Load from a non-existent file should return defaults.
	cfg, err := Load("/nonexistent/config.yaml")
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}

	if cfg.Server.Port != 8080 {
		t.Errorf("default Port = %d, want 8080", cfg.Server.Port)
	}
	if cfg.Server.ReadTimeout != 15*time.Second {
		t.Errorf("default ReadTimeout = %v, want 15s", cfg.Server.ReadTimeout)
	}
	if cfg.Server.WriteTimeout != 120*time.Second {
		t.Errorf("default WriteTimeout = %v, want 120s", cfg.Server.WriteTimeout)
	}
	if cfg.Log.Level != "info" {
		t.Errorf("default LogLevel = %q, want %q", cfg.Log.Level, "info")
	}
	if cfg.Database.MaxOpenConns != 25 {
		t.Errorf("default MaxOpenConns = %d, want 25", cfg.Database.MaxOpenConns)
	}
	if cfg.Database.MaxIdleConns != 5 {
		t.Errorf("default MaxIdleConns = %d, want 5", cfg.Database.MaxIdleConns)
	}
	if cfg.Auth.TokenExpiry != 24*time.Hour {
		t.Errorf("default TokenExpiry = %v, want 24h", cfg.Auth.TokenExpiry)
	}
	if cfg.Auth.RefreshExpiry != 30*24*time.Hour {
		t.Errorf("default RefreshExpiry = %v, want 720h", cfg.Auth.RefreshExpiry)
	}
	if cfg.LLM.Default.MaxConcurrent != 50 {
		t.Errorf("default LLM.Default.MaxConcurrent = %d, want 50", cfg.LLM.Default.MaxConcurrent)
	}
	if cfg.LLM.Default.Timeout != 120*time.Second {
		t.Errorf("default LLM.Default.Timeout = %v, want 120s", cfg.LLM.Default.Timeout)
	}
	if cfg.LLM.Fallback.MaxConcurrent != 25 {
		t.Errorf("default LLM.Fallback.MaxConcurrent = %d, want 25", cfg.LLM.Fallback.MaxConcurrent)
	}
}

func TestLoad_FromYAML(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "config.yaml")

	content := []byte(`
server:
  port: 9090
  read_timeout: 10s
  write_timeout: 60s
database:
  url: "postgres://localhost:5432/testdb"
  max_open_conns: 10
redis:
  url: "redis://localhost:6379"
auth:
  jwt_secret: "my-jwt-secret-123456"
  master_encryption_key: "my-master-key-1234567"
  token_expiry: 12h
log:
  level: debug
`)

	if err := os.WriteFile(cfgPath, content, 0644); err != nil {
		t.Fatalf("write config file: %v", err)
	}

	cfg, err := Load(cfgPath)
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}

	if cfg.Server.Port != 9090 {
		t.Errorf("Port = %d, want 9090", cfg.Server.Port)
	}
	if cfg.Server.ReadTimeout != 10*time.Second {
		t.Errorf("ReadTimeout = %v, want 10s", cfg.Server.ReadTimeout)
	}
	if cfg.Server.WriteTimeout != 60*time.Second {
		t.Errorf("WriteTimeout = %v, want 60s", cfg.Server.WriteTimeout)
	}
	if cfg.Database.URL != "postgres://localhost:5432/testdb" {
		t.Errorf("Database.URL = %q, want %q", cfg.Database.URL, "postgres://localhost:5432/testdb")
	}
	if cfg.Database.MaxOpenConns != 10 {
		t.Errorf("MaxOpenConns = %d, want 10", cfg.Database.MaxOpenConns)
	}
	if cfg.Redis.URL != "redis://localhost:6379" {
		t.Errorf("Redis.URL = %q, want %q", cfg.Redis.URL, "redis://localhost:6379")
	}
	if cfg.Auth.JWTSecret != "my-jwt-secret-123456" {
		t.Errorf("JWTSecret = %q, want %q", cfg.Auth.JWTSecret, "my-jwt-secret-123456")
	}
	if cfg.Auth.TokenExpiry != 12*time.Hour {
		t.Errorf("TokenExpiry = %v, want 12h", cfg.Auth.TokenExpiry)
	}
	if cfg.Log.Level != "debug" {
		t.Errorf("LogLevel = %q, want %q", cfg.Log.Level, "debug")
	}
}

func TestLoad_InvalidYAML(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "bad.yaml")

	if err := os.WriteFile(cfgPath, []byte("server:\n  port: [invalid"), 0644); err != nil {
		t.Fatalf("write config file: %v", err)
	}

	_, err := Load(cfgPath)
	if err == nil {
		t.Fatal("expected error for invalid YAML, got nil")
	}
}

// ---------------------------------------------------------------------------
// Tests: Validate
// ---------------------------------------------------------------------------

func TestValidate_Success(t *testing.T) {
	cfg := &Config{
		Database: DatabaseConfig{URL: "postgres://localhost/db"},
		Auth: AuthConfig{
			JWTSecret:          "a-valid-jwt-secret-16ch",
			MasterEncryptionKey: "a-valid-master-key-16",
		},
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("Validate returned unexpected error: %v", err)
	}
}

func TestValidate_MissingJWTSecret(t *testing.T) {
	cfg := &Config{
		Database: DatabaseConfig{URL: "postgres://localhost/db"},
		Auth: AuthConfig{
			MasterEncryptionKey: "a-valid-master-key-16",
		},
	}
	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected error for missing JWT_SECRET")
	}
}

func TestValidate_ShortJWTSecret(t *testing.T) {
	cfg := &Config{
		Database: DatabaseConfig{URL: "postgres://localhost/db"},
		Auth: AuthConfig{
			JWTSecret:          "short",
			MasterEncryptionKey: "a-valid-master-key-16",
		},
	}
	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected error for short JWT_SECRET")
	}
}

func TestValidate_MissingMasterKey(t *testing.T) {
	cfg := &Config{
		Database: DatabaseConfig{URL: "postgres://localhost/db"},
		Auth: AuthConfig{
			JWTSecret: "a-valid-jwt-secret-16ch",
		},
	}
	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected error for missing MASTER_ENCRYPTION_KEY")
	}
}

func TestValidate_ShortMasterKey(t *testing.T) {
	cfg := &Config{
		Database: DatabaseConfig{URL: "postgres://localhost/db"},
		Auth: AuthConfig{
			JWTSecret:          "a-valid-jwt-secret-16ch",
			MasterEncryptionKey: "short",
		},
	}
	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected error for short MASTER_ENCRYPTION_KEY")
	}
}

func TestValidate_MissingDatabaseURL(t *testing.T) {
	cfg := &Config{
		Auth: AuthConfig{
			JWTSecret:          "a-valid-jwt-secret-16ch",
			MasterEncryptionKey: "a-valid-master-key-16",
		},
	}
	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected error for missing DATABASE_URL")
	}
}

// ---------------------------------------------------------------------------
// Tests: BucketName
// ---------------------------------------------------------------------------

func TestBucketName_Default(t *testing.T) {
	cfg := MinIOConfig{}
	if cfg.BucketName() != "anynote" {
		t.Errorf("BucketName() = %q, want %q", cfg.BucketName(), "anynote")
	}
}

func TestBucketName_Custom(t *testing.T) {
	cfg := MinIOConfig{Bucket: "my-custom-bucket"}
	if cfg.BucketName() != "my-custom-bucket" {
		t.Errorf("BucketName() = %q, want %q", cfg.BucketName(), "my-custom-bucket")
	}
}

// ---------------------------------------------------------------------------
// Tests: LogLevel
// ---------------------------------------------------------------------------

func TestLogLevel_Default(t *testing.T) {
	cfg := &Config{Log: LogConfig{Level: ""}}
	if cfg.LogLevel() != "info" {
		t.Errorf("LogLevel() = %q, want %q", cfg.LogLevel(), "info")
	}
}

func TestLogLevel_Custom(t *testing.T) {
	cfg := &Config{Log: LogConfig{Level: "debug"}}
	if cfg.LogLevel() != "debug" {
		t.Errorf("LogLevel() = %q, want %q", cfg.LogLevel(), "debug")
	}
}

// ---------------------------------------------------------------------------
// Tests: LogFormat
// ---------------------------------------------------------------------------

func TestLogFormat_Default(t *testing.T) {
	cfg := &Config{Log: LogConfig{Format: ""}}
	if cfg.LogFormat() != "json" {
		t.Errorf("LogFormat() = %q, want %q", cfg.LogFormat(), "json")
	}
}

func TestLogFormat_Text(t *testing.T) {
	cfg := &Config{Log: LogConfig{Format: "text"}}
	if cfg.LogFormat() != "text" {
		t.Errorf("LogFormat() = %q, want %q", cfg.LogFormat(), "text")
	}
}

func TestLogFormat_JSON(t *testing.T) {
	cfg := &Config{Log: LogConfig{Format: "json"}}
	if cfg.LogFormat() != "json" {
		t.Errorf("LogFormat() = %q, want %q", cfg.LogFormat(), "json")
	}
}

// ---------------------------------------------------------------------------
// Tests: applyEnvOverrides
// ---------------------------------------------------------------------------

func TestApplyEnvOverrides_DatabaseURL(t *testing.T) {
	os.Setenv("DATABASE_URL", "postgres://envhost/db")
	defer os.Unsetenv("DATABASE_URL")

	cfg, _ := Load("/nonexistent")
	if cfg.Database.URL != "postgres://envhost/db" {
		t.Errorf("Database.URL = %q, want %q", cfg.Database.URL, "postgres://envhost/db")
	}
}

func TestApplyEnvOverrides_RedisURL(t *testing.T) {
	os.Setenv("REDIS_URL", "redis://envhost:6379")
	defer os.Unsetenv("REDIS_URL")

	cfg, _ := Load("/nonexistent")
	if cfg.Redis.URL != "redis://envhost:6379" {
		t.Errorf("Redis.URL = %q, want %q", cfg.Redis.URL, "redis://envhost:6379")
	}
}

func TestApplyEnvOverrides_JWTSecret(t *testing.T) {
	os.Setenv("JWT_SECRET", "env-jwt-secret-value")
	defer os.Unsetenv("JWT_SECRET")

	cfg, _ := Load("/nonexistent")
	if cfg.Auth.JWTSecret != "env-jwt-secret-value" {
		t.Errorf("JWTSecret = %q, want %q", cfg.Auth.JWTSecret, "env-jwt-secret-value")
	}
}

func TestApplyEnvOverrides_MasterEncryptionKey(t *testing.T) {
	os.Setenv("MASTER_ENCRYPTION_KEY", "env-master-key-value")
	defer os.Unsetenv("MASTER_ENCRYPTION_KEY")

	cfg, _ := Load("/nonexistent")
	if cfg.Auth.MasterEncryptionKey != "env-master-key-value" {
		t.Errorf("MasterEncryptionKey = %q, want %q", cfg.Auth.MasterEncryptionKey, "env-master-key-value")
	}
}

func TestApplyEnvOverrides_DeepSeekAPIKey(t *testing.T) {
	os.Setenv("DEEPSEEK_API_KEY", "sk-deepseek-test")
	defer os.Unsetenv("DEEPSEEK_API_KEY")

	cfg, _ := Load("/nonexistent")
	if cfg.LLM.Default.APIKey != "sk-deepseek-test" {
		t.Errorf("LLM.Default.APIKey = %q, want %q", cfg.LLM.Default.APIKey, "sk-deepseek-test")
	}
	// When BaseURL is empty, applyEnvOverrides should set defaults.
	if cfg.LLM.Default.Provider != "deepseek" {
		t.Errorf("LLM.Default.Provider = %q, want %q", cfg.LLM.Default.Provider, "deepseek")
	}
	if cfg.LLM.Default.BaseURL != "https://api.deepseek.com/v1" {
		t.Errorf("LLM.Default.BaseURL = %q, want %q", cfg.LLM.Default.BaseURL, "https://api.deepseek.com/v1")
	}
	if cfg.LLM.Default.Model != "deepseek-chat" {
		t.Errorf("LLM.Default.Model = %q, want %q", cfg.LLM.Default.Model, "deepseek-chat")
	}
}

func TestApplyEnvOverrides_DeepSeekAPIKey_ExistingBaseURL(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "config.yaml")
	content := []byte(`
llm:
  default:
    base_url: "https://custom.llm.api/v1"
    provider: "custom"
    model: "custom-model"
`)
	os.WriteFile(cfgPath, content, 0644)

	os.Setenv("DEEPSEEK_API_KEY", "sk-deepseek-test")
	defer os.Unsetenv("DEEPSEEK_API_KEY")

	cfg, _ := Load(cfgPath)
	// API key should be set from env.
	if cfg.LLM.Default.APIKey != "sk-deepseek-test" {
		t.Errorf("APIKey = %q, want %q", cfg.LLM.Default.APIKey, "sk-deepseek-test")
	}
	// BaseURL should NOT be overridden because it was set in the config file.
	if cfg.LLM.Default.BaseURL != "https://custom.llm.api/v1" {
		t.Errorf("BaseURL = %q, want %q", cfg.LLM.Default.BaseURL, "https://custom.llm.api/v1")
	}
	if cfg.LLM.Default.Provider != "custom" {
		t.Errorf("Provider = %q, want %q", cfg.LLM.Default.Provider, "custom")
	}
}

func TestApplyEnvOverrides_QwenAPIKey(t *testing.T) {
	os.Setenv("QWEN_API_KEY", "sk-qwen-test")
	defer os.Unsetenv("QWEN_API_KEY")

	cfg, _ := Load("/nonexistent")
	if cfg.LLM.Fallback.APIKey != "sk-qwen-test" {
		t.Errorf("LLM.Fallback.APIKey = %q, want %q", cfg.LLM.Fallback.APIKey, "sk-qwen-test")
	}
	if cfg.LLM.Fallback.Provider != "qwen" {
		t.Errorf("LLM.Fallback.Provider = %q, want %q", cfg.LLM.Fallback.Provider, "qwen")
	}
	if cfg.LLM.Fallback.BaseURL != "https://dashscope.aliyuncs.com/compatible-mode/v1" {
		t.Errorf("LLM.Fallback.BaseURL = %q, want %q", cfg.LLM.Fallback.BaseURL, "https://dashscope.aliyuncs.com/compatible-mode/v1")
	}
	if cfg.LLM.Fallback.Model != "qwen-plus" {
		t.Errorf("LLM.Fallback.Model = %q, want %q", cfg.LLM.Fallback.Model, "qwen-plus")
	}
}

func TestApplyEnvOverrides_ChromeWSURL(t *testing.T) {
	os.Setenv("CHROME_WS_URL", "ws://chrome:9222")
	defer os.Unsetenv("CHROME_WS_URL")

	cfg, _ := Load("/nonexistent")
	if cfg.Chrome.WSURL != "ws://chrome:9222" {
		t.Errorf("Chrome.WSURL = %q, want %q", cfg.Chrome.WSURL, "ws://chrome:9222")
	}
}

func TestApplyEnvOverrides_MinIOEndpoint(t *testing.T) {
	os.Setenv("MINIO_ENDPOINT", "minio.example.com:9000")
	defer os.Unsetenv("MINIO_ENDPOINT")

	cfg, _ := Load("/nonexistent")
	if cfg.MinIO.Endpoint != "minio.example.com:9000" {
		t.Errorf("MinIO.Endpoint = %q, want %q", cfg.MinIO.Endpoint, "minio.example.com:9000")
	}
}

func TestApplyEnvOverrides_MinIOAccessKey(t *testing.T) {
	os.Setenv("MINIO_ACCESS_KEY", "minioadmin")
	defer os.Unsetenv("MINIO_ACCESS_KEY")

	cfg, _ := Load("/nonexistent")
	if cfg.MinIO.AccessKey != "minioadmin" {
		t.Errorf("MinIO.AccessKey = %q, want %q", cfg.MinIO.AccessKey, "minioadmin")
	}
}

func TestApplyEnvOverrides_MinIOSecretKey(t *testing.T) {
	os.Setenv("MINIO_SECRET_KEY", "miniosecret123")
	defer os.Unsetenv("MINIO_SECRET_KEY")

	cfg, _ := Load("/nonexistent")
	if cfg.MinIO.SecretKey != "miniosecret123" {
		t.Errorf("MinIO.SecretKey = %q, want %q", cfg.MinIO.SecretKey, "miniosecret123")
	}
}

func TestApplyEnvOverrides_Port(t *testing.T) {
	os.Setenv("PORT", "3000")
	defer os.Unsetenv("PORT")

	cfg, _ := Load("/nonexistent")
	if cfg.Server.Port != 3000 {
		t.Errorf("Port = %d, want 3000", cfg.Server.Port)
	}
}

func TestApplyEnvOverrides_LogLevel(t *testing.T) {
	os.Setenv("LOG_LEVEL", "warn")
	defer os.Unsetenv("LOG_LEVEL")

	cfg, _ := Load("/nonexistent")
	if cfg.Log.Level != "warn" {
		t.Errorf("LogLevel = %q, want %q", cfg.Log.Level, "warn")
	}
}

func TestApplyEnvOverrides_LogFormat(t *testing.T) {
	os.Setenv("LOG_FORMAT", "text")
	defer os.Unsetenv("LOG_FORMAT")

	cfg, _ := Load("/nonexistent")
	if cfg.Log.Format != "text" {
		t.Errorf("LogFormat = %q, want %q", cfg.Log.Format, "text")
	}
}

func TestApplyEnvOverrides_NoEnvVars(t *testing.T) {
	// Clear all relevant env vars to ensure defaults are not affected.
	envVars := []string{
		"DATABASE_URL", "REDIS_URL", "JWT_SECRET", "MASTER_ENCRYPTION_KEY",
		"DEEPSEEK_API_KEY", "QWEN_API_KEY", "CHROME_WS_URL",
		"MINIO_ENDPOINT", "MINIO_ACCESS_KEY", "MINIO_SECRET_KEY",
		"PORT", "LOG_LEVEL", "LOG_FORMAT",
	}
	for _, v := range envVars {
		os.Unsetenv(v)
	}

	cfg, _ := Load("/nonexistent")
	if cfg.Server.Port != 8080 {
		t.Errorf("Port = %d, want 8080 (default)", cfg.Server.Port)
	}
	if cfg.Database.URL != "" {
		t.Errorf("Database.URL = %q, want empty (default)", cfg.Database.URL)
	}
	if cfg.Auth.JWTSecret != "" {
		t.Errorf("JWTSecret = %q, want empty (default)", cfg.Auth.JWTSecret)
	}
}
