// Package spec holds the per-platform publishing rules (field length limits,
// link policies, content-compliance checks) applied before a publish request
// enters the job queue.
//
// Rules are adapted from maitian (github.com/CzzzzzzJ/mdldm-maitian,
// MIT) — a multi-platform publishing workbench — where they were validated
// against real accounts; see doc/maitian-review-2026-11.md §二.1/§二.2.
package spec

import (
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"
)

// FieldSpec is the acceptable length range (in runes) for one content field.
type FieldSpec struct {
	Min int
	Max int
}

// Spec is the publishing rule set for one platform.
type Spec struct {
	ID           string
	Name         string
	Fields       map[string]FieldSpec
	MaxTags      int
	LinksAllowed bool
	// Notes documents platform quirks worth remembering when touching the
	// adapter for this platform.
	Notes string
	// Guidance is the writing brief for this platform: what the AI writing
	// step is told, and what the editor shows as hints. Each item is one
	// self-contained sentence, ordered the way a writer works (audience and
	// tone first, structure, then the things that get a post rejected).
	Guidance []string
}

// Guide is the client-facing view of a [Spec]: the limits an editor enforces
// while the user types, plus the writing brief.
type Guide struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	TitleMax     int      `json:"title_max"`
	ContentMax   int      `json:"content_max"`
	MaxTags      int      `json:"max_tags"`
	LinksAllowed bool     `json:"links_allowed"`
	Guidance     []string `json:"guidance"`
}

// Guides lists every supported platform with a declared spec, in a stable
// order (the order the client offers them in).
func Guides() []Guide {
	ids := []string{"xiaohongshu", "wechat", "zhihu", "medium", "wordpress", "webhook"}
	out := make([]Guide, 0, len(ids))
	for _, id := range ids {
		s, ok := specs[id]
		if !ok {
			continue
		}
		out = append(out, Guide{
			ID:           s.ID,
			Name:         s.Name,
			TitleMax:     s.Fields["title"].Max,
			ContentMax:   s.Fields["content"].Max,
			MaxTags:      s.MaxTags,
			LinksAllowed: s.LinksAllowed,
			Guidance:     s.Guidance,
		})
	}
	return out
}

// Severity of a validation problem: "error" blocks the publish, "warning"
// is passed through to the client for display only.
type Severity string

const (
	SeverityError   Severity = "error"
	SeverityWarning Severity = "warning"
)

// Problem is one validation finding.
type Problem struct {
	Field    string   `json:"field"`
	Severity Severity `json:"severity"`
	Message  string   `json:"message"`
}

