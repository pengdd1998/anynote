# AnyNote Development Plan

## Confirmed Decisions

- **Architecture**: Thin Server (Go/chi/PostgreSQL/Redis) + Thick Client (Flutter/Drift/Riverpod)
- **E2E Encryption**: XChaCha20-Poly1305 + Argon2id + HKDF-SHA256 (client-side only, server is zero-knowledge)
- **Crypto Package**: `sodium_libs` -- single dependency for XChaCha20-Poly1305, Argon2id (crypto_pwhash), and HKDF
- **Sync Protocol**: Version vector + LWW conflict resolution, client-driven push/pull
- **AI Integration**: Dual-mode proxy -- user-configured LLM via direct proxy, or shared server LLM with rate limiting
- **Publishing**: chromedp headless browser automation for XHS; content is public (no privacy conflict)
- **WeChat**: Deferred to post-MVP -- focus on XHS first
- **Key Storage**: Platform secure storage (Keychain/Keystore) via flutter_secure_storage
- **Local DB**: Drift (SQLite) with SQLCipher encryption at rest, FTS5 for full-text search
- **State Management**: Riverpod with ConsumerWidget/ConsumerStatefulWidget
- **Routing**: go_router with ShellRoute for bottom navigation

## Overall Planning Overview

### Project Objectives

Build a local-first, privacy-first note-taking application where the server never sees plaintext user data. Users own their encryption keys; the server stores only encrypted blobs. AI composition features operate via a proxy that streams LLM responses without logging content. Platform publishing automates posting to external services (XHS, WeChat) via headless browser.

### Technology Stack

| Layer | Technology |
|---|---|
| Backend | Go 1.22+, chi router, PostgreSQL 16, Redis (asynq), chromedp |
| Frontend | Flutter 3.3+, Drift (SQLite+SQLCipher), Riverpod, go_router |
| Encryption (client) | XChaCha20-Poly1305, Argon2id, HKDF-SHA256 via sodium_libs |
| Encryption (server) | AES-256-GCM for API key storage at rest |
| Infra | Docker Compose (PostgreSQL, Redis, MinIO, Chrome headless) |

### Current State Summary (Updated 2026-04-28)

**v2.0.0.** All 143 phases complete. Production-ready with zero lint issues, full l10n coverage (EN/ZH/JA/KO), schema v25.

| Module | Completeness | Notes |
|---|---|---|
| Backend Auth | 100% | Register, login, refresh, me — JWT + bcrypt, 33 tests |
| Backend Sync | 100% | Pull/push with LWW conflict resolution, 30 tests |
| Backend LLM Gateway | 100% | 5 OpenAI-compatible providers, retry with backoff, AES-256-GCM key encryption, shared HTTP client, fallback config, Prometheus metrics, 80 tests |
| Backend AI Proxy | 100% | Dual-mode (user LLM / shared server LLM), SSE streaming, quota, per-chunk SSE limits, ctx.Done() streaming, role validation, 19 tests |
| Backend Platform Adapters | 100% | 6 adapters (XHS, WeChat, Zhihu, Medium, WordPress, Webhook), 80 tests |
| Backend Worker/Queue | 100% | asynq Redis queue, AI + publish job handlers, 40 tests |
| Backend Publish | 100% | Async publish with platform adapters, history, 25 tests |
| Backend WebSocket/Presence | 100% | Room-based collab, CRDT relay, rate limiting, Redis pub/sub, 65 tests |
| Backend Security | 100% | Security headers, JWT auth, per-IP/user rate limiting, 19 tests |
| Backend Tests | 100% | ~934 test functions across 14 packages, all pass |
| Frontend Crypto | 100% | Native: XChaCha20-Poly1305 + Argon2id; Web: AES-256-GCM + PBKDF2, 100+ tests |
| Frontend Database | 100% | Drift schema v16, 12 tables, FTS5 with CJK tokenizer, color columns, sort order, snippets, tag hierarchy, all DAOs tested |
| Frontend Sync Engine | 100% | Pull/push, LWW, version vectors, periodic sync, connectivity-aware |
| Frontend Auth | 100% | Full crypto key derivation flow, BIP-39 recovery, token refresh |
| Frontend Notes CRUD | 100% | Rich editor, auto-save, encryption, version history, zen mode, templates, color-coding, reminders, drag-reorder, code snippets |
| Frontend AI Compose | 100% | 4-stage pipeline (cluster, outline, expand, style-adapt), content limits, CancelToken, ErrorMapper, quota pre-check, concurrency guard |
| Frontend Publish | 100% | Platform connection, publish form, history, 6 platform adapters |
| Frontend Settings | 100% | Account, AI, LLM config, platforms, encryption, sync, import/export, language |
| Frontend CRDT Collab | 100% | RGA CRDT, editor controller, WebSocket relay, presence indicators |
| Frontend Share Extension | 100% | Android/iOS platform channels, deep link routing |
| Frontend Desktop | 100% | Menu bar, window state persistence, keyboard shortcuts, adaptive layout |
| Frontend Search | 100% | FTS5 with BM25 ranking, CJK tokenizer, advanced search screen |
| Frontend Localization | 100% | EN + ZH + JA + KO |
| Frontend Tests | 100% | 3395 tests (15 skipped, 0 failures) across 70+ test files |

### Main Phases

