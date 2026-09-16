# Technical Implementation Plan — Sprint A/B/C (2026-09)

Grounded companion to `development-plan.md` Phases 124–133. Every item lists the
exact files/functions to touch, the data contracts, and the verification steps.
File references were verified against main @ 27683e2.

---

## Phase 124 — Platform Connection Bootstrap (G1)

### Current state (verified)
- Server registers 6 adapters in `backend/internal/appsetup/setup.go:22–31`:
  `xiaohongshu, wechat, zhihu, medium, wordpress, webhook`.
- `GET /api/v1/platforms` (handler → `PlatformService.List`) returns **connected
  connections only** — no catalog of available adapters.
- Client `ApiClient.connectPlatform(platform)` (`api_client.dart:474`) and the
  QR-dialog flow `_connect()` (`platform_connection_screen.dart:116`) already
  work — they are just unreachable from the empty state (no CTA), and the
  publish sheet's platform list has the same problem.

### Backend change (small)
`backend/internal/handler/platform.go` + `service/platform.go`:
1. Add `GET /api/v1/platforms/catalog` → `[{ "platform": "xiaohongshu",
   "display_name": "小红书", "connected": false }, …]`. Source: iterate
   `registry.List()`; LEFT JOIN `platform_connections` for the current user to
   set `connected`.
2. Register route in the existing platforms route group (next to
   `GET /platforms`).
3. Tests: table-driven handler test — zero connections returns 6 entries all
   `connected:false`; one connection marks exactly that row.

### Frontend change
`frontend/lib/features/settings/presentation/platform_connection_screen.dart`:
1. New `platformCatalogProvider` (FutureProvider) calling
   `ApiClient.listPlatformCatalog()` (new method, nil-slice tolerant like the
   other list endpoints).
2. Empty state: replace the passive "暂无可用平台" column with the catalog grid
   (6 cards, platform icon + name + 连接 button → existing `_connect` flow).
3. Non-empty state: append a "添加平台" section listing
   `catalog.where(!connected)`.
4. `frontend/lib/features/publish/presentation/publish_screen.dart` (and
   `publish_from_editor_sheet.dart`): when platform list is empty, inline
   prompt card "去连接平台" → `context.push('/settings/platforms')` (route
   already exists).

### Acceptance run-through
Fresh account → 平台连接 shows 6-platform catalog → tap 小红书 → QR dialog
(SSE) → scan on phone → verify → connected card. Publish sheet now offers
小红书. `go build ./... && go vet ./... && go test ./...` green; new handler
test included.

---

## Phase 125 — Prod Infra Repair + Backend Deploy (G2 + G8)

### Redis (1-line + hardening)
`backend/cmd/server/main.go:88–93` — `redisv9.NewClient(&redisv9.Options{Addr:
cfg.Redis.URL})` passes a `redis://user:pass@host:port` URL as `Addr`
(worker's `cmd/worker/main.go` already uses `ParseURL`). Fix:

```go
opt, err := redisv9.ParseURL(cfg.Redis.URL)
if err != nil { slog.Warn("invalid Redis URL, disabling Redis", "error", err) }
else { redisClient = redisv9.NewClient(opt); defer redisClient.Close() }
```

Same for `service.NewRedisRateLimiter` call site (pass the parsed client or
parse inside; check `service/rate_limit*.go` for a second URL-as-Addr).

### MinIO bucket
`minioBucketChecker` (`cmd/server/main.go:392+`) only *checks* the bucket.
Add an idempotent ensure step at startup (server or worker, whichever boots
the storage service):

```go
exists, _ := minioClient.BucketExists(ctx, bucket)
if !exists { if err := minioClient.MakeBucket(ctx, bucket); err != nil { …warn… } }
```

Alternative (no code): add a one-shot `minio/mc` init container to
`docker-compose.deploy.yml` creating `anynote` — do **both** (code makes new
envs self-healing; compose covers current prod immediately).

### Deploy + regression
1. CD pipeline → tag `v2.8.0` (ships this + llm_config merged-Update +
   resolver fallback + nil-slice fixes from 08-31).
2. Post-deploy checks: `/health` version; `/ready` → expect all ok;
   `docker logs anynote-server | grep -i redis` shows "Redis rate limiter
   initialized"; image sync round-trip between two devices (insert image in a
   note on device A, pull on device B).
3. G8 regression: `curl -X PUT …/llm/configs/{id} -d '{"is_default":true}'`
   then GET — name/model/api_key must be unchanged.

---

## Phase 126 — zh l10n Sweep (G7)

Verified leaks:
1. `note_detail_screen.dart:439` — hard-coded `'$minutes min read'` (the
   localized getters `minutesRead`/`lessThan1Min` already exist in
   app_localizations_en.dart:3262 — they are simply not used here).
   Also `note_editor_screen.dart:1506` same pattern. Fix: use
   `l10n.minutesRead(minutes)` / `l10n.lessThan1Min`.
