# 技术实施方案 — 平台发布规格表与合规校验（借鉴麦田 Phase 1）

> 配套评审：`maitian-review-2026-11.md`（§二.1/§二.2）。本期只做发布链路的
> "知识层"：一张声明式平台规格表 + 一组合规校验规则 + 接入发布链路。
> Phase 2（compose 中间格式 + 平台差异化提示词）与 Phase 3（期级分发计划 +
> 数据闭环）见文末路线。

---

## 1. 现状（main @ 713193e 实测）

- 发布入口 `POST /api/v1/publish`（`publish_handler.go`）：仅通用校验——
  title ≤500 字符（`len()` 字节数）、content ≤10MB、tags ≤50 个。
- 平台差异规则缺失：小红书 title 上限 20 字、无链接平台策略、引流话术、
  模型厂商名限流规避——全部没有。超限内容由平台侧拒绝，用户无感知原因。
- 六平台：xiaohongshu / wechat / zhihu / medium / wordpress / webhook
  （`platform/registry.go`）。

## 2. 目标

发布请求在进入队列前按**每平台规格**校验，失败返回具体到字段的错误；
合规规则（链接策略 / 引流话术 / 模型厂商名）拦截高风险内容并给出修改建议。
规则集中一处声明，前端发布页与 AI compose 后续可复用。

## 3. 设计

### 3.1 新包 `backend/internal/platform/spec`

```go
type FieldSpec struct {
    Min int
    Max int
}
type Spec struct {
    ID           string
    Name         string
    Fields       map[string]FieldSpec   // title/content 等字段字数区间
    MinTags      int                     // 要求标签第一个是账号名时由调用方校验
    MaxTags      int
    LinksAllowed bool                    // false = 正文/标签禁链接
    Notes        string                  // 平台注意事项（文档化）
}
```

- `SpecFor(platform string) (Spec, bool)` —— 六平台规格：
  - xiaohongshu: title [1,20]，content [1,1000]，links=false（实测限流最凶）；
  - wechat(公众号): title [1,64]，content [1,20000]，links=true；
  - zhihu / medium: title [1,100]/[1,150]，长文平台，links=true；
  - wordpress / webhook: title [1,200]，content [1,100000]，links=true
    （webhook 是自托管管道，只保留通用上限）。
- `Validate(platform, title, content, tags []string) Problems`：
  - 字段字数（**按 rune 计**，中文一字一字；现 handler 的 `len()` 是字节数，
    中文 20 字标题被误算 60——顺带修正）；
  - 标签数上限、单标签长度；
  - links=false 平台：正文/标签含 `https?://`、`www.`、常见域名后缀 → 报错；
  - 微信号引流：`(微信|vx|v信|wx)\s*[:：号]?\s*[A-Za-z][-_A-Za-z0-9]{5,}` 或
    `加微` → 报错；仅提"微信"→ 警告；
  - 引流话术（`评论区.{0,8}(链接|领|拿)|主页.{0,8}(搜|看|找)|点链接|戳链接`
    等，抄麦田 LEAD 正则族并按知乎/公众号语境扩展）→ links=false 平台报错、
    links=true 平台警告；
  - 模型/厂商名（`Claude|Codex|ChatGPT|GPT-?\d|Gemini|Anthropic|OpenAI|
    DeepSeek`）→ 仅 links=false 平台报错（要求换 Agent/AI 代称），
    其余平台不拦。
- 返回 `[]Problem{ Field, Severity(error|warning), Message }`；error 拦截、
  warning 放行（由客户端提示）。

### 3.2 接入点

`publish_handler.Publish`：`IsValidPlatform` 之后调用
`spec.Validate(...)`；存在 error 级 Problem 时返回
`400 validation_error`，body 携带 problems 数组（字段/严重度/消息），
前端可直接渲染。warning 级附在 200 响应的 `warnings` 字段透传。

### 3.3 字数口径修正

现 handler 的 `len(req.Title) > 500` 是字节长度——中文标题 167 字即误拦。
统一改为 `utf8.RuneCountInString`，与 spec 校验一致。

### 3.4 前端

`publish_screen.dart`：400 响应的 problems 数组逐条展示在平台卡片错误区
（现仅展示通用 error message）。本期仅做错误透传展示，不做编辑期实时校验
（Phase 2 的 compose 管线再考虑实时提示）。

## 4. 不做的事（本期）

- 不改适配器内部实现（发布执行逻辑不动）；
- 不做 compose 中间格式与平台差异化提示词（Phase 2）；
- 不做期级分发计划/数据采集（Phase 3）；
- 视频类校验（faststart/时长/响度）：AnyNote 尚无视频发布，规则先写进
  spec 注释留位。

## 5. 测试

- `spec_test.go`：每平台字数边界（小红书 20/21 字）、链接检测、微信号、
  引流话术、模型名（仅 links=false 拦截）、rune 计数正确性；
- `publish_handler_test.go`：新增用例——小红书 25 字标题返回 400 且
  problems 带 field=title；无链接平台正文带 URL 返回 400；zhihu 长文带
  链接通过；warning 场景 200 且响应带 warnings。

## 6. 验收

- `go test ./internal/platform/spec/ ./internal/handler/ -count=1` 全绿；
- CI（Go Backend）全绿；
- 前端发布页对 400 problems 的展示为Phase 1 的最小实现（后续实时校验
  归 Phase 2）。

---

## Phase 2（下一迭代）— compose 中间格式 + 平台差异化提示词

1. 中间格式：compose 扩写产物落为"按平台分节"的发布草稿（title/content/
   tags 每平台一份），确认页逐平台审改后分平台提交；
2. `prompt_builder.dart` 注入平台差异化规则（小红书口语化、知乎长文放
   链接+UTM、标签首账号名——规则源自 maitian SKILL.md，与后端 spec 同源
   维护）；
3. AI 产出后前端调用同一套 spec 校验做实时提示。

## Phase 3（backlog）— 期级分发计划 + 数据闭环

1. 数据模型：内容期（content episode）→ 平台计划（platform plan）→
   发布记录 → 每日采数快照；
2. stats.go 扩展为每平台采集器集合（小红书已有，逐平台补）+ 粉丝历史；
3. UTM 归因规范（`utm_campaign=<主题>-<期号>`）与自有站点转化对接；
4. 单期复盘页：同龄对比曲线 + 平台卡片 + 转化漏斗。
