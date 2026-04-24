# Changelog

All notable changes to AnyNote will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-04-24

### First stable release.

All 69 development phases complete. Production-ready with 2800+ tests (700+ Go backend, 2093+ Flutter frontend), zero lint issues, full l10n coverage (EN/ZH/JA/KO).

### Security

- Argon2id KDF upgrade with v1 auto-migration prompt on login
- Web CSP strict policy
- Web/native ciphertext incompatibility warning in encryption settings
- Constant-time password comparison
- JWT algorithm restriction (HS256 only)
- Crypto exception hierarchy
- Refresh token rotation with PostgreSQL tracking
- Per-IP and per-user rate limiting across all endpoints
- WebSocket short-lived tokens (60s)
- Share password verification
- `DisallowUnknownFields` on all request decoders

### Encryption

- Native: XChaCha20-Poly1305 + Argon2id + BLAKE2b per-item key derivation
- Web: AES-256-GCM + PBKDF2 + HMAC-SHA256 per-item key derivation
- Server API keys encrypted at rest with AES-256-GCM
- BIP-39 recovery phrase support

### Features

- **Notes**: Rich text editor (flutter_quill), auto-save, encryption, version history, zen mode, templates, FTS5 search with BM25 ranking and CJK tokenizer
- **Sync**: Version vector + LWW conflict resolution, batch operations, client-driven push/pull
- **AI**: Dual-mode proxy (user LLM or shared server LLM), SSE streaming, quota enforcement, circuit breaker with 3-state FSM
  - AI Chat assistant
  - Smart Summary
  - Auto-Tag Suggestion
  - AI Translation
  - Grammar/Writing Polish
  - AI Agent (organize/summarize/create_note actions)
- **AI Compose**: 4-stage pipeline (cluster, outline, expand, style-adapt)
- **Publishing**: 6 platform adapters (XHS, WeChat, Zhihu, Medium, WordPress, Webhook) via chromedp headless browser
- **Collaboration**: RGA-based CRDT editor, WebSocket relay, real-time cursor broadcast, presence indicators
- **Sharing**: Public shares with comments, reactions, nested comments, discover feed
- **Note Links**: Bidirectional links, backlinks, knowledge graph visualization
- **Push Notifications**: FCM integration, device token management
- **Billing**: Plan tiers (free/pro/lifetime), quota management
- **User Profiles**: Public profiles with username resolution
- **Desktop**: App menu bar, window state persistence, keyboard shortcuts, adaptive layout
- **Share Extension**: Android/iOS platform channels, deep link routing
- **Accessibility**: A11y utilities, semantic labels
- **Localization**: EN + ZH + JA + KO with full coverage

### Observability

- Prometheus metrics: AI request/token counters, active streams gauge, DB query histogram, HTTP status histogram, circuit breaker state gauge
- Request tracing with trace_id propagation
- Structured logging throughout

### Infrastructure

- Docker Compose: PostgreSQL 16, Redis, MinIO, Chrome headless
- asynq Redis queue for async jobs (AI, publish)
- Shared HTTP client with connection pooling
- Chromedp shared utility package
- Graceful shutdown
- pprof endpoint (auth-protected)

### Testing

- 700+ Go test functions across 18 packages
- 2093+ Flutter test functions across 55+ files
- Integration tests with testcontainers-go (build tag: `integration`)
- Widget tests, provider tests, service tests, E2E sync tests

### Bug Fixes (since v0.58.0)

- Fixed StaggeredGroup animation timer leak causing test failures
- Fixed go_router navigation in backlinks/graph screens
- Fixed stream leak in collab_cursors widget
- Fixed pgx.ErrNoRows handling in AI agent service
- Fixed dead code in ai_agent_service
- Cleaned duplicate performance_monitor files
- Fixed trailing comma lint issues
- Added trailing commas in app_components.dart

### Code Quality

- Zero `TODO`/`FIXME`/`HACK` markers in production code
- Zero `flutter analyze` issues
- Zero `go vet` issues
- Settings screen decomposed into modular sections (account, about, sign_out)
- Widget extraction: 15+ reusable widgets from monolithic screens
- Consistent handler/service/repository architecture throughout