2. `ai_chat_screen.dart:653–655` — follow-up chips
   `'Make it shorter' | 'More uplifting' | 'Summarize key points'`
   hard-coded English. Fix: add arb keys
   `chatChipShorter/chatChipUplifting/chatChipSummarize` (zh/ja/ko/en), pass
   through a small enum so the *prompt* stays English while the *label* is
   localized (chips send the label as message — localize label only, keep a
   separate `promptText`).
3. Server error strings: extend `ErrorDisplay` mapping (existing pattern) —
   no raw `e.toString()` in snackbars.

Process: add "zh locale — zero visible English" section to the QA checklist
doc with a screenshot list (home/detail/editor/AI chat/publish/settings);
regression-gate in future device QA rounds.

---

## Phase 127 — Real TTS (G3)

### Dependency
`pubspec.yaml`: `flutter_tts: ^4.x` (Android/iOS native; keep web on
`speech_synthesis` via existing `_speakWeb`).

### Rewrite `core/tts/speech_service.dart`
Keep the public surface (stateStream / progressStream / speak / stop / pause /
resume / rate) so the reader UI + editor menu need no changes:

- `isAvailable => true` on Android/iOS/web (probe `flutterTts.isLanguageAvailable`
  at init; expose `isAvailable` false only when engine missing).
- `speak(text)`: split paragraphs (existing `_splitParagraphs`), speak
  sequentially — `await flutterTts.awaitSpeakCompletion(true)`, loop
  paragraphs, update `_currentParagraphIndex` → progress stream (real progress
  replaces `_simulationTimer`).
- Language: detect CJK ratio > 0.3 → `zh-CN`, else locale default.
- Rate control: `flutterTts.setSpeechRate(rate)` mapping our 0.5–2.0 range
  onto platform scales (Android 0–1, iOS 0–0.5).
- Engine quirks: Android `setEngine` may be needed for Chinese TTS on some
  ROMs; guard with try/catch and fall back to default engine.

### Entry point
`note_detail_screen.dart` overflow menu: add 朗读 item (reuse the editor's
read-aloud handler logic; stop toggles). Editor already has the entry.

### Verification
Device: note with Chinese text → audible speech, paragraph highlight advances
in the reader sheet, rate slider changes speed, stop works; English note uses
en engine. Web unchanged.

---

## Phase 128 — Capture Modalities (G4)

`quick_capture_screen.dart` currently text-only.

