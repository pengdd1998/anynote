package config

import (
	"fmt"
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

// Config holds all application configuration.
type Config struct {
	Server   ServerConfig   `yaml:"server"`
	Database DatabaseConfig `yaml:"database"`
	Redis    RedisConfig    `yaml:"redis"`
	MinIO    MinIOConfig    `yaml:"minio"`
	Auth     AuthConfig     `yaml:"auth"`
	LLM      LLMConfig      `yaml:"llm"`
	Chrome   ChromeConfig   `yaml:"chrome"`
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

// Load reads config from file and environment variables.
func Load(path string) (*Config, error) {
	cfg := &Config{
		Server: ServerConfig{
			Port:         8080,
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 120 * time.Second, // Long for SSE streaming
			AllowOrigins: []string{"*"},
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
}
