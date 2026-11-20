package spec

import (
	"strings"
	"testing"
)

func TestFor_KnownAndUnknownPlatforms(t *testing.T) {
	if _, ok := For("xiaohongshu"); !ok {
		t.Fatal("xiaohongshu should have a spec")
	}
	if _, ok := For("does-not-exist"); ok {
		t.Fatal("unknown platform should not have a spec")
	}
	// Every supported platform must declare title and content field specs.
	for _, id := range Supported() {
		s, _ := For(id)
		if _, ok := s.Fields["title"]; !ok {
			t.Errorf("%s: missing title field spec", id)
		}
		if _, ok := s.Fields["content"]; !ok {
			t.Errorf("%s: missing content field spec", id)
		}
	}
}

func TestValidate_FieldLengths(t *testing.T) {
	s, _ := For("xiaohongshu")

	// 20 runes exactly at the limit: pass.
	problems := Validate(s, strings.Repeat("好", 20), "正文", nil)
	if len(Errors(problems)) != 0 {
		t.Fatalf("20-rune title should pass, got %v", problems)
	}

	// 21 runes: blocked with a rune-correct count.
	problems = Validate(s, strings.Repeat("好", 21), "正文", nil)
	errs := Errors(problems)
	if len(errs) != 1 {
		t.Fatalf("21-rune title should produce exactly one error, got %v", problems)
	}
	if !strings.Contains(errs[0].Message, "21") {
		t.Errorf("error should report rune count 21, got %q", errs[0].Message)
	}

	// Byte-length trap: 10 Chinese runes = 30 bytes. A byte-based check
	// would wrongly report 30; rune-based must pass a 20-rune CJK title.
	problems = Validate(s, strings.Repeat("标", 20), "内容", nil)
	if len(Errors(problems)) != 0 {
		t.Fatalf("20-rune CJK title must pass (rune counting), got %v", problems)
	}
}

func TestValidate_LinkPolicy(t *testing.T) {
	xhs, _ := For("xiaohongshu")
	zhihu, _ := For("zhihu")

	// No-link platform: URL in content is blocked.
	problems := Validate(xhs, "标题", "看这里 https://example.com/post", nil)
	errs := Errors(problems)
	if len(errs) == 0 || !strings.Contains(errs[0].Message, "链接") {
		t.Fatalf("xhs with URL should be blocked with a link error, got %v", problems)
	}

	// Long-form platform: URL is fine.
	if errs := Errors(Validate(zhihu, "标题", "参考 https://example.com/post", nil)); len(errs) != 0 {
		t.Fatalf("zhihu with URL should pass, got %v", errs)
	}
}

func TestValidate_WechatAndLeadGen(t *testing.T) {
	xhs, _ := For("xiaohongshu")

	problems := Validate(xhs, "标题", "加我微信: abc12345 领取资料", nil)
	errs := Errors(problems)
	foundWechat, foundLead := false, false
	for _, e := range errs {
		if strings.Contains(e.Message, "微信号") {
			foundWechat = true
		}
		if strings.Contains(e.Message, "引流") {
			foundLead = true
		}
	}
	if !foundWechat || !foundLead {
		t.Fatalf("wechat-id + lead phrases should both be blocked, got %v", problems)
	}

	// Mentioning 微信 without an ID is only a warning-class concern.
	problems = Validate(xhs, "标题", "微信上很火的话题", nil)
	for _, p := range Errors(problems) {
		if strings.Contains(p.Message, "微信号") {
			t.Errorf("plain 微信 mention should not be an error, got %v", p)
		}
	}
}

func TestValidate_ModelVendorNames(t *testing.T) {
	xhs, _ := For("xiaohongshu")
	zhihu, _ := For("zhihu")

	// No-link domestic platform: model names blocked.
	problems := Validate(xhs, "标题", "用 ChatGPT 写了一篇笔记", nil)
	if len(Errors(problems)) == 0 {
		t.Fatal("model vendor name on xhs should be blocked")
	}

	// Long-form platform: allowed.
	if errs := Errors(Validate(zhihu, "标题", "用 ChatGPT 写了一篇笔记", nil)); len(errs) != 0 {
		t.Fatalf("model vendor name on zhihu should pass, got %v", errs)
	}
}

func TestValidate_TagLimits(t *testing.T) {
	xhs, _ := For("xiaohongshu")

	tooMany := []string{"一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一"}
	problems := Validate(xhs, "标题", "正文", tooMany)
	errs := Errors(problems)
	if len(errs) == 0 || !strings.Contains(errs[0].Message, "标签") {
		t.Fatalf("over-limit tags should be blocked, got %v", problems)
	}

	// Long tag is a warning only.
	problems = Validate(xhs, "标题", "正文", []string{strings.Repeat("长", 25)})
	if len(Errors(problems)) != 0 {
		t.Fatalf("a long tag should be a warning, not an error: %v", problems)
	}
	if len(Warnings(problems)) == 0 {
		t.Fatal("a long tag should produce a warning")
	}
}

func TestValidate_ErrorsBeforeWarnings(t *testing.T) {
	xhs, _ := For("xiaohongshu")
	// URL (error) + long tag (warning): errors come first.
	problems := Validate(xhs, "标题", "看 https://example.com", []string{strings.Repeat("长", 25)})
	if len(problems) < 2 {
		t.Fatalf("expected both an error and a warning, got %v", problems)
	}
	if problems[0].Severity != SeverityError {
		t.Errorf("first problem should be the error, got %v", problems[0])
	}
}