// specs declares every platform AnyNote can publish to. Rules follow the
// platforms' real creator-side limits; when a platform is unknown here the
// publish handler falls back to its generic transport caps.
var specs = map[string]Spec{
	"xiaohongshu": {
		ID:   "xiaohongshu",
		Name: "小红书",
		Fields: map[string]FieldSpec{
			"title":   {Min: 1, Max: 20},
			"content": {Min: 1, Max: 1000},
		},
		MaxTags:      10,
		LinksAllowed: false,
		Notes:        "无链接平台：限流最凶。标题超 20 字会被平台截断；正文不放链接/微信号/引流话术。",
		Guidance: []string{
			"写给刷手机的人：像跟朋友讲这周干了什么，第一句就要让人想点开。",
			"口语化短句和分段，少用 emoji、少列清单；用真实例子和踩过的坑代替说理。",
			"标题 20 字以内，直接说结论或好处，不做标题党。",
			"正文 1000 字以内；末尾放 3 到 5 个 #话题，第一个是账号名。",
			"不能出现链接、微信号或“评论区领、主页搜”这类引流话术。",
			"不要写 AI 模型或厂商的名字（如 Claude、ChatGPT、GPT、Gemini），统称 Agent 或 AI，否则会被限流。",
		},
	},
	"wechat": {
		ID:   "wechat",
		Name: "微信公众号",
		Fields: map[string]FieldSpec{
			"title":   {Min: 1, Max: 64},
			"content": {Min: 1, Max: 20000},
		},
		MaxTags:      10,
		LinksAllowed: true,
		Notes:        "长文平台，链接可放；标题上限 64 字。",
		Guidance: []string{
			"写给订阅了公众号的读者：可以展开讲，一篇文章讲透一个主题。",
			"开头一两段交代这篇文章解决什么问题，再用小标题分节。",
			"标题 64 字以内；重要结论放段落开头，方便只扫小标题的读者。",
			"正文 20000 字以内；可以放链接和参考出处。",
		},
	},
	"zhihu": {
		ID:   "zhihu",
		Name: "知乎",
		Fields: map[string]FieldSpec{
			"title":   {Min: 1, Max: 100},
			"content": {Min: 1, Max: 50000},
		},
		MaxTags:      10,
		LinksAllowed: true,
		Notes:        "长文平台，链接可放。",
		Guidance: []string{
			"写给带着问题来搜索的人：先给结论，再给论证和细节。",
			"用小标题组织论证；有数据、来源或延伸阅读就放链接。",
			"标题 100 字以内，用具体的问句或判断，不用空泛的大词。",
			"正文 50000 字以内，长文优先于短文。",
		},
	},
	"medium": {
		ID:   "medium",
		Name: "Medium",
		Fields: map[string]FieldSpec{
			"title":   {Min: 1, Max: 150},
			"content": {Min: 1, Max: 50000},
		},
		MaxTags:      5,
		LinksAllowed: true,
		Notes:        "Medium 标签最多 5 个。",
		Guidance: []string{
			"写给愿意读长文的英文或跨语言读者：一个清晰的主线，段落短。",
			"用小标题和空行留白；开头先讲为什么这个问题值得关心。",
			"标题 150 字以内；标签最多 5 个，只放真正相关的。",
			"正文 50000 字以内；可以放链接。",
		},
	},
	"wordpress": {
		ID:   "wordpress",
		Name: "WordPress",
		Fields: map[string]FieldSpec{
			"title":   {Min: 1, Max: 200},
			"content": {Min: 1, Max: 100000},
		},
		MaxTags:      30,
		LinksAllowed: true,
		Notes:        "自托管站点，规则最宽松。",
		Guidance: []string{
			"写给通过搜索引擎或订阅来到博客的读者：结构清晰，便于长期阅读。",
			"使用小标题、列表和代码块；给出可操作的步骤。",
			"标题 200 字以内；标签最多 30 个，优先复用已有的分类和标签。",
			"正文 100000 字以内；可以放链接和图片。",
		},
	},
	"webhook": {
		ID:   "webhook",
		Name: "Webhook",
		Fields: map[string]FieldSpec{
			"title":   {Min: 0, Max: 500},
			"content": {Min: 1, Max: 10000000},
		},
		MaxTags:      50,
		LinksAllowed: true,
		Notes:        "自托管管道透传，只保留传输层上限。",
		Guidance: []string{
			"透传到你自己的接口，内容格式由接收方决定。",
			"保持纯文本或 Markdown，不要包含平台特有的排版。",
		},
	},
}

// For returns the publishing spec for a platform. ok is false for platforms
// without a declared spec (the caller then keeps its generic caps only).
func For(platform string) (Spec, bool) {
	s, ok := specs[platform]
	return s, ok
}

// Supported lists the platform IDs that have a declared spec.
func Supported() []string {
	out := make([]string, 0, len(specs))
	for id := range specs {
		out = append(out, id)
	}
	return out
}

// Link detection: any URL-ish token (https links, www., bare domains).
var reURL = regexp.MustCompile(`(?i)https?://|www\.|\.(com|cn|net|club|io|org)\b`)

// WeChat-ID lead detection: 微信号/加微 patterns copied from maitian bundle.js.
var reWechatID = regexp.MustCompile(`(微信|vx|v信|wx)\s*[:：号]?\s*[A-Za-z][-_A-Za-z0-9]{5,}|加微`)

// Lead-gen phrases ("评论区领", "主页搜", "点链接", …), also from maitian.
var reLead = regexp.MustCompile(`评论区.{0,8}(链接|领|拿|看)|主页.{0,8}(搜|看|找)|点(击)?链接|戳链接|私信.{0,4}(领|拿|回复)`)

