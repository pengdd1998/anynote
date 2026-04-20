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

### Current State Summary (Updated 2026-04-21)

**All features through Phase 31 are complete.** The app is production-ready with 1276+ tests passing (668 Go + 608 Flutter).

| Module | Completeness | Notes |
|---|---|---|
| Backend Auth | 100% | Register, login, refresh, me — JWT + bcrypt, 33 tests |
| Backend Sync | 100% | Pull/push with LWW conflict resolution, 30 tests |
| Backend LLM Gateway | 100% | 5 OpenAI-compatible providers, retry with backoff, AES-256-GCM key encryption, 80 tests |
| Backend AI Proxy | 100% | Dual-mode (user LLM / shared server LLM), SSE streaming, quota, 19 tests |
| Backend Platform Adapters | 100% | 6 adapters (XHS, WeChat, Zhihu, Medium, WordPress, Webhook), 80 tests |
| Backend Worker/Queue | 100% | asynq Redis queue, AI + publish job handlers, 40 tests |
| Backend Publish | 100% | Async publish with platform adapters, history, 25 tests |
| Backend WebSocket/Presence | 100% | Room-based collab, CRDT relay, rate limiting, Redis pub/sub, 65 tests |
| Backend Security | 100% | Security headers, JWT auth, per-IP/user rate limiting, 19 tests |
| Backend Tests | 100% | 668 test functions across 56+ test files, 18 packages |
| Frontend Crypto | 100% | Native: XChaCha20-Poly1305 + Argon2id; Web: AES-256-GCM + PBKDF2, 100+ tests |
| Frontend Database | 100% | Drift schema v8, 11 tables, FTS5 with CJK tokenizer, all DAOs tested |
| Frontend Sync Engine | 100% | Pull/push, LWW, version vectors, periodic sync, connectivity-aware |
| Frontend Auth | 100% | Full crypto key derivation flow, BIP-39 recovery, token refresh |
| Frontend Notes CRUD | 100% | Rich editor, auto-save, encryption, version history, zen mode, templates |
| Frontend AI Compose | 100% | 4-stage pipeline (cluster, outline, expand, style-adapt) |
| Frontend Publish | 100% | Platform connection, publish form, history, 6 platform adapters |
| Frontend Settings | 100% | Account, AI, LLM config, platforms, encryption, sync, import/export, language |
| Frontend CRDT Collab | 100% | RGA CRDT, editor controller, WebSocket relay, presence indicators |
| Frontend Share Extension | 100% | Android/iOS platform channels, deep link routing |
| Frontend Desktop | 100% | Menu bar, window state persistence, keyboard shortcuts, adaptive layout |
| Frontend Search | 100% | FTS5 with BM25 ranking, CJK tokenizer, advanced search screen |
| Frontend Localization | 100% | EN + ZH + JA + KO |
| Frontend Tests | 100% | 608 tests (14 skipped, 0 failures) across 55+ test files |

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

## Future Considerations (Post-Phase 31)

These are optional improvements for after initial release:

| Area | Description | Priority |
|------|-------------|----------|
| Performance Profiling | Memory profiling, startup time optimization | P3 |
| Offline-First Enhancement | Queue operations offline, sync on reconnect | P3 |
| Multi-Device Sync | Cross-device session management, conflict UI | P3 |
| Internationalization | RTL language support, plural rules, date formatting | P3 |
| Analytics (Privacy-Preserving) | Opt-in, anonymized usage telemetry | P3 |
