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

## Phase 2 — compose 中间格式 + 平台差异化提示词

> 2026-11-23 已落地，范围与未做项见文末"执行记录"。

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

---

## 执行记录

### 2026-11-23 — Phase 2

**先修掉的两个回归**（不修则 Phase 2 无从验证）：

- `ccfae57` App 内发布全部失败：handler 把 `content_item_id` 当必填 UUID 且
  先于一切校验执行，而两个客户端调用点都不传。改为可选。
- `0f239f5` 明文库升级后打不开、存不了笔记：`sqlcipher_export` 不保留
  `user_version`，Drift 把升级后的库当新库重跑 onCreate。迁移换成
  `DbFileGuard`，并加 CI 硬门槛（数据库套件必须在真 SQLCipher 上跑）。
- `7722fe5` 顺带修掉 5 个被 `continue-on-error` 掩盖的前端测试失败：
  `VersionDiffScreen` 在 `initState` 里读本地化字符串，debug 构建下一打开
  就是错误态（正式版不受影响），另有两个测试还按旧的通用错误文案断言。

> 当时前端全量测试有 **45 个既有失败**（TTS、BIP-39、登录页等，9 月基线
> `6db31ad` 的 CI 就是这 45 个），CI 的 `flutter test` 步骤是
> `continue-on-error`，不构成门槛。已随 v2.8.10 全部修复，见下一节。

**1. 平台词汇与规则同源**

- compose 的目标平台由写死的 `generic | xhs | twitter | blog | linkedin`
  改为 `generic` + 服务端 `GET /api/v1/publish/platforms` 的列表，id 与发布
  接口一致。webhook 只是投递管道、没有自己的读者，不作为创作目标。
- `platformGuidesProvider` 拉服务端规则；`currentPlatformGuidesProvider`
  是它的同步视图（服务端未到时用内置表）。创作各步在调用模型前等服务端
  规则，最多 3 秒（`platformRulesTimeoutProvider`），超时用内置表。
- `PromptBuilder` 的大纲 / 扩写 / 适配文风 / 润色四个提示词都注入平台写作
  指导（服务端 `Spec.Guidance`）和硬上限（标题、正文、标签、链接）。此前
  **扩写提示词完全不带平台**，成稿默认平台无关。
- 服务端指导补充一条：小红书 / 公众号 / 知乎的正文是纯文本——发布时逐字
  输入编辑器，Markdown 标记会原样出现在读者面前。

**2. 中间格式与确定性转换**

- 成稿布局（提示词明确要求，`PlatformDraft.parse` 确定性解析）：第一行
  `# 标题`，然后正文，最后一行只放 `#话题`。模型不产出 JSON，用户删掉标题行
  或手敲标签也能被识别。
- 交接发布时按布局拆成 title / content / tags，并带上创作时选的平台
  （`PublishFromEditorSheet.initialPlatform`；该平台未连接则不预选）。
  修掉三个交接缺陷：标题行在正文里重复一遍、标签恒为空、平台选择丢失。
- 润色提示词要求保持布局、只输出正文本身，避免"以下是修改后的稿子"这类
  前后缀被发布出去。

**3. 编辑期提示**

- 发布面板（`b8b1e32`）：逐条展示 problems / warnings；每个字段按平台上限
  显示字数；输入时防抖预校验，过期结果丢弃；打开即校验一次。
- 创作编辑器底栏：平台名 + 正文字数 / 上限；通用风格仍显示词数。"适配文风"
  在通用风格下禁用——没有可适配的对象。

**未做，留待下一步**

- **按平台分槽的多版本草稿**（上文"每平台一份"）：一次会话仍是单稿，
  "适配文风"会覆盖原稿。建议设计：`ComposeSessionState` 增加
  `platformDrafts: Map<platformId, text>` 与按槽位的润色历史，编辑器用平台
  chip 切换槽位，切到尚无稿的平台时才触发"适配"（一次 AI 调用，先确认消耗
  额度），发布用当前槽位。需要先定产品交互（以哪一版为底稿、是否确认消耗
  额度），且 notifier 与编辑器改动面大，没有真机验证不宜贸然做。
- WordPress 适配器把 content 原样交给 REST API（期望 HTML），AI 产出的
  Markdown 会在站点上原样显示。应在适配器内做 Markdown → HTML 转换。
- 创作编辑器内不做服务端实时校验：发布面板一步之遥且规则相同，编辑器只给
  离线即可判断的字数信号。
- 知乎链接的 UTM 归因属于 Phase 3。

### 2026-11-24 — v2.8.10

**45 个既有前端测试失败全部修复**（`2992771`、`64a0403`），前端全量测试
首次全绿：

- 20 个语音朗读测试：服务早已改用 flutter_tts，测试仍按更早的定时器模拟
  来写，也没有插件的平台通道。补了 `test/helpers/fake_tts_engine.dart`；
  过程中发现并修复 `SpeechService.dispose()` 不终止朗读循环、会往已关闭的
  流里写事件。
- 12 个加密测试：`setUpAll` 先注册测试用的 libsodium 加载器，再调
  `CryptoCompat.init()`，后者按宿主系统注册了正式加载器，把前者覆盖掉。
  调整了顺序。
- 13 个界面测试断言的是改版前的结构（登录/注册页、搜索入口、专注模式
  按钮、卡片标题行数、平台连接页空状态），改为按文案或语义查找。

**门槛**：

- CI 的 `flutter test` 不再 `continue-on-error`（`f60ad8c`）。
- CI 的 analyze 步骤加 `pipefail`（`2338b35`）。此前告警被管道吞掉而 CD 按
  退出码拒绝，v2.8.10 的第一次部署因此被跳过。
- `mobile-qa.yml` 新增 `id_suffix` 输入（`730af46`）：设备上已有不同签名的
  旧 QA 包时，无需卸载即可并存安装。

**真机验证（Note 9，测试账号）**：

- 明文库 → 加密库升级：以已发布的 v2.8.9（明文 SQLite）做 fixture 装入
  `.qa2`，登录、同步 2 条笔记、新建 1 条；覆盖安装新构建后 3 条笔记俱在、
  登录态保持，新建笔记保存成功，搜索命中。
- 正式版原地升级：手机上的正式版原是 11-20 装的 2.8.0 测试构建（从明文库
  升级后存不了笔记的状态）。覆盖安装 v2.8.10 后登录态保持，新建笔记保存
  成功；下拉刷新后账号在服务器上的笔记全部同步回来，搜索命中，版本显示
  2.8.10 (4081)。
- 创作页的目标平台即服务端的平台列表（部署后服务器日志里
  `GET /api/v1/publish/platforms` 返回 200）。
- 发现并修复：AI 额度用尽时聚类页直接显示 `quota_exceeded`（`bbac745`）。

**未能验证**：AI 成稿 → 发布交接（测试账号的 AI 额度已用尽）；发布到真实
平台（测试账号未连接任何平台）。

**发版结果**：标签 `v2.8.10` → `2338b35`。Android 正式包在 GitHub Release；
后端已部署（`/health` 返回 2.8.10，预部署备份已生成，共享基础设施容器未
动）；iOS 构建照旧失败（没有签名配置）。部署过程踩到三个环境问题，均重跑
解决：CD 的 analyze 对告警敏感（`2338b35`）；runner 到 VPS 的 SSH 握手被
重置（服务器 sshd 持续受公网爆破，未认证连接占满并发槽）；VPS 从 ghcr.io
拉 server 镜像只有 KB/s 量级。
