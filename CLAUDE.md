# AnyNote — Project Configuration for Claude Code

## Project Overview

Local-first, privacy-first note-taking app with E2E encryption.

**Architecture**: Thin Server (Go) + Thick Client (Flutter) + E2E Encryption (XChaCha20-Poly1305)

Server **never** stores plaintext notes — only encrypted blobs.

## Workflow Rules

### Resilience and Error Handling

- **Rate limits**: If subagents hit 429 rate limits, reduce parallel agent count to 2 max and prefer direct Read/Grep/Glob over agent spawning for status checks
- **API errors**: If persistent API 500 errors occur (2+ failures on same operation), stop retrying and document the blocker in work-log.md. Do not burn session context on infrastructure issues
- **Blocker documentation**: When blocked by infrastructure, note what was attempted and what can be done without the blocked capability
- **Subagent limits**: Launch at most 3 parallel subagents. For exploration/research, use direct tools instead of agents

### Cleanup Rules

- Clean temp/cache files after EACH subtask completes and results merge to main process (not just at end of long task)
- Delete files under `/tmp/claude*` after each subtask

### Complex Task Decomposition

When executing complex tasks (multi-file changes, cross-layer implementations, multi-module refactors):

1. **Decompose** — Break the task into independent, small subtasks (e.g., "create repo layer", "create handler layer", "write tests")
2. **Delegate to subagents** — Launch parallel subagents for independent subtasks:
   - Backend work → `go-backend-dev` agent
   - Frontend work → `flutter-frontend-dev` agent
   - Crypto/security review → `crypto-auditor` agent
3. **Merge results** — Main process collects subagent outputs, resolves conflicts, and proceeds to dependent steps
4. **Maximize parallelism** — Independent subtasks MUST run in parallel, not sequentially

Example: "Add a new sync feature" should spawn:
- Agent 1: `go-backend-dev` → repository + service + handler
- Agent 2: `flutter-frontend-dev` → DAO + screen + provider
- Main process: wire both together after completion

## Tech Stack

- **Backend**: Go 1.22+ / chi / PostgreSQL 16 / Redis (asynq) / chromedp
- **Frontend**: Flutter 3.3+ / Drift (SQLite+SQLCipher) / Riverpod / go_router
- **Encryption**: XChaCha20-Poly1305 + Argon2id + HKDF-SHA256
- **Infra**: Docker Compose (PostgreSQL, Redis, MinIO, Chrome headless)

## Project Structure

```
any-note/
├── backend/           # Go: github.com/anynote/backend
│   ├── cmd/           # server, worker, migrate
│   ├── internal/      # config, domain, handler, service, repository, llm, platform, queue
│   └── db/            # migrations, sqlc
├── frontend/          # Flutter
│   └── lib/
│       ├── core/      # crypto, database, sync, network, theme
│       ├── features/  # auth, notes, compose, publish, settings, tags
│       └── routing/   # go_router config
├── docker-compose.yml
└── Makefile
```

## Key Architectural Decisions

1. **E2E Encryption**: All user data encrypted client-side before sync. Server is zero-knowledge.
2. **Encrypted blob sync**: Single `sync_blobs` table on server. All items stored as encrypted blobs.
3. **Client-driven sync**: Version vector + LWW. Client pulls/pushes, server stores/forwards.
4. **AI proxy (dual-mode)**: User-configured LLM → direct proxy. No LLM config → shared server LLM with rate limiting.
5. **Platform publishing**: chromedp headless browser for XHS. Content is public, no privacy conflict.

## Code Conventions

### Go (Backend)
- Follow standard Go project layout
- Interfaces in service layer, implementations in repository layer
- Error types as `var ErrXxx = errors.New(...)` sentinel values
- Handler layer: thin HTTP handling, delegates to services
- No logging of request/response bodies in AI proxy (privacy)
- Comments in English

### Dart (Flutter)
- Feature-based directory structure
- Riverpod for state management (`ConsumerWidget` / `ConsumerStatefulWidget`)
- Drift for local database with generated code (`.g.dart`)
- Crypto operations return `Future<Uint8List>` or `Future<String>`
- Comments in English

### General
- No emojis in code unless explicitly requested
- Code comments in English
- Commit messages follow Conventional Commits format

## Common Commands

```bash
# Start infrastructure
docker compose up -d postgres redis minio chrome

# Backend
cd backend && go mod tidy
make dev-server    # Run server
make dev-worker    # Run worker
make migrate       # Run DB migrations
make test-backend  # Run tests

# Frontend
cd frontend && flutter pub get
make dev-frontend  # Run app
make generate-drift # Generate Drift code
```

## Privacy Rules (CRITICAL)

