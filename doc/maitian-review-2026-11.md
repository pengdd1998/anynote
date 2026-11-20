# 麦田（mdldm-maitian）评审 — 对 AnyNote 发布链路的借鉴分析

- **评审日期**: 2026-11-21
- **评审对象**: github.com/CzzzzzzJ/mdldm-maitian（MIT）、CzzzzzzJ/mdldm-maitian-publisher（Apache-2.0）
- **对照版本**: AnyNote main @ 713193e
- **结论**: 链路同构（一份内容 → 多平台发布），麦田在"平台知识沉淀的系统性"与"数据闭环"上领先 AnyNote 一个版本；七项可借鉴，其中两项一周内可落地。

---

## 一、双方形态对照

| | 麦田 | AnyNote |
|---|---|---|
| 定位 | 视频博主的多平台分发工作台 | 笔记应用，整合离散笔记产出平台内容 |
| 形态 | Mac 常驻 Node 服务 + Chrome 扩展操作用户已登录浏览器 | Flutter 客户端 + Go 服务端 chromedp + 加密凭据 |
| 发布执行 | 国内四家**只填写不发布**，人点最后一下 | 服务端 chromedp 自动发布 |
| 平台 | B站/小红书/抖音/视频号/YouTube/X/IG/自有站点 | 小红书/微信/知乎/Medium/WordPress/Webhook |
| 数据闭环 | 每期×每平台×每天采数、粉丝历史、UTM 归因、单期复盘、转化漏斗 | publish 日志 + 小红书 stats 采集（v2.8.5 起步） |

信任模型不同（浏览器真人登录 vs 服务端加密凭据），执行路线不互相照搬；但**发布前的知识层**（平台规则、合规校验、AI 写作差异化）与**发布后的数据层**（排期、采数、归因、复盘）完全可迁移。

## 二、可借鉴清单

### 1. 声明式平台规格表 + 发前校验（P0，直接移植）

`publisher/lib/bundle.js` 的 `PLATFORMS`：每平台字段与字数区间（小红书 title ≤20 / body ≤1000、B站 title ≤80 / desc ≤2000、视频号短标题 6–16 字…）、话题上限（抖音 max 5）、是否允许链接、hashtag 上限。`validate()` 逐平台校验并输出具体到字段的错误。

**AnyNote 现状**：`publish_handler.go` 只有通用校验（title ≤500、content ≤10MB、tags ≤50）——小红书 20 字标题限制完全没体现，超限会被平台拒绝且用户不知道原因。

### 2. 内容合规规则库（P0，实战沉淀直接抄）

`bundle.js` 校验器里的正则组，全部来自真实账号踩坑：

- 无链接平台检测 `https?://`、`www.`、常见域名后缀；
- 微信号引流检测（`微信[:：号]? + ID`、`加微`）；
- 引流话术检测（"评论区领"、"主页搜"、"点链接"等，命中即拦）；
- **模型/厂商名限流规避**：正文出现 `Claude|ChatGPT|GPT-?\d|Gemini|Anthropic|OpenAI|DeepSeek` 即拦，要求换"Agent、AI"代称（作者实测直接导致限流/封禁）。

### 3. "AI 写人可审中间格式 → 机械转换 → 校验"管线（P1，架构模式）

麦田的 AI 从不直接生成 JSON：先写人类可编辑的 `发布素材.md`（按平台分节、固定字段名），`make-publish.mjs` 确定性转换为 `publish.json`，校验不通过回改 md。三层各自职责：AI 产出内容、转换器保证结构、校验器保证合规。用户在 md 层审改（远比审 JSON 友好）。

**AnyNote 借鉴点**：compose（聚类→大纲→扩写→润色→发布）目前 AI 直出发布内容；在 compose→publish 之间加一个按平台分节的中间格式 + 确定性转换器。

### 4. 平台差异化 AI 提示词（P1）

`skills/maitian-publish/SKILL.md` 沉淀了各平台文风规则：小红书"写成跟朋友讲这周干了啥，少 emoji 少清单"；只有长文平台（B站/YouTube/X）放链接且链接带 `utm_campaign=主题-序号`（转化归因到某期）；标签第一个放账号名；视频号短标题 6–16 字。另有两层 skill 结构：通用 skill + 个人偏好 skill 覆盖（"先读 maitian-publish，再按本文件覆盖"）。

**AnyNote 借鉴点**：`compose/domain/prompt_builder.dart` 目前提示词平台无关；按平台差异化模板可从 SKILL.md 直接移植。

### 5. chromedp 平台坑知识库（P1，活文档）

`publisher/docs/platform-notes.md` 是持续维护的上传页自动化实录：B站"AIAgent"标签被静默拒绝、抖音话题需逐字输入+真实鼠标点击（整串 insertText 联想卡死）、视频号表单在 wujie-app Shadow DOM、小红书封面等视频传完才能编辑、Instagram 上传 bug 的运行时补丁等。

**AnyNote 借鉴点**：小红书 chromedp 适配器对抗同一批页面；建议建 `backend/internal/platform/docs/platform-notes.md` 活文档，每次修适配器追加一条实录。

### 6. 数据闭环：期级分发计划 + 归因 + 复盘（P2，蓝图）

- **期级分发计划**：一期内容 = 多平台排期；防重（同视频每平台只传一次，IG 还查定时内容页）；到点取链接回填记录；
- **UTM 归因**：链接带 `utm_campaign=主题-序号`，自有站点把注册/收入归因到某期某平台——闭环到钱；
- **时序采集**：每期×平台×天 views/likes/comments/favorites/shares；粉丝数历史（B站 90 天、小红书 30 天增减）；
- **单期复盘**：同龄对比（发布 N 天曲线对比）、转化漏斗；
- **登录预检**：批量执行前查各平台登录态，失效即通知并 20 分钟内自动补跑。

**AnyNote 借鉴点**：publish 日历已有雏形；按"内容期 → 平台计划 → 采数 → 复盘"补齐模型，把 stats.go 扩成每平台采集器集合。

### 7. 安全红线（P1，成文为适配器开发规范）

麦田红线：国内平台只填写不发布（人点最后一下）；同内容每平台只传一次（失败先确认未发出再重跑）；小红书只读页面、像人一样操作、低频、不调平台接口；不做评论/点赞/私信/关注自动化。

**AnyNote 借鉴点**：服务端自动发布路线下，"防重、低频、行为拟人、失败先核对平台侧状态"应写入适配器开发规范与 job 重试策略。

### 8. 媒体工程细节（P2，零散坑）

成片响度 -16 LUFS、`-movflags +faststart`（校验器读文件头判 moov 位置，否则小红书报无视频流）、IG 20min/1GB 限制自动转一版、封面 3:4/4:3/16:9 三比例（16:9 由 4:3 补模糊背景，ffmpeg 命令现成）。

## 三、不建议照搬

- **Chrome 扩展 + 用户浏览器路线**：与 AnyNote 服务端自动发布是不同信任模型，扩展的 CDP 技巧仅作选择器情报；
- **Node/Mac 常驻服务架构**：与 Flutter+Go 形态不符；
- **Obsidian 直读**：AnyNote 自身即笔记库。

## 四、落地路径

- **Phase 1（P0，本迭代）**：后端平台规格表 + 合规校验，接入发布链路——见 `tech-plan-2026-11-publish-spec.md`；
- **Phase 2（P1）**：compose 中间格式管线 + 平台差异化提示词；
- **Phase 3（P2）**：期级分发计划 + 数据闭环 + 复盘。