// Model/vendor names trigger throttling/bans on domestic no-link platforms
// (maitian: 2026-11-12, 实测); use Agent/AI 代称 instead.
var reModelVendor = regexp.MustCompile(`(?i)Claude|Codex|ChatGPT|GPT-?\d|Gemini|Anthropic|OpenAI|DeepSeek`)

// runeLen counts runes, not bytes — Chinese text must count one per glyph.
func runeLen(s string) int { return utf8.RuneCountInString(s) }

// Validate applies the platform spec to a publish payload and returns the
// findings ordered errors-first. severity=error findings block the publish;
// severity=warning ones are informational.
func Validate(s Spec, title, content string, tags []string) []Problem {
	var problems []Problem

	add := func(field string, sev Severity, format string, args ...any) {
		problems = append(problems, Problem{
			Field:    field,
			Severity: sev,
			Message:  fmt.Sprintf(format, args...),
		})
	}

	// -- Field length limits (rune-based) ------------------------------
	for field, value := range map[string]string{"title": title, "content": content} {
		fs := s.Fields[field]
		n := runeLen(value)
		if fs.Min > 0 && n < fs.Min {
			add(field, SeverityError, "%s：%s 至少 %d 字（当前 %d 字）", s.Name, fieldLabel(field), fs.Min, n)
		} else if fs.Max > 0 && n > fs.Max {
			add(field, SeverityError, "%s：%s 超过上限 %d 字（当前 %d 字），请精简后再发布", s.Name, fieldLabel(field), fs.Max, n)
		}
	}

	// -- Tag limits ----------------------------------------------------
	if s.MaxTags > 0 && len(tags) > s.MaxTags {
		add("tags", SeverityError, "%s：标签最多 %d 个（当前 %d 个）", s.Name, s.MaxTags, len(tags))
	}
	for _, tag := range tags {
		if n := runeLen(tag); n > 20 {
			add("tags", SeverityWarning, "%s：标签「%s」%d 字，过长的话题通常不会被平台收录为正式话题", s.Name, tag, n)
		}
	}

	// -- Content compliance (applies to title + content + tags together) --
	all := strings.Join([]string{title, content, strings.Join(tags, " ")}, "\n")

	if !s.LinksAllowed {
		if reURL.MatchString(all) {
			add("content", SeverityError, "%s：正文包含链接，%s不允许放链接，请移除或改为「整理成文档了，私信我」", s.Name, s.Name)
		}
		if reWechatID.MatchString(all) {
			add("content", SeverityError, "%s：正文包含微信号引流，%s不允许放微信号", s.Name, s.Name)
		}
		if m := reModelVendor.FindString(all); m != "" {
			add("content", SeverityError, "%s：出现模型/厂商名「%s」，直接写会被限流，请改用 Agent、AI 这类代称", s.Name, m)
		}
		if reLead.MatchString(all) {
			add("content", SeverityError, "%s：正文疑似引流话术「%s」，%s最多写到「整理成文档了，私信我」", s.Name, reLead.FindString(all), s.Name)
		}
	} else {
		// Long-form platforms allow links, but aggressive lead-gen still
		// deserves a warning.
		if reWechatID.MatchString(all) {
			add("content", SeverityWarning, "%s：正文包含微信号，确认符合该平台的引流规范", s.Name)
		}
		if reLead.MatchString(all) {
			add("content", SeverityWarning, "%s：正文疑似引流话术「%s」，请确认", s.Name, reLead.FindString(all))
		}
	}

	// Errors first, then warnings — the handler blocks on the first error.
	var errs, warns []Problem
	for _, p := range problems {
		if p.Severity == SeverityError {
			errs = append(errs, p)
		} else {
			warns = append(warns, p)
		}
	}
	return append(errs, warns...)
}

// Errors returns only the blocking findings.
func Errors(problems []Problem) []Problem {
	var out []Problem
	for _, p := range problems {
		if p.Severity == SeverityError {
			out = append(out, p)
		}
	}
	return out
}

// Warnings returns only the informational findings.
func Warnings(problems []Problem) []Problem {
	var out []Problem
	for _, p := range problems {
		if p.Severity == SeverityWarning {
			out = append(out, p)
		}
	}
	return out
}

func fieldLabel(field string) string {
	if field == "title" {
		return "标题"
	}
	return "正文"
}