1. **NEVER** log AI request/response bodies — they contain decrypted note content
2. **NEVER** store plaintext notes on the server
3. **NEVER** commit API keys, JWT secrets, or encryption keys to git
4. **ALWAYS** encrypt user data with per-item keys derived from master key
5. Server-side API keys use AES-256-GCM encryption at rest

## API Routes

All under `/api/v1/`:
- Auth: `/auth/register|login|refresh|me`
- Sync: `/sync/pull|push|status`
- AI: `/ai/proxy|quota`
- LLM: `/llm/configs|providers`
- Publish: `/publish|history`
- Platforms: `/platforms/{platform}/connect|disconnect|verify`

## Project Documentation & State Management

This project tracks progress via three documentation layers. Keep these updated when significant changes are made:

| File | Purpose | When to Update |
|------|---------|----------------|
| `doc/work-log-YYYY-MM-DD.md` | Detailed daily change log | After each development session |
| `doc/development-plan.md` | Full task breakdown with status | When tasks are completed or new ones discovered |
| `memory/MEMORY.md` (Claude memory) | Cross-session context summary | When project state changes significantly |

### Conventions
- Work logs: concise task summaries, group files by backend/frontend/docs
- Development plan: clear status markers (completed/pending/blocked)
- Memory file: keep under 200 lines, focus on decisions and key paths
- All documentation in English

### Quick Commands
- `/save-state` — Update all three documentation files in one shot
- `/test` — Run relevant tests based on changed files

## Verification Rules

After any Go backend implementation, before reporting completion:
1. Run `go build ./...` to confirm compilation
2. Run `go vet ./...` to check for common issues
3. Run `go test ./...` to verify no regressions

## Debugging Approach

When diagnosing environment or tooling issues:
1. Gather facts first: `which <tool>`, `go env`, `echo $PATH`
2. Analyze findings before proposing fixes
3. Do NOT assume tool availability or jump to solutions without understanding the environment

## Design & UI Preferences

- Do NOT generate design principles, style guides, or aesthetic opinions without explicit direction from the user
- Ask the user what they want first, then execute on their vision
- The `.impeccable.md` file in the project root contains the authoritative design context

## Testing Priorities

1. Encryption correctness (encrypt/decrypt round-trip, key derivation determinism)
2. Sync conflict resolution (LWW, version vectors)
3. AI proxy streaming (SSE parsing, quota enforcement)
4. FTS5 search (Chinese text, performance with large datasets)
5. Platform adapter integration (XHS publish flow)


<!-- auto-review:rules:start -->
## 代码评审规则（auto-review 自动生成，请勿手改）

本仓库由 auto-review 门禁把守。以下是当前生效的规则摘要——**写代码时就遵守，而不是等门禁失败后再修**。

**语言规则**：
- `python`：圈复杂度 ≥10 报 major / ≥15 报 blocker：生产代码变更必须伴随测试变更（TDD 耦合检查）；改动行覆盖率 ≥80%
- `javascript`：圈复杂度 ≥10 报 major / ≥15 报 blocker：生产代码变更必须伴随测试变更（TDD 耦合检查）；改动行覆盖率 ≥80%
- `golang`：圈复杂度 ≥10 报 major / ≥15 报 blocker：生产代码变更必须伴随测试变更（TDD 耦合检查）；改动行覆盖率 ≥60%
- `dart`：生产代码变更必须伴随测试变更（TDD 耦合检查）；改动行覆盖率 ≥60%

**通用要求**：
- 函数要小：一个函数只做一件事，圈复杂度超过阈值必须拆分；
- 测试先行：新行为先写失败测试再写实现；测行为，不测实现细节；
- 童子军规则：改到的文件不允许比改动前更复杂（Boy Scout 引擎比对基线）；
- 小批量提交：超大变更集会被直接拒绝，拆分为多个小 PR；
- 提交前自检：运行 `auto-review review --tier fast`，通过后再提交；
- 门禁失败时：用 `auto-review fix-hints`（或 CI artifact 的 report.json）获取修复指令，修复后重新验证，不要用 --no-verify 绕过。

**自定义检查**（命令失败即按配置级别计 finding）：
- `go-vet`：`command -v go >/dev/null 2>&1 || exit 0; cd backend && go vet ./...`
- `gofmt`：`command -v go >/dev/null 2>&1 || exit 0; cd backend && test -z "$(gofmt -l .)"`
- `flutter-analyze`：`command -v flutter >/dev/null 2>&1 || exit 0; cd frontend && flutter analyze --no-fatal-infos`

完整配置见 `.auto-review.yaml`；规则参考见 auto-review 的 `docs/rules.md`。
<!-- auto-review:rules:end -->