1. **Phase 0: Critical Fixes** — COMPLETED (security bugs, compilation blockers)
2. **Phase 1: Core Foundation** — COMPLETED (real crypto, Drift, encryption-integrated CRUD, auth)
3. **Phase 2: Sync & AI** — COMPLETED (E2E sync, AI composition workflow, structured logging, retry)
4. **Phase 3: Publishing** — COMPLETED (XHS, WeChat, Zhihu, Medium, WordPress, Webhook adapters)
5. **Phase 4: Polish & Testing** — COMPLETED (comprehensive tests, error handling, UX polish)
6. **Phase 5-13: Post-MVP Features** — COMPLETED (tags, collections, templates, import/export, backup/restore, home widgets, template marketplace, performance)
7. **Phase 21: Production Hardening** — COMPLETED (accessibility, security headers, expanded tests)
8. **Phase 22: WebCrypto + Web** — COMPLETED (AES-256-GCM + PBKDF2 for web)
9. **Phase 23: Share Extension** — COMPLETED (Android/iOS share-to-app)
10. **Phase 24: CRDT Collaboration** — COMPLETED (editor controller + WS relay)
11. **Phase 25: Desktop Polish** — COMPLETED (menu bar, window state, shortcuts)
12. **Phase 26: App Store Prep** — COMPLETED (icons, splash, Fastlane, privacy policy)
13. **Phase 27: Production Readiness** — COMPLETED (lint cleanup, deployment config, web build verification)
14. **Phase 28: Code Quality & Security** — COMPLETED (memory leaks, test fixes, input validation, rate limiter eviction)
15. **Phase 29: Push Notifications & E2E Tests** — COMPLETED (FCM push, E2E test suites, accessibility audit)
16. **Phase 30: Security Hardening + Sync Performance** — COMPLETED (body size limits, SSE fix, auth validation, TOCTOU fix, sync pagination)
17. **Phase 31: Security & Feature Completion** — COMPLETED (Argon2id upgrade, account deletion, push for publish/comments)
18. **Phase 32-36: Test Coverage & Quality** — COMPLETED (widget tests, provider tests, service tests, integration hardening)
19. **Phase 37-40: Feature Completion** — COMPLETED (remaining UI tests, settings tests, screen coverage)
20. **Phase 41-43: Tooling & Assessment** — COMPLETED (project config, quality assessment, widget/provider test pass)
21. **Phase 44-45: Final Coverage Push** — COMPLETED (widget tests, design system tests, cluster/outline model tests)
22. **Phase 46: Code Quality Hardening** — COMPLETED (screen tests, backend error handling, JWT validation, Bearer RFC compliance)
23. **Phase 47: Error Handling & Config Validation** — COMPLETED (silent error discard fixes, startup config warnings)
24. **Phase 48: Test Infrastructure & E2E Expansion** — COMPLETED (shared testutil package, share + AI proxy E2E flows)
25. **Phase 49: Security Tests & Benchmarks** — COMPLETED (JWT tampering, input validation, injection vectors, perf baselines)
26. **Phase 50: Frontend CRDT + Platform Tests** — COMPLETED (171 CRDT tests, 79 share/desktop tests, compilation fixes)
27. **Phase 51: Security Hardening** — COMPLETED (WS tokens, share passwords, DisallowUnknownFields, frontend typed exceptions, ICU plurals)
28. **Phase 52: Test Fixes** — COMPLETED (fix 36 failing tests + source bugs: connectivity provider, MarkdownPreview rewrite)
29. **Phase 53: Backend Quality + Frontend Polish** — COMPLETED (ErrNotOwner, UUID migration, pprof auth, refresh tokens infra, a11y, alpha constants)
30. **Phase 54: Refresh Token Rotation** — COMPLETED (refresh token rotation, graceful shutdown, test expansion)
31. **Phase 55: Efficiency Fixes** — COMPLETED (code review efficiency improvements)
32. **Phase 56: AI Module Hardening** — COMPLETED (shared HTTP client, stream cancellation, fallback LLM, Prometheus metrics, content limits, ErrorMapper, CancelToken, quota pre-check, concurrency guard, field validation, user-scoped delete)
33. **Phase 100-103: UX & Quality** — COMPLETED (lint cleanup, color-coding, reminders, accessibility)
34. **Phase 104-107: Power User Features** — COMPLETED (batch color/lock, note compare, Mermaid, collection picker)
35. **Phase 108-111: Reading & Navigation** — COMPLETED (TOC, section folding, scroll-to-top/print, TTS)
36. **Phase 112-115: Notifications & Shortcuts** — COMPLETED (local notifications, note reorder, AI chat tests, keyboard shortcuts)
37. **Phase 116-119: Snippets & Export** — COMPLETED (code snippets, PDF export, Mermaid rendering, widget tests)
38. **Phase 120-123: Hierarchy & Integration** — COMPLETED (tag hierarchy, collab cursors, quick actions + image DnD, widget tests)
39. **Phase 128-133: Security, UX, Performance, Architecture (v1.4.0)** — COMPLETED (backend hardening, SQLCipher, toolbar redesign, performance, architecture, polish)
40. **Phase 135: UX Polish — Error Handling & Offline** — COMPLETED (ErrorBoundary, ConflictResolutionScreen, unified SnackBar, What's New, offline indicators)
41. **Phase 136: UX Polish — Editor Experience** — COMPLETED (autosave debounce, save status, extended toolbar, Find & Replace)
42. **Phase 137: Cross-Platform Consistency** — COMPLETED (PlatformUtils, Breakpoints, adaptive widgets, FocusRing, DesktopContextMenu)
43. **Phase 138: Multi-Device Sync** — COMPLETED (device identity, migrations 020-021, account recovery)
44. **Phase 139: CRDT Persistence & Collab Backend** — COMPLETED (persistent siteIds, collab rooms/members, invite codes)
45. **Phase 140: Image Sync & Web Images** — COMPLETED (image compression, encrypted image sync, WebImageStorage)
46. **Phase 141: Collab Backend Hardening** — COMPLETED (operation persistence, WS access control, reconnect catch-up)
47. **Phase 142: Web Platform** — COMPLETED (CryptoFactory, DatabaseFactory, UnsupportedError audit, cross-platform crypto tests)
48. **Phase 143: Payment & Notification Infrastructure** — COMPLETED (payments, notifications, Stripe webhooks, CRUD endpoints)

---

## Detailed Task Breakdown

### Phase 0: Critical Fixes (Priority: P0) — COMPLETED

All 4 tasks completed: LLM config API key encryption, deterministic nonce fix, Drift code generation, missing routing files.

#### Task 0.1: Fix LLM Config API Key Encryption Bug

- **Description**: `llm_config_service.go` lines 57 and 79 compute the encrypted API key (`encryptedKey`) but discard it with `_ = encryptedKey`. The plaintext `DecryptedKey` is stored in the database instead. This means API keys are stored in cleartext.
- **Agent**: `go-backend-dev`
- **Dependencies**: None
- **Effort**: S (1-2 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/backend/internal/service/llm_config_service.go` -- Replace `_ = encryptedKey` with `cfg.EncryptedKey = encryptedKey` and `cfg.DecryptedKey = ""` on both Create and Update paths
  - `/home/ubuntu/projects/any-note/backend/internal/domain/types.go` -- Verify `LLMConfig` has proper `EncryptedKey` field (already exists at line 45)
  - `/home/ubuntu/projects/any-note/backend/internal/repository/` -- Verify repository stores `EncryptedKey` column, not `DecryptedKey`
- **Acceptance Criteria**:
  - API keys are stored encrypted in the database
  - `DecryptedKey` field is zeroed before database write
  - Existing test `crypto_test.go` for EncryptAPIKey/DecryptAPIKey passes
  - `TestConnection` in llm_config_service.go decrypts the stored key before use (line 113 currently reads `cfg.DecryptedKey` which will be empty after the fix)
  - `AIProxyService.Proxy` (line 58 in ai_proxy_service.go) must also decrypt the key before using it

---

#### Task 0.2: Fix Deterministic Nonce Generation in Frontend Crypto

- **Description**: `encryptor.dart` line 116 `_generateNonce` uses `DateTime.now().microsecondsSinceEpoch` with a deterministic formula instead of `Random.secure()`. `master_key.dart` line 33 `generateSalt` does the same. These produce predictable nonces/salts, completely defeating encryption security.
- **Agent**: `crypto-auditor`
- **Dependencies**: None
- **Effort**: S (1 hour)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/core/crypto/encryptor.dart` -- Replace `_generateNonce` with `Random.secure()` from `dart:math`
  - `/home/ubuntu/projects/any-note/frontend/lib/core/crypto/master_key.dart` -- Replace `generateSalt` with `Random.secure()`
- **Acceptance Criteria**:
  - Nonces are generated using `dart:math Random.secure()`
  - Salts are generated using `Random.secure()`
  - No deterministic patterns in generated values

---

#### Task 0.3: Generate Drift Code (.g.dart files)

- **Description**: The project uses Drift with `part 'app_database.g.dart'` and `part 'notes_dao.g.dart'` but these generated files do not exist. The app cannot compile without them.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: None
- **Effort**: S (1-2 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/app_database.dart` (has `part 'app_database.g.dart'`)
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/notes_dao.dart` (has `part 'notes_dao.g.dart'`)
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/tags_dao.dart`
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/collections_dao.dart`
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/generated_contents_dao.dart`
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/sync_meta_dao.dart`
- **Acceptance Criteria**:
  - `dart run build_runner build` completes without errors
  - All `.g.dart` files are generated
  - `flutter analyze` passes with no errors related to Drift

---

#### Task 0.4: Add Missing Frontend Routing Files

- **Description**: `app_router.dart` imports files that do not exist: `cluster_screen.dart`, `outline_screen.dart`, `compose_editor_screen.dart`, `publish_history_screen.dart`. These are likely defined as widget classes within other files (e.g., `ComposeScreen` file contains `ClusterScreen`, `OutlineScreen`, `ComposeEditorScreen` classes), but they need to be in separate files for the router imports to resolve. Alternatively, the router imports need to match the actual file structure.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 0.3
- **Effort**: S (1 hour)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/routing/app_router.dart`
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/presentation/` -- Either extract classes to separate files or fix imports
  - `/home/ubuntu/projects/any-note/frontend/lib/features/publish/presentation/` -- Same for `PublishHistoryScreen`
- **Acceptance Criteria**:
  - `flutter analyze` passes
  - App compiles and launches

---

### Phase 1: Core Foundation (Priority: P1) — COMPLETED

All 6 tasks completed: real XChaCha20-Poly1305 encryption, Argon2id key derivation, auth flow with crypto, encrypted note CRUD, encrypted tags/collections, settings persistence.

#### Task 1.1: Integrate Real XChaCha20-Poly1305 Encryption

- **Description**: Replace all XOR placeholder encryption in `encryptor.dart` with real XChaCha20-Poly1305 AEAD using the `sodium_libs` (or `sodium`) Flutter package. The encrypt/decrypt, encryptBlob/decryptBlob, and nonce generation must all use the real crypto primitives.
- **Agent**: `crypto-auditor`
- **Dependencies**: Task 0.2
- **Effort**: L (1-2 days)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/core/crypto/encryptor.dart` -- Full rewrite of encrypt/decrypt/encryptBlob/decryptBlob
  - `/home/ubuntu/projects/any-note/frontend/pubspec.yaml` -- Add `sodium_libs` dependency
- **Acceptance Criteria**:
  - Encryption produces: nonce (24 bytes) || ciphertext + Poly1305 tag (16 bytes)
  - Decrypt correctly reverses encrypt (round-trip test passes)
  - Authentication tag is verified on decrypt (tampered ciphertext fails)
  - Performance is acceptable for notes up to 100KB (under 100ms on mobile)

---

#### Task 1.2: Integrate Real Argon2id Key Derivation

- **Description**: Replace the XOR-based `deriveMasterKey` placeholder in `master_key.dart` with actual Argon2id. Also replace the fake HKDF-Expand (`_hkdfExpand`) with real HKDF-SHA256. The BIP-39 recovery key generation must also use proper entropy.
- **Agent**: `crypto-auditor`
- **Dependencies**: Task 0.2
- **Effort**: L (1-2 days)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/core/crypto/master_key.dart` -- Full rewrite of `deriveMasterKey`, `_hkdfExpand`, `generateRecoveryKey`
  - `/home/ubuntu/projects/any-note/frontend/pubspec.yaml` -- Add `argon2ffi` or equivalent native Argon2id package
- **Acceptance Criteria**:
  - `deriveMasterKey` uses Argon2id with: memory=64MB, iterations=3, parallelism=1, output=256-bit
  - `_hkdfExpand` uses proper HKDF-SHA256 (extract-then-expand)
  - Key derivation is deterministic: same password + salt always produces same key
  - Recovery key uses proper BIP-39 mnemonic with cryptographically secure entropy
  - Performance is acceptable (Argon2id should take ~1-3 seconds on mobile)

---

#### Task 1.3: Wire Encryption into Auth Flow

- **Description**: The login and registration screens currently send raw passwords. They must be updated to derive keys using the real crypto stack: Argon2id -> master key -> HKDF -> auth key hash (for server login) and encrypt key (for data encryption). Registration must generate and store a salt, derive the master key, and send the auth key hash to the server.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 1.1, Task 1.2
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/features/auth/presentation/login_screen.dart` -- Derive auth key hash from password + stored salt, send hash to server
  - `/home/ubuntu/projects/any-note/frontend/lib/features/auth/presentation/register_screen.dart` -- Generate salt, derive master key, send auth key hash + salt + recovery key to server
  - `/home/ubuntu/projects/any-note/frontend/lib/core/crypto/master_key.dart` -- Ensure public API supports the auth flow
  - `/home/ubuntu/projects/any-note/frontend/lib/core/crypto/key_storage.dart` -- Store master key, encrypt key, salt after registration/login
  - `/home/ubuntu/projects/any-note/frontend/lib/main.dart` -- Initialize key storage on app start
- **Acceptance Criteria**:
  - Registration: generates salt, derives master key via Argon2id, derives auth key hash via HKDF, sends hash (not password) to server
  - Login: retrieves stored salt, derives auth key hash, sends hash to server
  - Master key and encrypt key are stored in platform secure storage after successful auth
  - Auth redirect in `app_router.dart` checks key storage state
  - Token refresh works when access token expires

---

#### Task 1.4: Wire Encryption into Note CRUD

- **Description**: Notes are currently stored with raw plaintext. The note editor, detail view, and list must encrypt content before writing to Drift and decrypt when reading. Each note gets a per-item key derived via HKDF(encrypt_key, note_id).
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 1.1, Task 1.2, Task 0.3
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/features/notes/presentation/note_editor_screen.dart` -- Encrypt on save
  - `/home/ubuntu/projects/any-note/frontend/lib/features/notes/presentation/note_detail_screen.dart` -- Decrypt on display
  - `/home/ubuntu/projects/any-note/frontend/lib/features/notes/presentation/notes_list_screen.dart` -- Decrypt titles/previews for list display
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/notes_dao.dart` -- May need encryption-aware wrappers
  - `/home/ubuntu/projects/any-note/frontend/lib/core/crypto/encryptor.dart` -- Per-item key derivation API
- **Acceptance Criteria**:
  - Creating a note: plaintext is encrypted with per-item key, both `encryptedContent` and `plainContent` are stored (plain for local search)
  - Viewing a note: content is decrypted from `encryptedContent`, fallback to `plainContent` cache
  - Listing notes: `plainTitle` and `plainContent` preview are displayed (populated from encryption or cache)
  - FTS5 index is populated from `plainContent` after encryption
  - Deleting a note soft-deletes and removes from FTS5

---

#### Task 1.5: Wire Encryption into Tags and Collections

- **Description**: Tags and collections also use encrypted names. Apply the same per-item key derivation and encryption pattern to tags and collections CRUD.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 1.4
- **Effort**: S (2-3 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/tags_dao.dart`
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/collections_dao.dart`
  - `/home/ubuntu/projects/any-note/frontend/lib/features/tags/` (if tag management UI exists)
- **Acceptance Criteria**:
  - Tag names are encrypted with per-item key before storage
  - Collection titles are encrypted with per-item key before storage
  - Plain name/title caches are populated for local display
  - Tag-collections CRUD round-trips through encrypt/decrypt correctly

---

#### Task 1.6: Settings Persistence and Backend Integration

- **Description**: Settings screens (LLM config, platform connections, encryption status) have UI but no backend integration. Wire these screens to the API client to actually save/load settings.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 0.3
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/features/settings/presentation/llm_config_screen.dart` -- Wire to `ApiClient.listLlmConfigs()`, `createLlmConfig()`, etc.
  - `/home/ubuntu/projects/any-note/frontend/lib/features/settings/presentation/platform_connection_screen.dart` -- Wire to `ApiClient.listPlatforms()`, `connectPlatform()`, etc.
  - `/home/ubuntu/projects/any-note/frontend/lib/features/settings/presentation/encryption_screen.dart` -- Show encryption status, key fingerprint, recovery key
  - `/home/ubuntu/projects/any-note/frontend/lib/features/settings/presentation/settings_screen.dart` -- Wire sync status, AI quota display
  - Create Riverpod providers in `features/settings/data/` and `features/settings/domain/` directories
- **Acceptance Criteria**:
  - LLM config screen can create, update, delete, and test LLM configurations
  - Platform connection screen shows available platforms and connection status
  - Encryption screen shows current encryption state and recovery key
  - Settings screen shows real sync status and AI quota from server
  - State changes persist across app restarts

---

### Phase 2: Sync & AI (Priority: P1) — COMPLETED

All 5 tasks completed: sync with real encryption, token refresh, 4-stage AI composition workflow, structured logging, LLM retry logic.

#### Task 2.1: Integrate Real Encryption into Sync Engine

- **Description**: The sync engine currently passes around encrypted data but does not actually encrypt/decrypt. The pull flow must decrypt incoming blobs using per-item keys, and the push flow must encrypt outgoing data.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 1.4, Task 1.5
- **Effort**: L (1 day)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/core/sync/sync_engine.dart` -- Add encryption/decryption to `pull()` and `push()` flows
  - `/home/ubuntu/projects/any-note/frontend/lib/core/sync/sync_queue.dart` -- Ensure queue items are encrypted before push
  - `/home/ubuntu/projects/any-note/frontend/lib/core/crypto/encryptor.dart` -- Ensure `encryptBlob`/`decryptBlob` work with per-item keys
- **Acceptance Criteria**:
  - Pull: received encrypted blobs are decrypted using per-item keys and stored in local DB
  - Push: local changes are encrypted using per-item keys before sending to server
  - Conflict resolution still works after encryption integration
  - Sync is idempotent: running sync twice produces same result

---

#### Task 2.2: Add Token Refresh to API Client

- **Description**: The `_AuthInterceptor` in `api_client.dart` detects 401 errors and clears the access token, but does not attempt a token refresh. This means the user is logged out whenever their access token expires.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 0.3
- **Effort**: S (2-3 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/core/network/api_client.dart` -- Implement token refresh in `_AuthInterceptor.onError`, retry the failed request after refresh
  - `/home/ubuntu/projects/any-note/frontend/lib/main.dart` -- Store refresh token securely
- **Acceptance Criteria**:
  - When a 401 is received, the interceptor attempts token refresh using the stored refresh token
  - If refresh succeeds, the original request is retried with the new access token
  - If refresh fails, the user is redirected to the login screen
  - Refresh token is stored in secure storage (not memory only)

---

#### Task 2.3: Implement AI Composition Workflow

- **Description**: The AI compose feature has a landing page and prompt builder, but the actual workflow (select notes -> cluster -> outline -> draft -> style adapt) is unimplemented. Build the full 4-stage composition pipeline.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 1.4, Task 0.3
- **Effort**: L (2-3 days)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/presentation/compose_screen.dart` -- Add note selector, start compose button logic
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/presentation/cluster_screen.dart` -- Show clustered notes, allow user to select/reorder clusters
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/presentation/outline_screen.dart` -- Display generated outline, allow editing
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/presentation/compose_editor_screen.dart` -- Full editor with AI-generated content, inline editing
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/data/ai_repository.dart` -- May need to handle the multi-stage prompt flow
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/domain/prompt_builder.dart` -- Already exists, verify prompts work with real LLM responses
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/domain/cluster_model.dart` -- Verify model structure
  - `/home/ubuntu/projects/any-note/frontend/lib/features/compose/domain/outline_model.dart` -- Verify model structure
  - Create Riverpod providers for compose session state management
- **Acceptance Criteria**:
  - User can select multiple notes as source material
  - Stage 1 (Cluster): Notes are sent to AI for clustering, results displayed as cards
  - Stage 2 (Outline): AI generates an outline from selected clusters, user can edit
  - Stage 3 (Draft): AI expands outline into full content, displayed in editor
  - Stage 4 (Style Adapt): AI adapts content for target platform style
  - Streaming responses are displayed in real-time
  - User can save the composed content as a new note (encrypted) or as a GeneratedContent entry
  - Session state survives screen navigation within the compose flow

---

#### Task 2.4: Backend -- Add Structured Logging

- **Description**: The backend uses `log.Println` and `log.Printf` throughout. Replace with structured logging (e.g., `slog` from Go 1.21+ standard library) for better observability. Critical: never log request/response bodies for AI proxy endpoints (privacy).
- **Agent**: `go-backend-dev`
- **Dependencies**: None
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - All files in `/home/ubuntu/projects/any-note/backend/internal/handler/` -- Replace `log.*` with structured logger
  - All files in `/home/ubuntu/projects/any-note/backend/internal/service/` -- Replace `log.*` with structured logger
  - `/home/ubuntu/projects/any-note/backend/internal/config/config.go` -- Add log level configuration
  - `/home/ubuntu/projects/any-note/backend/cmd/server/main.go` -- Initialize structured logger
  - `/home/ubuntu/projects/any-note/backend/cmd/worker/main.go` -- Same
- **Acceptance Criteria**:
  - All log statements use structured logging with key-value pairs
  - Request logs include: method, path, status, duration, user_id (if authenticated)
  - AI proxy endpoint logs NEVER include request or response bodies
  - Log level is configurable via config.yaml
  - Error logs include stack traces

---

#### Task 2.5: Backend -- Add Retry Logic for LLM Gateway

- **Description**: LLM API calls can fail transiently (rate limits, timeouts, server errors). The gateway should retry with exponential backoff for transient failures.
- **Agent**: `go-backend-dev`
- **Dependencies**: None
- **Effort**: M (3-4 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/backend/internal/llm/openai_compat.go` -- Add retry wrapper around HTTP calls
  - `/home/ubuntu/projects/any-note/backend/internal/llm/gateway.go` -- Add retry configuration to `GatewayConfig`
  - `/home/ubuntu/projects/any-note/backend/internal/llm/config.go` -- Add retry settings to config
- **Acceptance Criteria**:
  - Transient HTTP errors (429, 502, 503, 504) are retried up to 3 times
  - Retry uses exponential backoff: 1s, 2s, 4s
  - 429 rate limit responses respect `Retry-After` header if present
  - Non-retryable errors (400, 401, 403) fail immediately
  - Streaming connections are not retried (would duplicate output)

---

### Phase 3: Publishing (Priority: P2) — COMPLETED

All 5 tasks completed: XHS auth + publish, WeChat adapter, worker handlers, frontend publish workflow.

#### Task 3.1: Implement XHS (Xiaohongshu) Authentication Adapter

- **Description**: Implement the QR-code-based authentication flow for Xiaohongshu using chromedp. The adapter must connect to headless Chrome, navigate to the XHS creator page, extract the QR code, and poll for login completion.
- **Agent**: `go-backend-dev`
- **Dependencies**: None
- **Effort**: L (2-3 days)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/backend/internal/platform/xiaohongshu/adapter.go` -- Implement `Authenticate` method
  - `/home/ubuntu/projects/any-note/backend/internal/platform/adapter.go` -- May need to extend `Authenticate` signature to return QR code data
  - `/home/ubuntu/projects/any-note/backend/internal/handler/platform_handler.go` -- Add SSE endpoint for streaming QR code data to client
  - `/home/ubuntu/projects/any-note/backend/internal/service/platform_service.go` -- Orchestrate auth flow
  - `/home/ubuntu/projects/any-note/backend/internal/domain/types.go` -- May need `QRCodeResponse` type
  - `/home/ubuntu/projects/any-note/docker-compose.yml` -- Ensure Chrome headless service is configured correctly
- **Acceptance Criteria**:
  - `/platforms/xiaohongshu/connect` returns a QR code image for the client to display
  - Client polls `/platforms/xiaohongshu/verify` for auth completion
  - Upon successful QR scan, cookies are extracted and encrypted for storage
  - Auth state is persisted in `platform_connections` table
  - Cookie encryption uses server-side AES-256-GCM master key

---

#### Task 3.2: Implement XHS (Xiaohongshu) Publish Adapter

- **Description**: Implement the publish flow that loads saved cookies, navigates to the XHS publish page, fills in title/content/tags, uploads images, and submits the post.
- **Agent**: `go-backend-dev`
- **Dependencies**: Task 3.1
- **Effort**: L (2-3 days)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/backend/internal/platform/xiaohongshu/adapter.go` -- Implement `Publish` and `CheckStatus` methods
  - `/home/ubuntu/projects/any-note/backend/internal/service/publish_service.go` -- Wire to queue for async processing
  - `/home/ubuntu/projects/any-note/backend/internal/queue/queue.go` -- Ensure publish job is properly enqueued
- **Acceptance Criteria**:
  - Publish adapter loads cookies, navigates to publish page, fills form, submits
  - Image upload works for up to 9 images
  - Tags are properly added to the post
  - Returns published post URL and platform ID
  - `CheckStatus` verifies post is still live
  - Handles failures gracefully (session expired, form validation errors)

---

#### Task 3.3: Implement Worker Task Handlers

- **Description**: The asynq queue can enqueue jobs but the worker's `HandleFunc` is never called with actual handlers. Implement task handlers for AI proxy jobs and publish jobs that process them via the platform adapters.
- **Agent**: `go-backend-dev`
- **Dependencies**: Task 3.2
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/backend/internal/queue/queue.go` -- Register actual handlers
  - Create `/home/ubuntu/projects/any-note/backend/internal/queue/handlers.go` -- AI proxy handler, publish handler
  - `/home/ubuntu/projects/any-note/backend/cmd/worker/main.go` -- Initialize worker with handlers
  - `/home/ubuntu/projects/any-note/backend/internal/service/publish_service.go` -- Wire queue into publish flow
- **Acceptance Criteria**:
  - Worker process starts and connects to Redis
  - AI proxy jobs are processed (for shared LLM mode)
  - Publish jobs are processed via the correct platform adapter
  - Job results are stored (publish log status updated)
  - Failed jobs are retried per queue configuration
  - Graceful shutdown completes in-progress jobs

---

#### Task 3.4: Implement WeChat Platform Adapter

- **Description**: Create a WeChat adapter following the same pattern as XHS. WeChat publishing may use a different flow (OAuth-based or cookie-based, depending on WeChat Official Account platform).
- **Agent**: `go-backend-dev`
- **Dependencies**: None (can be done in parallel with XHS)
- **Effort**: L (2-3 days)
- **Files Involved**:
  - Create `/home/ubuntu/projects/any-note/backend/internal/platform/wechat/adapter.go` -- Full implementation
  - `/home/ubuntu/projects/any-note/backend/internal/service/platform_service.go` -- Register wechat adapter
  - `/home/ubuntu/projects/any-note/backend/cmd/server/main.go` -- Register wechat adapter in registry
- **Acceptance Criteria**:
  - WeChat adapter implements the `Adapter` interface
  - Authentication flow works (specific mechanism TBD -- see questions)
  - Publish flow creates a WeChat draft or publishes directly
  - Status check works

---

#### Task 3.5: Frontend -- Complete Publish Workflow

- **Description**: Wire the publish screens to backend APIs, show platform connection status, publish history, and allow users to select content and publish to a connected platform.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 3.1, Task 3.2, Task 0.3
- **Effort**: L (1-2 days)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/features/publish/presentation/publish_screen.dart` -- Wire to real platform data
  - `/home/ubuntu/projects/any-note/frontend/lib/features/publish/presentation/publish_history_screen.dart` -- Wire to `ApiClient.publishHistory()`
  - `/home/ubuntu/projects/any-note/frontend/lib/features/publish/data/` -- Create publish repository
  - `/home/ubuntu/projects/any-note/frontend/lib/features/publish/domain/` -- Create publish models
  - `/home/ubuntu/projects/any-note/frontend/lib/features/settings/presentation/platform_connection_screen.dart` -- Wire to QR code display for XHS auth
- **Acceptance Criteria**:
  - Publish screen shows real platform connection status
  - User can select a note or AI-composed content to publish
  - User can choose target platform
  - Publish action enqueues a publish job and shows progress
  - Publish history shows past publications with status
  - Platform connection screen shows QR code for XHS auth

---

### Phase 4: Polish & Testing (Priority: P2) — COMPLETED

All 7 tasks completed: backend unit tests (90 tests), backend integration tests (63 tests), crypto tests (76 tests), sync/DAO tests, FTS5 Chinese optimization, error handling, UX polish.

#### Task 4.1: Backend -- Comprehensive Unit Tests -- COMPLETED

- **Description**: Add unit tests for all service and repository layers. Currently only 4 test files exist.
- **Agent**: `go-backend-dev`
- **Dependencies**: Phase 0 complete
- **Effort**: L (2-3 days)
- **Status**: COMPLETED — 8 new test files (90 tests total). Fixed duplicate `StreamChunk` type bug in `provider.go` and `openai_compat.go`.
- **Files Involved**:
  - Create tests for each service:
    - `/home/ubuntu/projects/any-note/backend/internal/service/auth_service_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/service/sync_service_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/service/ai_proxy_service_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/service/llm_config_service_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/service/publish_service_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/service/platform_service_test.go`
  - Create tests for repository layer:
    - `/home/ubuntu/projects/any-note/backend/internal/repository/user_repository_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/repository/sync_blob_repository_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/repository/llm_config_repository_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/repository/publish_log_repository_test.go`
  - Create tests for LLM layer:
    - `/home/ubuntu/projects/any-note/backend/internal/llm/gateway_test.go`
    - `/home/ubuntu/projects/any-note/backend/internal/llm/openai_compat_test.go` (mock HTTP server)
  - Create tests for platform adapters:
    - `/home/ubuntu/projects/any-note/backend/internal/platform/xiaohongshu/adapter_test.go`
- **Acceptance Criteria**:
  - All service tests use mock repositories (interface-based)
  - Repository tests use test database or pgx pool mock
  - Test coverage > 70% for service layer
  - Test coverage > 50% for repository layer
  - All tests pass with `go test ./...`
  - LLM gateway tests verify SSE parsing with mock HTTP server

---

#### Task 4.2: Backend -- Integration Tests -- COMPLETED

- **Description**: Add integration tests that test the full HTTP request-to-response cycle, including middleware, handlers, and services.
- **Status**: COMPLETED — 5 handler test files, 63 tests (auth, sync, ai, llm_config, publish handlers).
- **Agent**: `go-backend-dev`
- **Dependencies**: Task 4.1
- **Effort**: M (1 day)
- **Files Involved**:
  - Create `/home/ubuntu/projects/any-note/backend/internal/handler/auth_handler_test.go`
  - Create `/home/ubuntu/projects/any-note/backend/internal/handler/sync_handler_test.go`
  - Create `/home/ubuntu/projects/any-note/backend/internal/handler/ai_handler_test.go`
  - Create `/home/ubuntu/projects/any-note/backend/internal/handler/llm_config_handler_test.go`
  - Create `/home/ubuntu/projects/any-note/backend/internal/handler/publish_handler_test.go`
- **Acceptance Criteria**:
  - Each handler test sends real HTTP requests through the router
  - Auth flow: register -> login -> refresh -> me, all verified
  - Sync flow: push blobs -> pull blobs -> status, verified
  - AI proxy: streaming SSE response verified
  - Token refresh on expired access token verified
  - All tests clean up after themselves (no test data pollution)

---

#### Task 4.3: Frontend -- Encryption Unit Tests -- COMPLETED

- **Description**: Write unit tests for the crypto module: encrypt/decrypt round-trip, key derivation determinism, nonce uniqueness, authentication tag verification.
- **Status**: COMPLETED — 3 test files, 76 tests (encryptor_test, master_key_test, crypto_service_test).
- **Agent**: `crypto-auditor`
- **Dependencies**: Task 1.1, Task 1.2
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/crypto/encryptor_test.dart`
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/crypto/master_key_test.dart`
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/crypto/key_storage_test.dart`
- **Acceptance Criteria**:
  - Encrypt/decrypt round-trip succeeds for strings, empty strings, and large content (100KB)
  - Key derivation is deterministic (same password + salt = same key)
  - Different salts produce different keys
  - Nonces are unique across multiple encrypt calls
  - Tampered ciphertext fails decryption with authentication error
  - Per-item key derivation produces unique keys per item ID

---

#### Task 4.4: Frontend -- Sync and DAO Tests

- **Description**: Write tests for the sync engine, conflict resolution, and DAO operations using an in-memory Drift database.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 0.3, Task 2.1
- **Effort**: M (1 day)
- **Files Involved**:
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/database/notes_dao_test.dart`
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/database/tags_dao_test.dart`
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/database/collections_dao_test.dart`
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/sync/conflict_resolver_test.dart`
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/sync/version_vector_test.dart`
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/sync/sync_engine_test.dart`
- **Acceptance Criteria**:
  - DAO tests cover CRUD, FTS5 search, soft delete, sync status
  - Conflict resolver tests cover: local wins, remote wins, timestamp tie, device ID tiebreaker
  - Version vector tests cover: increment, merge, getNewerItemIds, serialization
  - Sync engine tests cover: pull with empty DB, push unsynced items, conflict handling
  - All tests use in-memory database, no filesystem dependencies

---

#### Task 4.5: Frontend -- FTS5 Chinese Text Search Optimization -- COMPLETED

- **Description**: FTS5 needs proper Unicode tokenizer configuration for Chinese text search. The default FTS5 tokenizer does not handle CJK characters well.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Task 0.3
- **Effort**: M (4-6 hours)
- **Status**: COMPLETED — Schema v2, unicode61 tokenizer with CJK support, BM25 ranking, 25 tests.
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/app_database.dart` -- Update FTS5 virtual table creation with Unicode61 or custom tokenizer
  - `/home/ubuntu/projects/any-note/frontend/lib/core/database/daos/notes_dao.dart` -- Update search query if needed
  - Create `/home/ubuntu/projects/any-note/frontend/test/core/database/fts5_test.dart`
- **Acceptance Criteria**:
  - Chinese text is searchable by individual words/characters
  - Mixed Chinese/English content searches work correctly
  - Search performance is acceptable with 1000+ notes
  - Search handles punctuation and special characters gracefully

---

#### Task 4.6: Error Handling and User Feedback -- COMPLETED

- **Description**: Add proper error handling across the app: network errors, encryption errors, sync conflicts, auth failures. Display user-friendly error messages and loading states.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Phase 1 complete
- **Effort**: M (1 day)
- **Status**: COMPLETED — Centralized error infrastructure in `core/error/`, applied to 8 screens.
- **Files Involved**:
  - Create `/home/ubuntu/projects/any-note/frontend/lib/core/error/` -- Error types, error mapper
  - All screen files -- Add proper error handling and user feedback
  - `/home/ubuntu/projects/any-note/frontend/lib/core/network/api_client.dart` -- Standardize error handling
- **Acceptance Criteria**:
  - Network errors show "No internet connection" or "Server unreachable" messages
  - Auth errors redirect to login with explanatory message
  - Sync conflicts show notification to user
  - Encryption errors show clear error without exposing technical details
  - Loading states shown during all async operations
  - Snackbar or dialog for transient errors

---

#### Task 4.7: UX Polish -- Offline Indicators, Sync Status, Empty States -- COMPLETED

- **Description**: Add visual indicators for sync status (synced/pending/conflict), offline mode indicator, and polished empty states for all list screens.
- **Status**: COMPLETED — 3 reusable widgets (offline_banner, sync_status_badge, empty_state), integrated into 5 screens + router.
- **Agent**: `flutter-frontend-dev`
- **Dependencies**: Phase 1 complete
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `/home/ubuntu/projects/any-note/frontend/lib/features/notes/presentation/notes_list_screen.dart` -- Sync status badge, pull-to-refresh
  - `/home/ubuntu/projects/any-note/frontend/lib/routing/app_router.dart` -- Offline banner in MainShell
  - All list screens -- Consistent empty state designs
- **Acceptance Criteria**:
  - Notes list shows sync status icon per note (synced, pending, conflict)
  - Pull-to-refresh triggers sync
  - Top-level offline banner appears when device has no connectivity
  - All empty states have helpful messaging and call-to-action
  - Sync progress indicator (pulling X/Y, pushing X/Y)

---

## Task Dependency Graph

```
Phase 0 (parallel):
  0.1 LLM Config Bug ─────────────────────────────────┐
  0.2 Frontend Nonce Fix ─────────┐                    │
  0.3 Drift Code Gen ─────┐       │                    │
  0.4 Missing Route Files │       │                    │
                          │       │                    │
Phase 1 (sequential):     │       │                    │
  1.1 Real XChaCha20 ─────┼───────┘                    │
  1.2 Real Argon2id ──────┼───────┘                    │
  1.3 Auth Flow ──────────┤ (depends on 1.1 + 1.2)    │
  1.4 Note CRUD ──────────┤ (depends on 1.1 + 1.2)    │
  1.5 Tags/Collections ───┤ (depends on 1.4)          │
  1.6 Settings Wire Up ───┘ (depends on 0.3)          │
                          │                             │
Phase 2:                  │                             │
  2.1 Sync + Encryption ──┤ (depends on 1.4 + 1.5)    │
  2.2 Token Refresh ──────┤ (depends on 0.3)          │
  2.3 AI Compose ─────────┤ (depends on 1.4)          │
  2.4 Structured Logging ─┤ (independent)              │
  2.5 Retry Logic ────────┘ (independent)              │
                          │                             │
Phase 3:                  │                             │
  3.1 XHS Auth ───────────┤ (independent)              │
  3.2 XHS Publish ────────┤ (depends on 3.1)          │
  3.3 Worker Handlers ────┤ (depends on 3.2)          │
  3.4 WeChat Adapter ─────┤ (independent)              │
  3.5 Frontend Publish ───┘ (depends on 3.1, 3.2)     │
                          │                             │
Phase 4:                  │                             │
  4.1 Backend Unit Tests ─┤ (depends on Phase 0)       │
  4.2 Backend Integ Tests ┤ (depends on 4.1)          │
  4.3 Crypto Tests ───────┤ (depends on 1.1, 1.2)     │
  4.4 Sync/DAO Tests ─────┤ (depends on 0.3, 2.1)     │
  4.5 FTS5 Chinese ───────┤ (depends on 0.3)          │
  4.6 Error Handling ─────┤ (depends on Phase 1)       │
  4.7 UX Polish ──────────┘ (depends on Phase 1)       │
```

## Parallelism Opportunities

The following task groups can be executed in parallel by different agents:

| Group | Tasks | Agents |
|---|---|---|
| Phase 0 all | 0.1, 0.2, 0.3, 0.4 | go-backend-dev, crypto-auditor, flutter-frontend-dev |
| Crypto + DB | 1.1, 1.2 | crypto-auditor (both), or split |
| Backend independent | 2.4, 2.5, 3.1, 3.4 | go-backend-dev |
| Tests backend | 4.1, 4.2 | go-backend-dev |
| Tests frontend | 4.3, 4.4 | crypto-auditor, flutter-frontend-dev |
| UX improvements | 4.5, 4.6, 4.7 | flutter-frontend-dev |

## Effort Summary

| Phase | Tasks | Estimated Total |
|---|---|---|
| Phase 0: Critical Fixes | 4 tasks | 4-6 hours |
| Phase 1: Core Foundation | 6 tasks | 3-4 days |
| Phase 2: Sync & AI | 5 tasks | 4-5 days |
| Phase 3: Publishing | 5 tasks | 6-9 days |
| Phase 4: Polish & Testing | 7 tasks | 5-7 days |
| **Total** | **27 tasks** | **18-31 days** |

---

## Questions That Need Further Clarification

### Question 1: Flutter Crypto Package Selection

For XChaCha20-Poly1305, there are multiple Flutter package options. The choice affects Task 1.1.

**Recommended Solutions**:

- Solution A: `sodium_libs` -- Full libsodium binding, includes XChaCha20-Poly1305, Argon2id, and HKDF in one package. Most comprehensive but larger binary size.
- Solution B: `sodium` (nativecryptography) -- Lighter wrapper around libsodium. Similar API surface.
- Solution C: `cryptography` + `cryptography_flutter` -- Pure Dart with Flutter platform implementations. May not have XChaCha20-Poly1305 (only ChaCha20-Poly1305).

**Awaiting User Selection**:

```
Please select your preferred solution or provide other suggestions:
[ ] Solution A: sodium_libs (recommended)
[ ] Solution B: sodium
[ ] Solution C: cryptography
[ ] Other solution: ________
```

### Question 2: WeChat Authentication Method

WeChat Official Account platform has different auth mechanisms than XHS. This affects Task 3.4.

**Recommended Solutions**:

- Solution A: WeChat Official Account OAuth -- Standard OAuth flow, requires registered developer account. More stable but requires business verification.
- Solution B: Cookie-based login via chromedp -- Same approach as XHS. More fragile but works without developer registration.
- Solution C: Defer WeChat to post-MVP -- Focus on XHS first, add WeChat later based on user demand.

**Awaiting User Selection**:

```
Please select your preferred solution or provide other suggestions:
[ ] Solution A: WeChat OAuth
[ ] Solution B: Cookie-based (chromedp)
[ ] Solution C: Defer to post-MVP
[ ] Other solution: ________
```

### Question 3: Argon2id Flutter Package

For Argon2id key derivation, there are FFI-based and WASM-based options. This affects Task 1.2.

**Recommended Solutions**:

- Solution A: `argon2ffi` -- Native FFI binding, fast, but requires platform-specific build configuration.
- Solution B: `dart_argon2` -- Pure Dart via WASM compilation. Slower but no native build complexity.
- Solution C: Use libsodium's crypto_pwhash (Argon2id) via the same `sodium_libs` package from Question 1. Single dependency for all crypto.

**Awaiting User Selection**:

```
Please select your preferred solution or provide other suggestions:
[ ] Solution A: argon2ffi
[ ] Solution B: dart_argon2
[ ] Solution C: libsodium crypto_pwhash (recommended if using sodium_libs)
[ ] Other solution: ________
```

---

## Phase 14+: Production Hardening (Post-MVP)

### Phase 21: Production Hardening — COMPLETED

**Goal**: Fix accessibility, security, and test coverage gaps before production.

| Task | Status | Description |
|------|--------|-------------|
| WS0: Commit checkpoint | completed | Committed 239 files from phases 14-20 |
| WS1: WCAG AA Accessibility | completed | Fixed 3 contrast ratio failures, added focus indicators, touch targets, semantics wrappers |
| WS2: Security Headers | completed | Added SecurityHeaders middleware (X-Content-Type-Options, X-Frame-Options, HSTS, etc.) |
| WS3: Frontend Widget Tests | completed | Added widget tests for ~20 screens |
| WS4: Backend Test Coverage | completed | Added tests for share/comment handlers and services |
| WS5: CI/CD + Docs | completed | CI pipeline already existed, updated docs |

**Files Modified/Created**:
- `frontend/lib/core/theme/app_theme.dart` — WCAG AA contrast ratio fixes
- `frontend/lib/core/accessibility/a11y_utils.dart` — focus indicators, touch targets
- `frontend/lib/main.dart` — debug semantics overlay
- `backend/internal/handler/security_middleware.go` — NEW security headers middleware
- `backend/internal/handler/security_middleware_test.go` — NEW middleware tests
- `backend/internal/handler/router.go` — applied SecurityHeaders first in chain
- 20+ screen files — semantics wrappers, touch targets
- 20+ test files — widget and handler tests

---

## User Feedback Area

Please supplement your opinions and suggestions on the overall planning in this area:

```
User additional content:
_______________
_______________
_______________
```

---

## Phase 22: WebCrypto + Web Build — COMPLETED

**Goal**: Functional web build with E2E encryption via WebCrypto API.

| Task | Status | Description |
|------|--------|-------------|
| 22.1 WebCrypto encryption | completed | AES-256-GCM encrypt/decrypt via dart:js_interop + package:web |
| 22.2 WebCrypto key derivation | completed | PBKDF2 (600k iterations) + HMAC-SHA256 for web |
| 22.3 Web storage + build | completed | SharedPreferences for web keys, kIsWeb conditionals |
| 22.4 Web deployment | completed | CSP meta tag, PWA fields |

**Key files**: `encryptor_web.dart`, `encryptor_native.dart`, `master_key_web_compat.dart`, `master_key_native_compat.dart`, `web_crypto_compat.dart`

---

## Phase 23: Share Extension — COMPLETED

**Goal**: Share text/URLs/images from any app into AnyNote.

| Task | Status | Description |
|------|--------|-------------|
| 23.1 Android ShareActivity | completed | ACTION_SEND for text/plain, image/* |
| 23.2 iOS Share Extension | completed | ShareViewController with App Group |
| 23.3 Flutter share receiver | completed | MethodChannel listener + deep link routing |

**Key files**: `ShareActivity.kt`, `ShareViewController.swift`, `receive_share_service.dart`

---

## Phase 24: CRDT Collaboration — COMPLETED

**Goal**: Real-time multi-user editing with RGA CRDT.

| Task | Status | Description |
|------|--------|-------------|
| 24.1 CRDT editor controller | completed | Bridges TextEditingController <-> CRDTText |
| 24.2 CRDT broadcast over WS | completed | edit/cursor message types, CollabProvider |
| 24.3 Wire into NoteEditorScreen | completed | Real-time sync, presence UI |
| 24.4 CRDT persistence | completed | collabStates Drift table + DAO |
| 24.5 Backend edit relay | completed | Rate-limited (30 edits/s), Redis pub/sub, zero-knowledge |

**Key files**: `crdt_editor_controller.dart`, `collab_provider.dart`, `ws_handler.go`, `collab_dao.dart`

---

## Phase 25: Desktop Polish — COMPLETED

**Goal**: Native-feeling desktop app.

| Task | Status | Description |
|------|--------|-------------|
| 25.1 Menu bar | completed | PlatformMenuBar (macOS) / Material MenuBar (Win/Linux) |
| 25.2 Window state persistence | completed | Save/restore position/size/maximized |
| 25.3 Extended keyboard shortcuts | completed | Ctrl+P/W/,/Tab, F11, Escape |
| 25.4 Desktop UI refinements | completed | Animated sidebar, persisted divider, tooltips |

**Key files**: `app_menu_bar.dart`, `window_state.dart`, `keyboard_shortcuts.dart`, `sidebar_provider.dart`

---

## Phase 26: App Store Preparation — COMPLETED

**Goal**: All assets ready for App Store + Google Play submission.

| Task | Status | Description |
|------|--------|-------------|
| 26.1 App icons | completed | flutter_launcher_icons config |
| 26.2 Splash screens | completed | flutter_native_splash config |
| 26.3 Privacy policy | completed | doc/legal/privacy-policy.md |
| 26.4 Store screenshots | completed | Fastlane configs |
| 26.5 Release build config | completed | scripts/build-release.sh |
| 26.6 Store listing metadata | completed | Title, description, keywords, changelog |

---

## Phase 27: Production Readiness — COMPLETED

**Goal**: Clean up remaining code quality issues, verify all build targets, production deployment config.

### 27.1 Fix remaining lints ✅

No remaining lints. `flutter analyze` reports 0 issues. `restore_screen.dart` uses modern `RadioGroup` API.

### 27.2 Production Docker Compose ✅

`docker-compose.prod.yml` created with:
- Resource limits for all services
- Proper volume mounts for persistent data
- Health check configurations
- Three-tier network isolation (frontend/backend/data)

### 27.3 Web build verification ✅

PWA manifest valid (`web/manifest.json`). WebCrypto code paths implemented.

### 27.4 Backend production config ✅

- `LOG_LEVEL` and `LOG_FORMAT=json` in config
- Graceful shutdown with SIGINT/SIGTERM, 15s timeout
- Prometheus `/metrics` endpoint with request counter + duration histogram
- Database connection pool tuning (25 max open, 5 max idle, 5min lifetime)

### 27.5 Remaining test gaps ✅

- Widget tests for 6 uncovered screens (recovery, collection_detail, compose_editor, notes_list, import, restore)
- E2E encryption round-trip integration test (master key → per-item key → encrypt → decrypt)
- Backend repository layer tests for 8 repositories (user, sync_blob, shared_note, quota, comment, publish_log, llm_config, platform_connection) — 112 test cases total

---

## Phase 28: Code Quality & Security Hardening — COMPLETED

**Goal**: Fix audit findings from comprehensive codebase review — memory leaks, test reliability, input validation, and server-side resource management.

### 28.1 Fix ScrollController memory leak ✅

- **File**: `frontend/lib/features/notes/presentation/markdown_preview_screen.dart`
- **Issue**: `_MarkdownScrollView` (StatelessWidget) created `ScrollController()` in `build()` — every rebuild leaked a controller
- **Fix**: Converted to StatefulWidget with proper `dispose()` lifecycle

### 28.2 Fix Drift timer leak in widget tests ✅

- **File**: `frontend/lib/features/notes/presentation/notes_list_screen.dart`
- **Issue**: Drift's `StreamQueryStore.markAsClosed` creates undrainable `Timer(Duration.zero, ...)` during widget disposal, causing 4 test failures
- **Fix**: Added `@visibleForTesting autoLoad` parameter to suppress Drift watch subscription in tests
- **Tests**: All 3 NotesListScreen tests now pass (were failing with "A Timer is still pending")

### 28.3 Add deep link input validation ✅

- **File**: `frontend/lib/core/deep_link/deep_link_handler.dart`
- **Issue**: URI segments used directly in `context.push()` without validation
- **Fix**: Added `_isValidSegment()` and `_isValidId()` validators, early-return with `debugPrint` warning for invalid URIs
- **Validation rules**: max 256 chars, no path traversal (`..`), alphanumeric+hyphen only, UUID format for IDs

### 28.4 Add rate limiter eviction ✅

- **File**: `backend/internal/service/rate_limiter.go`
- **Issue**: In-memory `map[string]*slidingWindow` grows unbounded — memory leak under sustained load
- **Fix**: Lazy eviction every 100th `Allow()` call, scanning and removing expired windows; O(min(n,200)) per sweep
- **Tests**: 6 new eviction tests covering expiry, retention, bounded memory, and disabled mode

---

## Phase 29: Push Notifications, E2E Tests, Accessibility — COMPLETED

**Goal**: Implement push notification dispatch, end-to-end test suites, and accessibility audit.

### 29.1 FCM Push Notifications ✅

- **File**: `backend/internal/service/push_service.go`, `backend/internal/config/config.go`
- Implemented FCM push via `firebase.google.com/go/v4/messaging`
- Device token CRUD in PostgreSQL
- FirebaseConfig in app config (credentials file path, project ID)

### 29.2 E2E Integration Tests ✅

- **Backend**: `e2e_auth_flow_test.go`, `e2e_publish_flow_test.go`, `e2e_sync_flow_test.go`
- **Frontend**: `test/e2e/auth_flow_test.dart`, `test/e2e/note_crud_flow_test.dart`, `test/e2e/sync_flow_test.dart`
- Full flow coverage: auth registration/login/refresh, sync pull/push/conflict, publish queue/complete

### 29.3 Accessibility Audit ✅

- **File**: `frontend/lib/core/accessibility/a11y_utils.dart`
- Full WCAG 2.1 AA audit with screen reader semantics
- Test helpers: `frontend/test/helpers/test_app_helper.dart` (pumpScreen, FakeCryptoService, defaultProviderOverrides)
- `frontend/test/core/accessibility/` — accessibility-specific test cases

---

## Phase 30: Security Hardening + Sync Performance — COMPLETED

**Goal**: Address remaining security findings and optimize sync performance.

### 30.1 Body size limits ✅

- **File**: `backend/internal/handler/middleware.go`
- `MaxBodySize` middleware: 10MB default, 50MB for sync/push endpoints

### 30.2 SSE fix ✅

- **File**: `backend/internal/handler/ai_handler.go`
- Error payload now uses `json.Marshal` instead of `fmt.Fprintf` for proper SSE formatting

### 30.3 Auth validation ✅

- Field length limits: AuthKeyHash 128, Salt 64, RecoveryKey 1024
- Username regex: `^[a-zA-Z0-9_-]+$`

### 30.4 TOCTOU fix ✅

- **File**: `backend/internal/repository/sync_blob_repository.go`
- Upsert now uses atomic `INSERT ON CONFLICT DO UPDATE WHERE version < $4`

### 30.5 Sync performance ✅

- Cursor pagination: limit/cursor/HasMore/NextCursor
- `pgx.Batch` for bulk upsert
- Combined `GetStatusSummary` endpoint

### 30.6 WS/Docker hardening ✅

- Configurable WebSocket origins via `WS_ALLOWED_ORIGINS` env var
- Docker `cap_drop ALL`, `mem_limit`, `read_only`

---

## Phase 31: Security Hardening & Feature Completion — COMPLETED

**Goal**: Argon2id parameter upgrade, account deletion, and push notifications for publish/comments.

### 31.1 Worker graceful shutdown ✅

- Signal handling (SIGINT/SIGTERM, 5s timeout)

### 31.2 Expired share cleanup ✅

- Background job (hourly, cancellable on shutdown)

### 31.3 Account deletion ✅

- `DELETE /api/v1/auth/account` with auth key verification

### 31.4 JWT token_type claim separation ✅

- Access vs refresh token type claims

### 31.5 AI proxy max_tokens cap + DRY platform adapter ✅

- max_tokens cap based on user plan tier
- DRY platform adapter registration via appsetup package

### 31.6 MinIO health check + WS origins ✅

- BucketChecker interface in readiness endpoint
- Configurable WebSocket allowed origins

### 31.7 Argon2id parameter hardening ✅

- opsLimitSensitive + memLimitModerate with migration support
- KDF version tracking (v1 legacy, v2 current) with try-current-first fallback
- Share key derivation upgraded to stronger parameters
- Login flow: version-aware key derivation with automatic migration
- Registration: stores KDF version for new users

### 31.8 Push notifications for publish/comments ✅

- Push on publish completion and new comments

---

---

## Phase 32-40: Test Coverage & Feature Completion — COMPLETED

Incremental test coverage improvements across backend and frontend.

| Phase | Focus | Key Deliverables |
|-------|-------|------------------|
| 32 | Widget tests | Note editor, compose screens, publish screens |
| 33 | Provider tests | Riverpod provider coverage for auth, sync, settings |
| 34 | Service tests | Backend service layer edge cases |
| 35 | Integration tests | Handler→service→repo chain validation |
| 36 | DAO tests | Drift DAO query correctness |
| 37 | Screen tests | Remaining uncovered screens |
| 38 | Settings tests | LLM config, platform connections, encryption screen |
| 39 | UI tests | Theme, accessibility, responsive layout |
| 40 | Coverage audit | Gap analysis, prioritized remaining work |

---

## Phase 41-43: Tooling & Assessment — COMPLETED

### Phase 41: Project Tooling Configuration ✅

- Claude Code settings, hooks configuration
- Task management setup

### Phase 42: Quality Fixes from Assessment ✅

- Fixed lint warnings and test reliability issues
- Cleaned up dead code paths

### Phase 43: Widget and Provider Test Pass ✅

- 8 new test files covering settings, providers, and widgets
- PumpWidget helper infrastructure improvements

---

## Phase 44-45: Final Coverage Push — COMPLETED

### Phase 44: Widget and Provider Tests ✅

- 6 test files: accessibility, app components, design system widgets
- Settings group/item tests, master detail layout tests

### Phase 45: Fill Remaining Test Gaps ✅

- 10 test files, 3,283 lines
- App components (AppEmptyState, AppLoadingCard, AppErrorCard, etc.)
- Master-detail layout with draggable divider
- Presence indicator (join/leave/typing, overflow badge)
- Page transition builders
- Cluster/outline model serialization
- Key storage hex encode/decode
- Connectivity provider state management
- Database seed template validation
- AI repository DTO tests

---

## Phase 46: Code Quality Hardening — COMPLETED

**Goal**: Fix remaining code quality issues found during systematic backend review.

### 46.1 Frontend screen tests ✅

- `rich_note_editor_test.dart` — Toolbar configuration, theme adaptation, controller integration
- `shared_note_viewer_test.dart` — Server share detection (32-char hex), password mode, decryption paths

### 46.2 Backend error handling ✅

- `sync_service.go` — GetStatus and GetProgress now propagate errors instead of silently swallowing
- `ai_proxy_service.go` — IncrementUsage error logged instead of discarded
- `ai_job_handler.go` — Same IncrementUsage fix for worker path

### 46.3 Security improvements ✅

- JWT secret minimum length validation (16 chars) in AuthMiddleware
- Case-insensitive Bearer prefix matching per RFC 6750
- Pprof env vars require explicit truthy value (not just non-empty)
- Message count limit (max 100) for AI proxy requests
- Explicit `r.Body.Close()` on sync handlers

### 46.4 Performance ✅

- Rate limiter eviction removes full key slice allocation — O(1) per sampled key instead of O(n)

**Files changed**: 12 files, 564 insertions, 42 deletions

---

## Phase 47: Error Handling & Config Validation — COMPLETED

**Goal**: Eliminate all remaining silent error discards in backend production code, add startup config validation warnings.

### 47.1 Silent error discard fixes ✅

All `_ = ` patterns in backend production code replaced with proper error logging:
- `publish_job_handler.go` (4) — Publish status updates on failure paths now log via `slog.Error`
- `ws_handler.go` (2) — WebSocket join re-entry and rate limit error sends now log
- `publish_service.go` (1) — Enqueue failure status update logged
- `presence_service.go` (1) — Typing indicator cleanup on leave logged
- `quota_service.go` (2) — Quota reset checks now log warnings
- `platform_service.go` (1) — Revocation best-effort now logged
- `auth_service.go` (1) — Device token cleanup during account deletion logged
- `share_service.go` (1) — View count increment now logged
- Platform adapters (3) — Tag insertion fallbacks in wechat/xiaohongshu/zhihu use `slog.Debug`

### 47.2 Config startup validation ✅

New `Config.Warn()` method in `config.go`:
- Redis URL format validation (`redis://` or `rediss://`)
- Firebase credentials file existence check
- LLM default/fallback BaseURL format validation
- Server port range validation (1-65535)
- Called in `cmd/server/main.go` after `Validate()`

**Files changed**: 14 files, all backend

---

## Phase 48: Test Infrastructure & E2E Expansion — COMPLETED

**Goal**: Create shared test utilities to reduce duplication, expand E2E test coverage for share and AI proxy flows.

### 48.1 Shared test utilities package ✅

New `backend/internal/testutil/` package with:
- `GenerateTestToken` / `GenerateAccessToken` / `GenerateRefreshToken` — JWT token generation
- `SetupTestRouter` — chi router with standard middleware
- `DecodeJSON` — JSON response decoder with test failure
- `AssertHTTPError` — status code + error code assertion
- `AssertStatus` — simple status code assertion
- `NewJSONRequest` — JSON request builder with Content-Type header
- `SetBearerToken` — Authorization header helper
- `RandomUUID` — test UUID generator
- `MakeAuthResponse` — auth response builder

### 48.2 Share E2E flow tests ✅

New `e2e_share_flow_test.go` with 10 test functions:
- Full lifecycle: create -> get -> heart reaction -> discover feed
- Share with expiration, max views, password
- Expired share returns 410 Gone
- Max views reached returns 410 Gone
- Bookmark toggle, invalid reaction type
- Discover feed pagination
- Unauthorized create returns 401

### 48.3 AI proxy E2E flow tests ✅

New `e2e_ai_proxy_flow_test.go` with 6 test functions:
- SSE streaming with correct event format
- Quota exceeded returns 429
- Missing auth returns 401
- Empty messages validation
- Too many messages (>100) validation
- Non-streaming success response

**Files changed**: 4 new files (testutil helpers, doc.go, 2 E2E test files)
**E2E test count**: 29 total (13 existing + 16 new)

---

## Phase 49: Security Tests & Benchmarks — COMPLETED

**Goal**: Add security-focused handler tests and performance benchmarks for critical backend paths.

### 49.1 Security tests ✅

New `security_test.go` with 18 test functions across 4 groups:

**JWT Security (8 tests):**
- Invalid signature, modified payload, algorithm confusion (`alg:"none"`)
- Refresh token rejected from API endpoints
- Short secret panics at middleware init
- Case-insensitive Bearer prefix (RFC 6750)
- Expired token rejection, empty token after Bearer prefix

**Input Validation (6 tests):**
- Sync push oversized batch (>1000), empty batch, exact boundary (1000)
- AI proxy message limit (>100), batch delete limits

**Authorization (2 tests):**
- Cross-user access prevention, missing auth on sync endpoints

**Injection Vectors (2 tests):**
- SQL/XSS/JNDI strings in sync blob item_type pass through safely
- Username rejects XSS, SQL injection, LDAP injection, null bytes, path traversal

### 49.2 Performance benchmarks ✅

New `benchmark_test.go` (service) and `middleware_bench_test.go` (handler):

| Benchmark | ns/op | allocs/op |
|-----------|-------|-----------|
| RateLimiter.Allow (1000 keys) | 912 | 1 |
| RateLimiter.Eviction (10K expired) | 90 | 0 |
| SyncService.Push 100 blobs | 77,900 | 219 |
| SyncService.Push 1000 blobs | 842,195 | 2,027 |
| SyncService.Pull (100 blobs) | 50 | 1 |
| AuthMiddleware valid token | 12,803 | 71 |
| AuthMiddleware invalid token | 5,657 | 31 |
| AuthMiddleware missing token | 4,350 | 19 |

**Key findings:**
- Rate limiter eviction is essentially free (90 ns, zero allocs)
- Sync Pull service overhead is negligible (50 ns)
- Sync Push scales linearly with blob count
- Auth middleware: ~12.8us for valid JWT, ~4.4us for missing header rejection

**Files changed**: 4 new files (security_test.go, benchmark_test.go, middleware_bench_test.go)
**Test count**: +18 security tests, +12 benchmarks

---

## Phase 50: Frontend CRDT + Platform Tests — COMPLETED

**Goal**: Fill the largest test gaps in the Flutter frontend — CRDT collaboration (untested distributed system logic) and desktop/share platform features.

### 50.1 CRDT collaboration tests ✅

New `test/core/collab/` test files with 171 tests:

**`crdt_text_test.dart` (78 tests):**
- CRDTText basics: empty state, clock monotonicity, insert at positions, delete
- Local insert/delete behavior: unicode, node chaining, tombstone verification
- Remote convergence: concurrent same-position inserts, two/three-way merge, idempotent operations
- Remote insert causal dependency: leftOrigin/rightOrigin handling, Lamport clock
- Serialization: round-trip text, complex concurrent doc, RGANode JSON
- Edge cases: large merge, many-site convergence, delete beyond length
- Stress convergence: 10-site convergence, interleaved edits, concurrent multi-position

**`crdt_editor_controller_test.dart` (42 tests):**
- Local edits: insert/delete/replace emit ops, sequential typing, no-ops for empty change
- Diff detection: append, prepend, single char delete, replacement, clearing
- Remote operations: insert/delete, cursor preservation, initializeFromText
- Convergence: bidirectional sync, concurrent edits
- Cursor position: end, beginning, clamped after delete
- Dispose: closes stream, no ops after dispose

**`ws_client_test.dart` (51 tests):**
- WSMessage encode/decode: round-trip, all types, nested JSON, special characters, unicode
- WSClient construction: initial state, stream access
- Send when disconnected: all message types drop gracefully
- Connection state transitions: state emitted, connect no-op, error state
- Reconnection: multiple attempts, dispose during reconnect

### 50.2 Share extension tests ✅

New `test/core/share/receive_share_service_test.dart` with expanded tests:
- URL share intent parsing, subject + text preservation
- Deep link URL handling, empty data handling
- Invalid share types, multiple share items

### 50.3 Desktop platform tests ✅

New/expanded `test/core/storage/window_state_test.dart`:
- Negative dimensions, SharedPreferences key verification
- Type mismatch handling, multiple saves, WindowBounds defaults

New/expanded `test/core/widgets/app_menu_bar_test.dart`:
- MaterialMenuBar on Linux, PlatformMenuBar on macOS
- File/Edit/View/Help menu structure verification
- Keyboard shortcut activators, toggle sidebar, about/shortcuts dialogs
- PlatformUtils.modifierLabel, PlatformUtils.isDesktop

### 50.4 Compilation fixes ✅

Fixed pre-existing compilation errors in:
- `app_router.dart` — `.library.load()` -> `.loadLibrary()`
- `login_screen.dart` — missing `dart:typed_data` import
- `compose_screen.dart` — missing BuildContext parameter
- `compose_editor_screen.dart`, `outline_screen.dart` — l10n declaration order
- `publish_screen.dart` — missing child parameter
- `import_screen.dart` — missing function argument

**Files changed**: 6 new/expanded test files, 7 source file compilation fixes
**Test count**: +250 new tests (171 CRDT + 79 share/desktop)

---

## Phase 56: AI Module Hardening — COMPLETED

**Goal**: Comprehensive hardening of backend and frontend AI modules based on audit findings.

### 56.1 Backend: Shared HTTP client + connection pooling

- **File**: `backend/internal/llm/openai_compat.go`
- `openaiCompatProvider` now uses a shared `http.Client` with connection pooling instead of creating a new client per request

### 56.2 Backend: Stream cancellation via ctx.Done()

- **File**: `backend/internal/llm/openai_compat.go`, `backend/internal/handler/ai_handler.go`
- Both provider goroutine and handler monitor `ctx.Done()` for client disconnection
- Ensures goroutine cleanup when users navigate away mid-stream

### 56.3 Backend: Fallback LLM config

- **File**: `backend/internal/service/ai_proxy_service.go`
- Shared mode retries with fallback config when primary LLM fails
- Prevents single-provider outages from blocking all users

### 56.4 Backend: Per-chunk SSE limit

- **File**: `backend/internal/handler/ai_handler.go`
- 1MB max chunk size with truncation + warning log
- Prevents memory issues from oversized LLM responses

### 56.5 Backend: Prometheus metrics

- **File**: `backend/internal/handler/ai_metrics.go` (NEW)
- Request counter (total requests by provider/mode/status)
- Token counter (prompt + completion tokens)
- Active streams gauge (concurrent SSE connections)

### 56.6 Backend: Usage extraction + role validation

- LLM response usage data now populated in ChatResponse
- AI proxy validates ChatMessage.Role against system/user/assistant
- Provider CRUD validates against known provider list

### 56.7 Backend: User-scoped delete

- Repository delete query includes user_id in WHERE clause
- Prevents cross-user data deletion

### 56.8 Frontend: Content size limits

- Max 10 notes selected, 100K chars total for AI compose
- Clear user-facing error messages when limits exceeded

### 56.9 Frontend: ErrorMapper + CancelToken

- Compose module uses typed AppException errors via ErrorMapper
- Dio CancelToken cancels streaming on screen dispose

### 56.10 Frontend: Quota pre-check + concurrency guard

- AI operations check quota before starting (fail fast)
- Concurrency guard prevents parallel AI operations

### 56.11 Frontend: ResponseParser

- **File**: `frontend/lib/features/compose/domain/response_parser.dart` (NEW)
- Extracted `_extractJson` to domain layer for reuse

**Files changed**: Backend 13 modified + 1 new, Frontend 6 modified + 1 new, 1 test file updated

---

## Phase 80: Note Linking (Priority: P2) — COMPLETED

Wiki-style [[note links]] for bidirectional note connections. Pure local data, no server sync.

### 80.1 Wiki Link UI — COMPLETED

- **Description**: Users can type `[[` in the editor to trigger a note picker. Selected notes are embedded as clickable links. Backlinks panel shows which notes link to the current note.
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/embeds/wiki_link_embed.dart` (NEW) — Custom Quill embed builder for [[links]]
  - `frontend/lib/features/notes/presentation/widgets/wiki_link_picker_sheet.dart` (NEW) — Note picker bottom sheet
  - `frontend/lib/features/notes/presentation/widgets/backlinks_sheet.dart` (NEW) — Inbound links viewer
  - `frontend/lib/features/notes/presentation/widgets/related_notes_sheet.dart` (NEW) — Outbound links viewer
  - `frontend/lib/core/database/tables.dart` — Added NoteLinks table
  - `frontend/lib/core/database/daos/note_links_dao.dart` (NEW) — CRUD operations
  - `frontend/lib/core/database/app_database.dart` — Schema v9, migration added
  - `frontend/lib/features/notes/presentation/note_editor_screen.dart` — [[ syntax detection
  - `frontend/lib/features/notes/presentation/rich_note_editor.dart` — WikiLinkEmbedBuilder integration
- **Acceptance Criteria**:
  - Typing `[[` triggers note picker with search
  - Clicking [[link]] navigates to target note
  - Backlinks panel shows inbound links
  - Related notes panel shows outbound links
  - Local-only storage (no server sync)
  - Deleting a note cleans up all associated links

---

## Phase 81: Graph View (Priority: P2) — COMPLETED

Interactive force-directed graph visualization for note connections.

### 81.1 Graph Visualization — COMPLETED

- **Description**: Visual graph showing notes as nodes and links as edges using a force-directed layout. Supports pan, zoom, and tap-to-navigate.
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/widgets/note_graph_screen.dart` — Complete rewrite with local data provider
  - `frontend/lib/features/notes/presentation/notes_list_screen.dart` — Added graph button
- **Acceptance Criteria**:
  - Force-directed layout algorithm with repulsion and spring forces
  - Pan and zoom support (0.5x to 3x)
  - Tap nodes to navigate to note editor
  - Hover effects for better UX
  - Empty state with helpful message
  - Local-only data using NoteLinksDao

### 81.2 Graph Integration — COMPLETED

- **Description**: Added action buttons to graph screen for suggestions, orphaned notes, and link management.
- **Effort**: S (1-2 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/widgets/note_graph_screen.dart` — Added AppBar actions
- **Acceptance Criteria**:
  - Suggestions button opens link suggestions sheet
  - Orphaned notes button shows disconnected notes
  - Link management button opens management sheet
  - Reset view button refreshes the graph

---

## Phase 82: Advanced Link Features (Priority: P2) — COMPLETED

Enhanced link management with content-based suggestions, orphaned notes detection, and unified link management interface.

### 82.1 Link Suggestions — COMPLETED

- **Description**: Suggest potential links based on content similarity using word overlap (Jaccard index).
- **Effort**: M (3-4 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/widgets/link_suggestions_sheet.dart` — NEW
- **Acceptance Criteria**:
  - Analyze note titles and content for similarity
  - Filter out already-linked notes
  - One-tap link creation
  - Show top 10 suggestions with similarity threshold > 0.1

### 82.2 Orphaned Notes — COMPLETED

- **Description**: Identify notes with no connections to help users connect their knowledge graph.
- **Effort**: S (1-2 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/widgets/orphaned_notes_sheet.dart` — NEW
- **Acceptance Criteria**:
  - Detect notes with zero inbound and outbound links
  - Sort by update date (most recent first)
  - Tap to navigate and add connections
  - Empty state when all notes are connected

### 82.3 Link Management — COMPLETED

- **Description**: Unified interface for viewing and deleting both backlinks and outbound links.
- **Effort**: M (3-4 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/widgets/link_management_sheet.dart` — NEW
- **Acceptance Criteria**:
  - Filter chips for backlinks vs outbound
  - Delete links with confirmation
  - Navigate to linked notes
  - Visual indicators for link direction

---

## Phase 83: Note Transclusion (Priority: P2) — COMPLETED

Embed content from one note into another with live preview and sync across linked notes.

### 83.1 Transclusion Syntax — COMPLETED

- **Description**: Add `![[note]]` syntax for embedding note content, similar to Obsidian.
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/embeds/transclusion_embed.dart` — NEW
  - `frontend/lib/features/notes/presentation/rich_note_editor.dart` — Add transclusion embed builder
  - `frontend/lib/features/notes/presentation/note_editor_screen.dart` — Add `![[` pattern detection
- **Acceptance Criteria**:
  - Type `![[` to trigger transclusion picker
  - Render embedded note content inline
  - Support nested transclusions (with depth limit)
  - Prevent circular transclusion loops

### 83.2 Live Sync — COMPLETED

- **Description**: When embedded note changes, update all transclusions automatically.
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/embeds/transclusion_embed.dart` — Update mechanism
  - `frontend/lib/core/database/daos/notes_dao.dart` — Added watchNoteById method
- **Acceptance Criteria**:
  - Watch for note updates
  - Invalidate transclusion cache on change
  - Update all embedding notes
  - Handle deleted target notes gracefully

### 83.3 Transclusion UI — COMPLETED

- **Description**: Visual indication and controls for transcluded content blocks.
- **Effort**: S (2-3 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/embeds/transclusion_embed.dart` — UI components
- **Acceptance Criteria**:
  - Visual border/background for embedded content ✓
  - "Edit original" button to jump to source ✓
  - Show source note title as caption ✓
  - Expand/collapse toggle ✓
  - "Unlink" feature omitted (requires complex Quill embed manipulation, out of scope)

---

## Phase 84: Note Properties/Metadata System — COMPLETED

Custom key-value metadata system for notes with built-in and custom properties.

### 84.1 Database Schema — COMPLETED

- **Description**: Add NoteProperties table for storing custom metadata (status, priority, dates, etc).
- **Effort**: S (2-3 hours)
- **Files Involved**:
  - `frontend/lib/core/database/tables.dart` — Add NoteProperties table
  - `frontend/lib/core/database/app_database.dart` — Add NotePropertiesDao, migration v9→v10
- **Acceptance Criteria**:
  - Support text, number, date property types
  - Cascade delete when note is deleted
  - Index on noteId for efficient queries

### 84.2 DAO Layer — COMPLETED

- **Description**: CRUD operations for note properties with type-safe getters.
- **Effort**: S (2-3 hours)
- **Files Involved**:
  - `frontend/lib/core/database/daos/note_properties_dao.dart` — NEW
- **Acceptance Criteria**:
  - Create/update/delete properties
  - Watch properties for note (reactive stream)
  - Built-in properties: status, priority, due_date, start_date
  - Type-safe getters for text/number/date values

### 84.3 UI — Properties Panel — COMPLETED

- **Description**: Bottom sheet for viewing and editing note properties.
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/widgets/properties_sheet.dart` — NEW
  - `frontend/lib/features/notes/presentation/note_editor_screen.dart` — Add properties button
- **Acceptance Criteria**:
  - Properties button in note editor app bar
  - List all properties for current note
  - Add/edit/delete properties
  - Built-in properties with predefined options (status: Todo/In Progress/Done/Blocked/Cancelled, priority: High/Medium/Low)
  - Custom properties support (UI placeholder)
  - Date picker for date properties

### 84.4 Property Display in Notes List — COMPLETED

- **Description**: Show key properties (status, priority, due dates) as badges in notes list.
- **Effort**: S (2-3 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/widgets/property_badges.dart` — NEW
  - `frontend/lib/features/notes/presentation/widgets/note_card.dart` — Add PropertyBadges widget
- **Acceptance Criteria**:
  - Status badge with color coding
  - Priority badge with icon
  - Date badges (due date, start date) with overdue indication
  - Empty state when no properties set

---

## Phase 85: Properties Filtering & Quick Actions — COMPLETED

Filter and manage note properties directly from the notes list.

### 85.1 Filter UI — COMPLETED

- **Description**: Add filter chips to notes list for filtering by status, priority, date range.
- **Effort**: M (4-6 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/notes_list_screen.dart` — Add filter chips and state
  - `frontend/lib/features/notes/presentation/widgets/property_filter_chips.dart` — NEW
- **Acceptance Criteria**:
  - Filter chips shown below search bar
  - Filter by status (Todo, In Progress, Done, Blocked, Cancelled)
  - Filter by priority (High, Medium, Low)
  - Multiple filters can be active (AND logic)
  - Clear all filters button
  - Filter state persists across navigation

### 85.2 Quick Actions — COMPLETED

- **Description**: Long-press or swipe actions to quickly set status/priority.
- **Effort**: S (2-3 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/notes_list_screen.dart` — Add quick action menu
  - `frontend/lib/features/notes/presentation/widgets/note_card.dart` — Add quick action buttons
- **Acceptance Criteria**:
  - Tap status badge to cycle through statuses
  - Long-press note to show quick actions menu
  - Set status from quick actions
  - Set priority from quick actions

### 85.3 Properties Dashboard — COMPLETED

- **Description**: Screen showing statistics and grouped views by properties.
- **Effort**: S (2-3 hours)
- **Files Involved**:
  - `frontend/lib/features/notes/presentation/widgets/properties_dashboard.dart` — NEW
  - `frontend/lib/features/notes/presentation/notes_list_screen.dart` — Add dashboard button
  - `frontend/lib/routing/app_router.dart` — Add /notes/dashboard route
  - `frontend/lib/core/database/daos/note_properties_dao.dart` — Add getAllProperties()
  - `frontend/lib/l10n/app_*.arb` — Add localization strings
- **Acceptance Criteria**:
  - Show notes grouped by status (kanban-style columns)
  - Show priority distribution chart with color-coded bars
  - Tap a group to show status filter hint
  - Route: `/notes/dashboard` accessible from notes list app bar
  - Empty state when no notes exist
  - Full localization support (EN, ZH, JA, KO)

---

## Phase 86: Daily Notes / Journal System — COMPLETED

Date-based daily notes with calendar navigation and automatic naming.

### 86.1 Database & DAO — COMPLETED

- **Description**: Use existing NoteProperties table with `key='daily_note_date'` to mark daily notes. Added DAO queries for finding/creating daily notes.
- **Files Modified**: `frontend/lib/core/database/daos/note_properties_dao.dart`

### 86.2 Daily Notes Screen — COMPLETED

- **Description**: Calendar-based daily notes screen with month navigation, dot indicators, and quick-create.
- **Files Created**: `frontend/lib/features/notes/presentation/daily_notes_screen.dart`
- **Files Modified**: `frontend/lib/routing/app_router.dart`, `frontend/lib/features/notes/presentation/notes_list_screen.dart`

### 86.3 Localization — COMPLETED

- 11 new strings across EN, ZH, JA, KO

---

## Phase 87: Command Palette & Quick Navigation — COMPLETED

Ctrl/Cmd+K command palette for quick search, actions, and navigation.

### 87.1 Command Palette Overlay — COMPLETED

- **Files Created**: `frontend/lib/features/notes/presentation/widgets/command_palette.dart`
- **Features**: Full-screen overlay, fuzzy search, keyboard navigation, recently opened notes, action shortcuts

### 87.2 Keyboard Shortcut Integration — COMPLETED

- **Files Modified**: `frontend/lib/core/widgets/keyboard_shortcuts.dart`, `frontend/lib/main.dart`

### 87.3 Localization — COMPLETED

- 13 new strings across EN, ZH, JA, KO

---

## Phase 88: Slash Commands & Block Shortcuts — COMPLETED

Slash commands in the rich text editor for inserting blocks.

### 88.1 Slash Command Menu — COMPLETED

- **Files Created**: `frontend/lib/features/notes/presentation/widgets/slash_command_menu.dart`
- **Features**: 14 block types (headings, lists, code, quote, divider, table, image, wiki link, transclusion, callout), keyboard navigation, fuzzy filtering

### 88.2 Editor Integration — COMPLETED

- **Files Modified**: `frontend/lib/features/notes/presentation/rich_note_editor.dart`, `frontend/lib/features/notes/presentation/note_editor_screen.dart`

### 88.3 Localization — COMPLETED

- 16 new strings across EN, ZH, JA, KO

---

## Phase 89: Split View / Multi-pane Editing — COMPLETED

Side-by-side note editing on wide screens.

### 89.1 Split View Pane — COMPLETED

- **Files Created**: `frontend/lib/features/notes/presentation/widgets/split_view_pane.dart`, `frontend/lib/features/notes/presentation/widgets/split_note_picker_sheet.dart`
- **Features**: Draggable divider (min 300px/pane), secondary pane header with close button, 50/50 default split

### 89.2 Integration — COMPLETED

- **Files Modified**: `frontend/lib/features/notes/presentation/notes_list_screen.dart`
- **Features**: Split view toggle in detail pane toolbar, note picker for secondary pane

### 89.3 Localization — COMPLETED

- 4 new strings across EN, ZH, JA, KO

---

## Phase 90: Advanced Search with Search Operators — COMPLETED

Structured search operators, saved searches, and search history.

### 90.1 Search Query Parser — COMPLETED

- **Files Created**: `frontend/lib/features/notes/domain/search_query_parser.dart`
- **Supported operators**: `tag:`, `status:`, `priority:`, `date:`, `collection:`, `links:`

### 90.2 Enhanced DAO Queries — COMPLETED

- **Files Modified**: `frontend/lib/core/database/daos/notes_dao.dart`
- **Features**: `advancedSearch()` method with multi-table joins and FTS5

### 90.3 Saved Searches — COMPLETED

- **Files Modified**: `frontend/lib/core/database/tables.dart` (SavedSearches table), `frontend/lib/core/database/app_database.dart` (schema v11, migration v10→v11)
- **Files Created**: `frontend/lib/core/database/daos/saved_searches_dao.dart`

### 90.4 Search History — COMPLETED

- **Files Created**: `frontend/lib/features/notes/domain/search_history.dart`
- **Features**: SharedPreferences-backed, max 20 entries, deduped

### 90.5 Advanced Search Screen — COMPLETED

- **Files Created**: `frontend/lib/features/search/presentation/advanced_search_screen.dart`, `frontend/lib/features/search/data/search_providers.dart`
- **Features**: Tabbed operator hints, search history chips, saved searches, result highlighting

### 90.6 Localization — COMPLETED

- 20 new strings across EN, ZH, JA, KO

---

## Phase 91: Image & Attachment Management — COMPLETED

- **Image gallery viewer** with pinch-zoom, swipe, share, delete
- **Image management screen** in settings (total storage, orphaned image cleanup)
- **Enhanced image picker** with gallery/camera/paste-from-clipboard options
- **Note card thumbnails** in grid view
- Route: `/settings/images`

## Phase 92: Focus Mode & Writing Experience — COMPLETED

- **WritingStats** data class with CJK-aware word/char/line/paragraph counting
- **WritingStatsBar** compact overlay showing live stats during editing
- **FocusHighlight** spotlight overlay that dims non-current lines
- **Typewriter scrolling** mode to keep cursor centered
- Integrated with Zen mode chrome for unified distraction-free experience

## Phase 93: Note Version Diffing — COMPLETED

- **LCS-based text diff algorithm** (`text_diff.dart`) for comparing note versions
- **Version diff screen** with color-coded unified diff view (green additions, red deletions)
- **Multi-select version comparison** from version history screen
- **Restore actions** with automatic pre-restore snapshot
- Route: `/notes/:id/diff?older=xxx&newer=yyy`

## Phase 94: Markdown Export & Interop — COMPLETED

- **MarkdownExportService** with YAML frontmatter generation
- **ExportOrganization** modes: flat, by date, by collection, by tag
- **ZIP archive export** for batch note exports
- **ExportSheet** bottom sheet for configuring export options
- **YAML frontmatter parser** for round-trip import support
- Single note share as `.md`, multiple notes as `.zip`

## Phase 95: Note Statistics & Writing Insights — COMPLETED

- **NoteStatistics** with SQL aggregation (word counts, activity, streaks)
- **StatisticsScreen** with overview cards, streak calendar, monthly activity chart
- **Top tags/collections** rankings, status/priority distribution charts
- **Knowledge graph stats** (total links, orphaned notes, most connected)
- CustomPaint-based charts (no external chart dependencies)
- Route: `/notes/statistics`

## Phase 96: Markdown Import & Obsidian Vault Import — COMPLETED

- **MarkdownImportService** with frontmatter parsing (reuses `parseYamlFrontmatter`)
- **ImportSheet** bottom sheet with file/ZIP/folder picker
- **Obsidian vault import**: `[[wiki links]]` conversion, `![[image]]` embed handling, image copy
- **ZIP import** for batch `.md` file imports
- Property extraction from frontmatter (status, priority, dates)

## Phase 97: Note Templates Library — COMPLETED

- **NoteTemplates table** (schema v12) with name, description, content, category, usage tracking
- **7 built-in templates**: Meeting Notes, Daily Journal, Project Plan, Reading Notes, Weekly Review, Brainstorm, Blank
- **TemplatePickerSheet** with search, category filters, 2-column grid
- **TemplateManagementScreen** for CRUD on user templates, duplicate built-in
- Route: `/settings/templates`

## Phase 98: Quick Capture — COMPLETED

- **QuickCaptureScreen** minimal full-screen overlay with auto-save debounce
- **Quick actions** (home screen shortcuts): New Note, New Checklist, Daily Note
- Priority selector, tag picker in bottom toolbar
- Swipe-to-dismiss with draft confirmation
- Route: `/quick-capture`

## Phase 99: Offline Queue & Sync Resilience — COMPLETED

- **SyncOperations table** with retry tracking, exponential backoff, nextRetryAt
- **SyncOperationsDao** with enqueue, process, retry, clear operations
- **OfflineQueueService** Riverpod notifier with reactive queue status
- **SyncStatusIndicator** compact app bar dot (green/yellow/red)
- **SyncQueueSheet** bottom sheet with pending/failed counts, retry/clear actions

## Phase 100: Lint Cleanup — COMPLETED

- Fixed 4 lint issues: 3 trailing commas, 1 deprecated `value` → `initialValue` API
- Files: quick_capture_screen.dart, template_picker.dart, sync_queue_sheet.dart

## Phase 101: Note Color-Coding System — COMPLETED

- **Database v13**: Added `color TEXT` column to Notes, Tags, Collections tables
- **ColorPickerSheet**: Bottom sheet with 18 predefined Material colors + custom hex input
- **Note cards**: Colored left border (list) / top border (grid), color dot indicator
- **Tags**: Color dot avatar, long-press edit menu with color picker
- **Collections**: Colored folder icons, long-press edit menu with color picker
- **Search**: `color:#FF5722` or `color:red` operator in search query parser
- **Advanced search**: Color filter chip integration
- 7 l10n keys added across EN/ZH/JA/KO

## Phase 102: Note Reminders — COMPLETED

- **ReminderService**: Polling-based (60s Timer) reminder checker with Riverpod provider
- **NoteProperties storage**: `reminder_at`, `reminder_title`, `reminder_recurring`, `reminder_fired_at` keys
- **ReminderPickerSheet**: Preset options (later today, tomorrow, next week), custom date/time, recurring selector
- **RemindersScreen**: List of upcoming reminders sorted by time, tap-to-open, swipe-to-cancel
- **Note editor**: Bell icon in app bar with badge indicator for active reminders
- **Notes list**: Notification icon navigating to reminders screen
- **Route**: `/notes/reminders`
- 15 l10n keys added across EN/ZH/JA/KO

## Phase 103: Accessibility Improvements — COMPLETED

- **SemanticOrder**: Focus traversal utility with `OrderedTraversalPolicy` for logical tab order
- **Note cards**: Full Semantics wrapper with localized labels, pin indicator, decorative exclusion
- **Dismissible cards**: Semantics labels for swipe actions (delete, archive, restore)
- **Rich editor**: Semantics label + hint on QuillEditor area
- **Graph view**: Text alternative summary with node/link counts
- **Settings**: Section grouping with `Semantics(container: true)`, toggle switch hints
- **Collections/Tags**: FAB semantic labels, dismissible card labels
- **Daily notes**: Calendar day cell semantic labels
- **Quick capture**: TextField semantic label
- **Routing**: `_PhoneShell` wrapped in `FocusTraversalGroup` with ordered traversal
- 16 l10n keys added across EN/ZH/JA/KO

## Phase 104: Batch Color + Note Locking — COMPLETED

- **Batch color**: Palette icon in multi-select toolbar opens ColorPickerSheet, applies to all selected notes
- **Note locking**: `is_locked` key in NoteProperties, lock/unlock in editor AppBar, read-only mode with banner
- **NoteCard**: Lock icon indicator on locked cards
- **Rich editor**: `readOnly` parameter hides toolbar, disables editing
- **Long-press menu**: Lock/unlock options in context menu
- **Batch lock**: Lock/unlock button in multi-select toolbar
- 11 l10n keys added across EN/ZH/JA/KO

## Phase 105: Note Comparison Diff — COMPLETED

- **NoteCompareScreen**: Side-by-side and unified diff views using TextDiff LCS algorithm
- **NoteComparePicker**: Bottom sheet to select exactly 2 notes for comparison
- **Batch integration**: Compare button visible when exactly 2 notes selected
- **Route**: `/notes/compare?left={id1}&right={id2}`
- **Color-coded**: Green additions, red deletions, synchronized scrolling
- 9 l10n keys added across EN/ZH/JA/KO

## Phase 106: Mermaid Diagram Rendering — COMPLETED

- **MermaidRenderer**: Styled code block with copy-to-clipboard for mermaid diagrams (fallback without WebView)
- **MarkdownPreview**: Intercepts ` ```mermaid ` blocks before standard rendering
- **Slash commands**: Mermaid diagram entry with template insertion
- 7 l10n keys added across EN/ZH/JA/KO

## Phase 107: Drag-and-Drop to Collections — COMPLETED

- **CollectionPickerSheet**: Bottom sheet with search, lists all collections, supports single and batch move
- **Batch action**: Folder icon in multi-select toolbar opens picker
- **Context menu**: "Add to Collection" in long-press context menu
- **Move method**: `_moveToCollection()` adds notes to selected collection with snackbar confirmation
- 7 l10n keys added across EN/ZH/JA/KO

## Phase 108: Table of Contents — COMPLETED

- **TocExtractor**: Parses ATX and Setext headings, skips code blocks, assigns sequential IDs
- **TocSheet**: DraggableScrollableSheet with hierarchical heading list, tap-to-scroll
- **Markdown preview**: TOC button in AppBar, scrolls to heading via character offset mapping
- 3 l10n keys added across EN/ZH/JA/KO

## Phase 109: Section Folding — COMPLETED

- **SectionFoldController**: ChangeNotifier tracking fold state as Set<int> of heading line indices
- **FoldedOutlineView**: Collapsible sections with content preview, animated expand/collapse
- **SectionFoldBar**: "Fold All" / "Unfold All" toolbar with count badge
- **Editor integration**: Fold view toggle in AppBar, switches between rich editor and outline
- 6 l10n keys added across EN/ZH/JA/KO

## Phase 110: Scroll-to-Top FAB + Print — COMPLETED

- **Scroll-to-top**: AnimatedOpacity/AnimatedSlide FAB in notes list, appears after 1000px scroll
- **PrintPreviewSheet**: Bottom sheet with metadata/image toggles, HTML export with print CSS
- **Editor/Detail/Preview**: Print button in AppBar across all note viewing screens
- **Share as HTML**: Generates styled HTML, shares via share_plus
- 7 l10n keys added across EN/ZH/JA/KO

## Phase 111: Text-to-Speech Read Aloud — COMPLETED

- **SpeechService**: Riverpod provider, paragraph-by-paragraph playback, state tracking
- **TtsPlayerBar**: Compact bottom bar with play/pause, stop, speed selector, progress indicator
- **Editor integration**: Volume icon in AppBar toggles TTS, player bar at bottom of editor
- 5 l10n keys added across EN/ZH/JA/KO

## Phase 112: Local Notifications for Reminders — COMPLETED

- **LocalNotificationService**: Wraps flutter_local_notifications for system tray notifications
- **ReminderService integration**: Schedules/cancels system notifications alongside polling
- **Startup init**: Notification permissions requested, channel configured
- **Recurring support**: Daily/weekly/monthly scheduled notifications
- **Platform guards**: kIsWeb + Platform checks for graceful no-op on unsupported platforms
- 4 l10n keys added across EN/ZH/JA/KO
- Dependencies: flutter_local_notifications ^18.0.0, timezone ^0.9.4

## Phase 113: Note List Reordering — COMPLETED

- **Database migration v13→v14**: Added `sort_order` INTEGER column to notes table
- **DAO methods**: `updateNoteSortOrder()`, `reorderNotes()`, `getNotesSortedByCustomOrder()`
- **Custom sort mode**: New "Custom Order" option in sort popup
- **ReorderableListView**: Drag handles visible when custom sort active
- **Info banner**: Shows reorder hint when in custom sort mode
- **DismissibleNoteCard**: Optional trailing widget for drag handle
- 2 l10n keys added across EN/ZH/JA/KO

## Phase 114: AI Chat Tests — COMPLETED

- **chat_message_test.dart**: 17 tests (construction, copyWith, toApiMap, equality)
- **chat_session_test.dart**: 23 tests (defaults, copyWith, immutability, const construction)
- **chat_session_notifier_test.dart**: 30 tests (send, stream, error, cancel, context, providers)
- **agent_notifier_test.dart**: 15 tests (states, execute, reset, provider)
- **ai_agent_screen_test.dart**: 19 widget tests (render, tap, loading, error, success)
- Total: 96 new tests, all passing

## Phase 115: Keyboard Shortcuts Enhancement — COMPLETED

- **New shortcuts**: Ctrl+P (print), Ctrl+H (heading cycle), Ctrl+` (inline code), Ctrl+Shift+K (link), Ctrl+Shift+S (strikethrough)
- **Rich editor**: Explicit undo/redo Shortcuts/Actions, strikethrough/inline code/heading/link toggles
- **Toolbar tooltips**: Shortcut hints shown in toolbar button tooltips
- **KeyboardShortcutsScreen**: Settings page listing all shortcuts by category
- **Route**: `/settings/shortcuts`
- **Settings**: Added "Keyboard Shortcuts" tile
- 18 l10n keys added across EN/ZH/JA/KO

## Phase 116: Code Snippet Management — COMPLETED

- **Snippets table**: DB v15, new table with id/title/code/language/description/category/tags/usageCount
- **SnippetsDao**: 11 methods (watch, search, CRUD, categories, languages, usage tracking)
- **SnippetsScreen**: Search bar, language/category filters, snippet cards, FAB, context menu
- **SnippetEditorSheet**: Create/edit with 17 language options, description, category, tags
- **SnippetDetailSheet**: Read-only view with copy, edit, delete actions
- **Slash command**: `/snippet` shows searchable picker, inserts code fence
- **Route**: `/snippets`
- 19 l10n keys added across EN/ZH/JA/KO

## Phase 117: PDF Export — COMPLETED

- **PdfExportService**: A4 layout, CJK font (Noto Sans SC), page numbers, markdown formatting
- **System print dialog**: Via `printing` package's `Printing.layoutPdf()`
- **PDF share**: Via `share_plus` platform sheet
- **ExportSheet update**: PDF format option alongside Markdown/HTML/Plain Text
- **PrintPreviewSheet update**: Generate PDF + Print buttons (non-web only)
- **Ctrl+P shortcut**: Wired to open print preview sheet
- **Bundled font**: `assets/fonts/NotoSansSC-Regular.ttf` (2MB, covers CJK)
- Dependencies: printing ^5.12.0, pdf ^3.10.0
- 5 l10n keys added across EN/ZH/JA/KO

## Phase 118: Mermaid Diagram Rendering — COMPLETED

- **WebView rendering**: Loads mermaid.js v11 via CDN, renders actual SVG diagrams
- **Theme-aware**: Matches app brightness (light/dark mermaid themes)
- **Auto-height**: JavaScript channel reports rendered height (100-800px range)
- **View Source toggle**: Switch between rendered diagram and raw code
- **Graceful fallback**: kIsWeb or WebView failure → source code display with copy
- **Loading state**: Spinner while mermaid.js loads from CDN
- Dependency: webview_flutter ^4.10.0
- 3 l10n keys added across EN/ZH/JA/KO

## Phase 119: Critical Widget Tests — COMPLETED

- **export_sheet_test.dart**: 11 tests (format options, scope, frontmatter toggle, organization)
- **print_preview_sheet_test.dart**: 12 tests (content rendering, toggles, clipboard, actions)
- **version_diff_screen_test.dart**: 17 tests (14 TextDiff LCS algorithm + 3 widget tests)
- **home_widget_service_test.dart**: 12 tests (NoteSummary, JSON serialization, no-op platform)
- **tts_player_bar_test.dart**: 13 tests (state icons, callbacks, speed selector, progress)
- Total: 65 new tests, all passing

## Phase 120: Tag Hierarchy — COMPLETED

- **DB migration v15→v16**: Added `parent_id` column to Tags table with index
- **TagsDao additions**: `watchAllTagsOrdered`, `getChildTags`, `getDescendantTagIds`, `reparentTag` (circular ref guard), `getTagPath`
- **TagTreeItem model**: `buildTagTree` and `flattenTagTree` utilities for client-side tree construction
- **TagsScreen tree view**: Hierarchical ListView replacing flat Wrap, expand/collapse state, indented levels
- **TagReparentSheet**: Searchable bottom sheet for selecting new parent with circular reference prevention
- **Long-press context menu**: Create sub-tag, reparent, color, delete options
- 8 l10n keys added across EN/ZH/JA/KO

## Phase 121: Collab Cursor Precision — COMPLETED

- **CursorPositionCalculator**: Static utility using TextPainter + RenderBox for accurate cursor positioning
- **CursorOverlay update**: Animated cursors (AnimatedPositioned, 150ms easeOutCubic), selection range highlights
- **CursorData extension**: `selectionEnd` for range selections, equality/hashCode overrides
- **CollabCursorsWidget update**: GlobalKey captures editor RenderBox each frame for precise positioning
- **User labels**: Colored username badges with theme-adaptive text, tooltips on hover
- 2 l10n keys added across EN/ZH/JA/KO

## Phase 122: Quick Actions + Image Drag-and-Drop — COMPLETED

- **QuickActionsManager rewrite**: Actual `QuickActions().initialize()` + `.setShortcutItems()` calls
- **Main.dart integration**: Register on startup, unregister on dispose, navigator key binding
- **EditorDropTarget**: `desktop_drop` DropTarget wrapping editor, image validation, visual drag feedback
- **Image drop handling**: Validates jpg/png/gif/webp, saves via ImageStorage, inserts markdown reference
- **Platform guards**: kIsWeb checks, desktop-only drop, mobile-only quick actions
- Dependencies: quick_actions ^1.1.0, desktop_drop ^0.5.0
- 6 l10n keys added across EN/ZH/JA/KO

## Phase 123: Widget Tests Batch 2 — COMPLETED

- **command_palette_test.dart**: 13 tests (search, filter, keyboard, empty state, recent notes, provider)
- **properties_sheet_test.dart**: 15 tests (CRUD, property types, built-in properties, dialog, empty state)
- **slash_command_menu_test.dart**: 10 tests (16 enum types, buildSlashCommands, filter, data class)
- **note_graph_screen_test.dart**: 10 tests (AppBar, empty state, loading, error, GraphData model, provider)
- **translation_sheet_test.dart**: 14 tests (language selector, translate, loading, error, callbacks)
- Total: 62 new tests, all passing

## v1.4.0 — Security, UX, Performance, Architecture (Completed 2026-04-27)

### Phase 128: Backend Security Hardening ✅
- Redis rate limiter, transaction sync, JWT validation, pool config, SSE escaping, worker validation, log retention

### Phase 129: Frontend Security Hardening ✅
- SQLCipher activation, database key derivation, web platform docs

### Phase 130: UI/UX Toolbar Redesign ✅
- Editor toolbar redesign, notes list AppBar overflow, save status indicator, context menu fix, responsive grid, theme tokens, localization

### Phase 131: Frontend Performance & Architecture ✅
- NotesListScreen decomposition, N+1 batch queries, background sync, typed API models, sync dedup, FTS5 helper

### Phase 132: Backend Architecture Improvements ✅
- ResponseWriter consolidation, LLM config resolver, sqlc removal, presence TTL, cleanup resilience, BIP-39 consolidation

### Phase 133: Polish & Testing ✅
- Tooltip shortcuts, FAB scroll, dark mode fixes, haptics, SnackBar helper, behavior tests, migration naming

### Stats (v1.4.0)
- 38 tasks completed across 6 phases
- ~84 estimated hours of work
- 2939 tests passing

### Phase 134: E2E Integration Tests — COMPLETED

**Backend (Go)** — 4 files, 13 tests with `//go:build integration`:
- `e2e_full_server_test.go` — Full production stack test server (13 repos, 15 services, httptest.Server)
- `e2e_auth_integration_test.go` — Register/login/me/refresh/rotation lifecycle (4 tests)
- `e2e_share_integration_test.go` — Create/retrieve/react/toggle lifecycle (5 tests)
- `e2e_note_links_integration_test.go` — Create/backlinks/graph/delete lifecycle (4 tests)

**Frontend (Dart)** — 3 files, 28 tests with real libsodium crypto:
- `pipeline_helper.dart` — Sodium init, in-memory DB, MockSyncApiClient, crypto helpers
- `encryption_sync_pipeline_test.dart` — Push/pull/round-trip/multi-type pipelines (19 tests)
- `conflict_pipeline_test.dart` — LWW conflict resolution, edge cases (9 tests)

**Test counts**: 2967 frontend (was 2957) + 700+ backend, all passing, 0 regressions.

### Phase 135: UX Polish — Error Handling & Offline Indicators — COMPLETED
- Global ErrorBoundary widget, ConflictResolutionScreen, OfflineBanner in editors
- Unified SnackBar: 37 files converted to AppSnackBar.info()/error()
- NotificationPreferences screen (4 toggles with SharedPreferences)
- What's New dialog (changelog constants, version-gated)
- Onboarding permission requests, accessibility tooltip audit
- Tests: 32 new

### Phase 136: UX Polish — Editor Experience — COMPLETED
- Autosave debounce via AppDurations.autoSaveDelay, _AppBarSaveStatus widget
- Extended formatting toolbar (code block, checklist, indent/outdent, undo/redo)
- Find & Replace bar (Ctrl+F): search, match count, replace/replace all
- Tests: 110 new

### Phase 137: Cross-Platform Consistency — COMPLETED
- PlatformUtils utility, Breakpoints constants, Adaptive widgets (AdaptiveBuilder, AdaptiveVisibility, AdaptivePadding)
- Focus management (FocusRing), Desktop context menu widget
- Replaced all raw Platform.isX checks (12 files) with PlatformUtils getters
- Keyboard shortcut consistency (platform-aware modifiers)
- Tests: 112 new

### Phase 138: Multi-Device Sync — Backend Device Identity — COMPLETED
- Migration 020: devices table, Migration 021: sync_blobs.device_id
- DeviceRepository, DeviceHandler (register, list, delete, update last seen)
- Account recovery endpoint, stale device cleanup job
- Frontend: stable device ID (UUID in SharedPreferences), device management API methods
- Tests: backend + 7 frontend (device_id_test)

### Phase 139: CRDT Persistence & Collab Backend — COMPLETED
- Persistent CRDT siteIds (UUID v4 in SharedPreferences), CRDT state persistence
- Migration 022: collab_rooms + collab_room_members tables
- CollabRepository (9 methods), CollabService (8 sentinel errors, 8-char invite codes), CollabHandler (5 endpoints)
- Tests: 87 new (21 frontend + 66 backend)

### Phase 140: Image Sync & Web Images — COMPLETED
- Image compression (JPEG 1920px/85%, auto-compress > 100KB), NoteImages Drift table + images_dao
- Image push/pull in sync_engine.dart (encrypted blobs with item_type='image')
- WebImageStorage (SharedPreferences-based, 5MB budget, base64) with kIsWeb delegation
- Tests: 89 new

### Phase 141: Collab Backend Hardening — COMPLETED
- Migration 023: collab_operations table (room_id, site_id, clock, operation_type, payload)
- WS room access control (403 if not member), CRDT operation persistence
- Reconnect catch-up: ?since_clock=N, server sends missed ops
- Tests: 72 new backend

### Phase 142: Web Platform — COMPLETED
- CryptoFactory — unified crypto across all platforms (sodium_libs-based XChaCha20-Poly1305 everywhere)
- DatabaseFactory — web executor documentation (OPFS/IndexedDB via drift_flutter)
- UnsupportedError audit — only stubs remain (io_stub, web_download_stub, markdown_export_service)
- Cross-platform crypto contract tests (key derivation hierarchy, encrypt/decrypt)
- Tests: 64 new

### Phase 143: Payment & Notification Infrastructure — COMPLETED
- Migration 024: payments table (user_id, stripe_session_id, amount, status, plan)
- Migration 025: notifications table (user_id, type enum, title, body, data JSONB, is_read)
- PaymentRepository + PaymentService: checkout creation, webhook handling, HMAC-SHA256 signature verification
- NotificationRepository + NotificationService: CRUD, pagination, unread count
- PaymentHandler: POST /payments/checkout, GET /payments, POST /payments/webhook (public)
- NotificationHandler: GET /notifications, GET /notifications/unread-count, POST /notifications/{id}/read, POST /notifications/read-all
- Stripe integration with test mode fallback (graceful degradation without STRIPE_SECRET_KEY)
- Tests: 96 new backend

### v2.0.0 Final Verification
- Frontend: 3395 tests pass (0 failures, 15 skipped) — +428 new from v1.4.0
- Backend: 14 packages, ~934 tests pass — +234 new from v1.4.0
- flutter analyze: 0 errors (144 info-level only)
- go build/vet: clean
- Database schema: v25 (payments, notifications)
- All 9 phases (135-143) COMPLETE

## Future Considerations (Post-v2.0.0)

| Area | Description | Priority |
|------|-------------|----------|
| Stripe Production Integration | Switch from test mode to live Stripe keys, subscription tiers | P1 |
| Push Notification Delivery | FCM/APNs integration with notification infrastructure | P1 |
| Web App Deployment | Build and deploy Flutter web app, CORS configuration | P2 |
| Performance Profiling | Memory profiling, startup time optimization | P3 |
| Internationalization | RTL language support, plural rules, date formatting | P3 |
| Analytics (Privacy-Preserving) | Opt-in, anonymized usage telemetry | P3 |
