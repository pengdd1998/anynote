package xiaohongshu

import (
	"testing"
)

func TestParseChineseCount(t *testing.T) {
	tests := []struct {
		in   string
		want int
	}{
		{"", 0},
		{"  ", 0},
		{"0", 0},
		{"123", 123},
		{"1,234", 1234},
		{"1.2万", 12000},
		{"10万", 100000},
		{"1.5万", 15000},
		{"2.3千", 2300},
		{"1.2k", 1200},
		{"3W", 30000},
		{"abc", 0},
		{"赞", 0},
	}
	for _, tt := range tests {
		if got := parseChineseCount(tt.in); got != tt.want {
			t.Errorf("parseChineseCount(%q) = %d, want %d", tt.in, got, tt.want)
		}
	}
}

func TestParseCountField(t *testing.T) {
	m := map[string]interface{}{
		"likeCount":    float64(42),
		"commentCount": "1.2万",
	}
	if got := parseCountField(m, "likeCount"); got != 42 {
		t.Errorf("likeCount = %d, want 42", got)
	}
	if got := parseCountField(m, "commentCount"); got != 12000 {
		t.Errorf("commentCount = %d, want 12000", got)
	}
	if got := parseCountField(m, "missing", "alsoMissing"); got != 0 {
		t.Errorf("missing = %d, want 0", got)
	}
}

func TestResolvePostURL(t *testing.T) {
	if got := resolvePostURL("abc123"); got != postBaseURL+"abc123" {
		t.Errorf("resolvePostURL(id) = %q", got)
	}
	full := "https://www.xiaohongshu.com/explore/xyz?source=web"
	if got := resolvePostURL(full); got != full {
		t.Errorf("resolvePostURL(url) = %q, want unchanged", got)
	}
}
