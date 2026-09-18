package appsetup

import (
	"testing"

	"github.com/anynote/backend/internal/platform"
)

// RegisterDefaultAdapters must register the six built-in platform adapters
// under their wire names, so GET /api/v1/platforms/catalog can enumerate them.
func TestRegisterDefaultAdapters(t *testing.T) {
	registry := platform.NewRegistry()
	RegisterDefaultAdapters(registry, "ws://chrome:9222")

	want := []string{
		"xiaohongshu",
		"wechat",
		"zhihu",
		"medium",
		"wordpress",
		"webhook",
	}
	got := registry.List()
	if len(got) != len(want) {
		t.Fatalf("registered %d adapters, want %d: %v", len(got), len(want), got)
	}
	for _, name := range want {
		if _, err := registry.Get(name); err != nil {
			t.Errorf("adapter %q not registered: %v", name, err)
		}
	}
}