1. **Image in quick capture**: attach button → `image_picker` (already a dep)
   → save via `ImageStorage.saveImageForNote` (existing) → embed in the note
   created on submit (reuse editor's `BlockEmbed.image` path). Thumbnail
   preview row above the input with remove.
2. **Voice → text**: add `speech_to_text: ^7` (Android: RECORD_AUDIO +
   speech recognition permission in AndroidManifest; note vendor availability
   — Samsung/Xiaomi usually OK with Google app present; provide graceful
   "not available" state when `SpeechToText.initialize()` fails). Mic button
   toggles dictation; interim results shown in the field; final text lands as
   note content. Fallback: keep recording as an attachment is OUT of scope
   (privacy + storage) — dictation only.
3. **URL capture**: on paste/submit detect `^https?://\S+$` → offer chip
   "保存为链接摘要" → note body becomes `[title](url)` where title is fetched
   client-side with a plain Dio GET + `<title>` regex (5 s timeout, strip
   scripts; no server involvement to keep zero-knowledge). Failure → fall
   back to bare markdown link.

Verification: each modality home→note in < 3 s on device; airplane-mode voice
shows the unavailable state; URL chip works on a slow site with timeout.

---

## Phase 129 — Capture-time AI Auto-tag (G6)

Reuse the manual path (`note_editor_screen._applySuggestedTags` /
compose's tag prompt) — the LLM call contract already exists.

1. New `core/ai/auto_tagger.dart`: `suggestTags(noteId)` — reads plainContent
   (first 2 000 chars), one non-stream chat call via `AIRepository`
   (client-direct GLM config → no server), prompt returns JSON array of ≤5
   tags (same parsing as the manual action).
2. Trigger: after `_saveNote` succeeds **for a new note** (`_isNew == true` at
   save start) and count of auto-tagged notes today < 5 (counter in
   SharedPreferences). Fire-and-forget (unawaited); never blocks save.
3. Surface: `NoteCard` (home) and note detail show a dismissible
   "建议标签: #a #b +" chip row when suggestions exist for the note
   (store in a small Drift table `tag_suggestions(note_id, tags_json,
   created_at, dismissed)` — add migration 032 + DAO).
4. Accept = one tap → existing tag-create-or-link flow (`_applySuggestedTags`
   logic moved to a shared service), suggestion row disappears.
5. Rate/privacy: no content logged (AI proxy rule); quota counter local;
   auto-tag disabled when no local LLM config (avoid shared-LLM spend) —
   surface a one-time hint instead.

---

## Phase 130 — Startup Performance (G12)

1. Measure first: `flutter run --profile --trace-startup` on device +
   `PerformanceMonitor` timings already in main.dart. Record
   time-to-first-frame and time-to-Home.
2. Likely suspects (verify with the trace, don't guess): synchronous
   `await`s before `runApp` (secure storage reads, DB open, Argon2 unlock
   attempt), full note-list stream subscription before first paint.
3. Fixes pattern: show `flutter_native_splash` (add dep) with
   `preserve`/`remove` around the async bootstrap; move non-critical init
   (analytics, presence, sync kick-off) to `addPostFrameCallback` /
   short-delay microtasks; lazily open DB (Drift `lazy` connect already
   possible) — keep crypto unlock eager (login UX depends on it).
4. Budget: release build, mid-range Android — first frame < 2 s, Home
   interactive < 4 s. Document in the QA checklist; re-measure after each
   Sprint B merge.

---

## Phase 131 — Publish Stats + Content Calendar (G5)

1. Backend: adapter interface gains optional
   `FetchStats(ctx, cookieJar) (*PostStats, error)` — implement for
   xiaohongshu first (chromedp navigate to post page, scrape
   views/likes/comments selectors — same session infra as publish).
   Others return `ErrNotSupported`.
2. Worker: extend the existing hourly scheduler (`cmd/worker/main.go`) with a
   `TaskRefreshPostStats` — for each publish_history row ≤ 30 days old with a
   platform post id, fetch stats into a new table
   `post_stats(publish_id, platform, views, likes, comments, fetched_at)`
   (migration 033; keep last 30 snapshots per post for the trend line).
3. API: `GET /publish/history` response gains `stats` object (joined latest).
4. Frontend: history card shows the three numbers with icons; calendar view =
   new tab in the publish screen — simple month grid (`TableCalendar`-free:
   hand-rolled GridView to avoid a dep) with dots on days having publishes;
   tap a day lists posts.
5. Verify: publish a test post to a scratch XHS account, wait for the worker
   cycle, numbers appear; calendar shows the dot.

---

## Phase 132 — Semantic Search pgvector (G9)

1. Infra: `docker-compose.deploy.yml` postgres image → `pgvector/pgvector:pg16`
   (drop-in); migration 034 `CREATE EXTENSION IF NOT EXISTS vector;`.
2. Schema: `public_note_embeddings(note_id uuid pk, embedding vector(1024),
   lang, updated_at)` — **server-side embeddings are computed from
   public-content only** (privacy decision): the share/publish flows already
   have plaintext-public bodies server-side? No — E2E design means the server
   never sees note text. Resolution (must be explicit): embedding happens
   CLIENT-side via the user's GLM config (embedding endpoint), the client
   uploads the vector (numbers only, not text) tagged `public: true` only for
   notes the user has shared/published. Server stores vectors, never text.
3. Query flow: client embeds the query (same model), POST
   `/search/semantic` → server `ORDER BY embedding <=> $1 LIMIT 20` filtered
   to `public = true AND owner = me` (own notes only; cross-user discovery is
   a later decision). Hybrid: merge with FTS5 results (RRF, k=60).
4. Client: search screen gains a "语义" toggle; results reuse the note card.
5. Cost guard: embed on share/publish and on explicit user action
   ("为此笔记建立语义索引"), not on every save.

---

## Phase 133 — Paper Rollout + Dead-feature Decision (G10/G11/G15)

- Collection covers / compose cluster cards / settings banner → wrap in
  `PaperSurface` + `PaperTokens` (mechanical, follow note-card examples).
- Editor edit-mode first line handwritten: apply the handwriting TextStyle to
  the first-line `defaultStyles` via a custom `TextSpan` builder in
  `rich_note_editor.dart` (quill `customStyleBuilder` on block index 0).
- Duplicate 专注模式 entries: the editor menu lists focus mode twice with two
  different actions (Zen auto-enables focus vs standalone toggle) — merge into
  one item; keep Zen separate.
- Version-history "current" chars: snapshot taken pre-save shows stale count —
  label the top entry 当前(上次保存) or snapshot post-write like the restore
  flow already does (aa0b-style post-write snapshot, reuse the pattern).
- G15 decision memo (no code): home_widget_service.dart — either wire a real
  launcher widget (home_widget dep + glance config) or delete the service and
  strike the phase label; same for template marketplace UI. Default: strip —
  YAGNI until a user asks.

---

## Sequencing & risk notes

- **125 first** (unblocks everything server-side; Redis fix is one line).
- 124 depends on nothing; run parallel with 125 (different repos/halves).
- 126 anytime — batch with the Sprint A release build.
- 128 voice depends on 127's platform-permission pass? No — independent, but
  both touch AndroidManifest; land together to avoid merge friction.
- 129 needs a local GLM config on device (exists); quota counter prevents
  runaway spend.
- 132 is the only schema-risky item (image swap + extension) — rehearse on the
  VPS with a DB snapshot first; pgvector image is a drop-in for pg16 data dir.
- North-star analytics (opt-in) land at the START of Sprint B as a small
  `core/analytics/` wrapper (counts + durations only, no content), so Sprint C
  decisions have baselines.
