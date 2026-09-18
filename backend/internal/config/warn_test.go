package config

import "testing"

// Warn must run to completion on a variety of misconfigurations without
// panicking: it only emits warnings and never mutates the config.
func TestWarn_DoesNotPanic(t *testing.T) {
	cases := map[string]*Config{
		"empty":                 {},
		"bad redis scheme":      {Redis: RedisConfig{URL: "http://wrong-scheme:6379"}},
		"good redis scheme":     {Redis: RedisConfig{URL: "redis://localhost:6379"}},
		"missing firebase file": {Firebase: FirebaseConfig{CredentialsFile: "/nonexistent/fcm.json"}},
		"bad llm base url": {LLM: LLMConfig{
			Default: LLMProviderConfig{BaseURL: "not a url"},
		}},
	}
	for name, cfg := range cases {
		t.Run(name, func(t *testing.T) {
			// Must not panic; warnings go to the standard logger.
			cfg.Warn()
			if cfg == nil {
				t.Fatal("config became nil")
			}
		})
	}
}
