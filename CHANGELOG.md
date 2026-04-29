# Changelog

All notable changes to AnyNote will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] — 2026-04-29

### Added

- **Stripe Production Integration**: stripe-go v82.1.0, StripeAdapter implementing StripeClient, Pro=subscription / Lifetime=payment via Price IDs, webhook idempotency (stripe_webhook_events table), subscription lifecycle handlers, atomic CompletePaymentTx, webhook rate limiting (100/min)
- **Push Notification Delivery**: TaskTypePush in asynq queue with retry, push_job_handler.go, notification preference sync (GET/PUT /api/v1/notifications/preferences), expanded notification types (publish_started, publish_completed, collab_invite), APNs/APNSConfig with sound and ContentAvailable, iOS aps-environment entitlement + UIBackgroundModes
- **Notification Preferences**: Frontend syncs notification_preferences to backend, 4 toggle categories
- **Frontend UX**: L10n updates across all 4 locales, improved accessibility, widget refinements

### Changed

- Database schema upgraded to v29 (stripe_event_log, payment_status_expired, notification_preferences, notification_types_expand)
- Stripe test-mode fallback for local development
- Frontend pubspec dependency cleanup

### Fixed

- UUID type mismatch in collab migrations
- Non-tag refs in Android APK rename step
- compileSdk updated to 36, desugaring enabled, workmanager upgraded

## [2.0.0] — 2026-04-28

### Added

- **UX Polish**: Global error boundary widget with recovery UI, conflict resolution screen (Keep Local / Keep Server / Keep Both), offline indicator in editor, unified AppSnackBar helper replacing 100+ raw ScaffoldMessenger calls
- **Editor Experience**: Find & Replace bar (Ctrl+F) with match count and replace/replace-all, extended toolbar (code block, checklist, indent/outdent, undo/redo), enhanced save status indicator in AppBar
- **Cross-Platform**: PlatformUtils utility (isDesktop, isMobile, isWeb, isApple), Breakpoints constants, AdaptiveBuilder/AdaptiveVisibility/AdaptivePadding widgets, FocusRing for desktop forms, DesktopContextMenu widget, all raw Platform.isX checks replaced with PlatformUtils getters
- **Multi-Device**: Stable device identity via UUID persisted in SharedPreferences, device registration API (POST/GET/DELETE /device-identity), device_id on sync blobs
- **CRDT/Collab**: Persistent CRDT siteIds (UUID v4 in SharedPreferences), collab state persistence (load on join, periodic 5s save, save on leave), MergeEngine exportState/loadState for full document serialization
- **Collab Backend**: Invite codes with 8-char unambiguous generation, collab_rooms + collab_room_members tables, CollabRepository (9 methods), CollabService with 8 sentinel errors, CollabHandler (5 endpoints), WS room access control (403 for non-members), CRDT operation persistence (collab_operations table), reconnect catch-up via since_clock
- **Image Sync**: JPEG compression (1920px max, 85% quality) before save, NoteImages Drift table, images_dao with CRUD + getUnsyncedImages/markSynced, image push/pull in sync engine (encrypted blobs with item_type='image'), WebImageStorage for web platform (SharedPreferences-based, 5MB budget)
- **Web Platform**: CryptoFactory unifying crypto across all platforms (sodium_libs-based XChaCha20-Poly1305 everywhere), cross-platform crypto contract tests, database factory documentation for web (OPFS/IndexedDB)
- **Payment/Notification**: Stripe checkout integration (HMAC-SHA256 webhook verification), payments table, notifications table with type enum and JSONB data, PaymentHandler + NotificationHandler endpoints, graceful Stripe test-mode fallback
- **Notification Preferences**: Settings screen with 4 toggle switches (Reminders, Sync Conflicts, Sharing, Push), SharedPreferences persistence
- **What's New**: Changelog constants and dialog shown on version update
- **Onboarding**: Notification permission request on "Get Started"

### Changed

- Database schema upgraded to v25 (payments, notifications, collab_operations, devices tables)
- Toolbar redesign: primary AppBar (4 items) + formatting toolbar + overflow menu
- Notes list AppBar: 16 actions consolidated to 4 visible + overflow menu
- NotesListScreen decomposed: 2641 to 1923 lines (-27%), extracted 4 widget files
- NoteEditorScreen decomposed: 1748 to 1592 lines (-9%), extracted EditorAppBarActions
- 8 additional build method extractions across encryption_screen, share_dialog, snippet sheets, rich_note_editor, keyboard_shortcuts_screen, tag_reparent_sheet
- Replaced all hardcoded Colors.grey with theme tokens across 10+ files
- Responsive grid layout (SliverGridDelegateWithMaxCrossAxisExtent)
- Autosave debounce uses AppDurations.autoSaveDelay constant

### Fixed

- 27 Flutter test failures from Drift StreamQueryStore timer leaks (manual disposal pattern)
- 14 collab_provider_test failures from async joinRoom
- Dark mode handle bar visibility across 10+ files
- Context menu position (tap coordinates instead of RelativeRect.fill)
- Accessibility: tooltips on IconButtons, semantic labels on charts and tag items

### Testing

- 3395 frontend tests (+428 from v1.3.0-dev), ~934 backend tests (+234)
- 0 flutter analyze errors, 0 warnings

## [1.3.0-dev] — 2026-04-27

### Added

- **Backend Security Hardening**: Redis rate limiter (replaces in-memory, shares state across instances), transaction on Sync BatchUpsert, jwt.WithValidMethods on WS token validation, database pool configuration from config, worker config validation, sync operation log retention (30-day cleanup)
- **Frontend Security Hardening**: SQLCipher activated with derived key for local database encryption, deriveDatabaseKey() in CryptoService, web platform key storage documentation
- **Backend Domain Tests**: 64 new tests covering sentinel errors, plan constants/limits, JSON serialization, privacy-critical json:"-" tags, sync types, AI types, share/reaction/note link types
- **Backend Platform Adapter DRY**: shared helpers package (DecryptAuth, DecryptCookieJar), 5 adapters refactored to use them
- **Backend Service Tests**: 51 new tests across plan_service, ai_agent_service, note_link_service, profile_service
- **Backend N+1 Fix**: note_link_repository CreateLinks refactored from loop INSERT to pgx.Batch
- **Backend Architecture**: Consolidated ResponseWriter wrappers, consolidated LLM config resolver, removed dead sqlc config, presence service TTL with Redis expiry + stale sweep, shared-note cleanup goroutine with exponential backoff, consolidated BIP-39 wordlist
- **Backend Repository Tests**: 38 new tests (note_link_repository, plan_repository, profile_repository)
- **E2E Integration Tests**: 13 Go integration tests using testcontainers-go, 28 Dart pipeline tests (encryption/sync/conflict with real libsodium)
- **Widget Tests**: 111 new tests across 13 screens (trash, daily notes, quick capture, plan, AI chat, statistics, template management, keyboard shortcuts, snippets, image management, note compare, reminders, profile)
- **Domain Model Equality**: operator== and hashCode overrides on 26 value classes across 14 files
- **ErrorStateWidget**: Reusable error display with icon, message, and optional retry button; replaced 10 bare Text('Error:...') displays
- **AppDurations**: Named Duration constants (11 total), replacing ~45 hardcoded Duration values across 25+ files
- **Shared Utilities**: parseHexColor() extracted to color_utils.dart (was duplicated in 5 files), filenameToTitle() extracted to import_utils.dart (was duplicated in 2 files)
- **copyWith**: Added to 6 key state classes (DecryptedNote, PlanLimits, PlanInfo, AgentState, ShareResult, DecryptedSharedNote)
- **Web Build**: Conditional dart:io imports (9 files + 1 new io_stub.dart) for web compatibility
- **Accessibility**: Semantics wrappers on charts, semantic labels on tag items, ExcludeSemantics on decorative painters, 4 new l10n keys
- **l10n**: 59+ hardcoded strings replaced with l10n keys across 16+ source files, 7 new l10n keys added to all 4 locales

### Changed

- Toolbar redesign: editor toolbar (primary AppBar + formatting + overflow), notes list AppBar (16 to 4 visible + overflow)
- NotesListScreen decomposed (2641 to 1923 lines, -27%)
- NoteEditorScreen decomposed (1748 to 1592 lines, -9%)
- 8 additional build method extractions for readability
- Replaced hardcoded Colors.grey with theme tokens
- Replaced all raw Platform.isX checks (12 files) with PlatformUtils getters
- Renamed backend migration files to .up.sql/.down.sql convention
- Silent catch blocks: debugPrint logging added to 44 locations across 32 frontend files + 13 backend unbounded io.ReadAll wrapped with LimitReader
- panic() replaced with log.Fatal in 2 backend locations

### Fixed

- 29 Flutter test failures (FAB finders, tag tree view, Material ancestor, AI tag, seed templates, DismissibleNoteCard timer leak)
- 14 flutter analyze warnings (use_build_context_synchronously, require_trailing_commas)
- Table embed cell edit persistence (edits silently lost on reload)
- Dead "Custom property" button in properties_sheet
- Silent error handling in 4 screens (discover, collections, trash, deep link routing)
- 38 flutter analyze warnings fixed (use_build_context_synchronously, require_trailing_commas, unused imports)

### Security

- SQLCipher for local database encryption
- Backend SQL injection protection
- CORS and CSP hardening

### Testing

- 263 new frontend tests, 115 new backend tests
- flutter analyze: 0 errors, 0 warnings
- go build/vet: clean

## [1.2.0] — 2026-04-24

### Added

- **Trash Screen**: Restore and permanent delete for soft-deleted notes, empty trash action
- **Batch Operations**: Multi-select on notes list with batch tag, delete, and archive actions, tag picker dialog
- **Data Tables View**: Notes displayed in tabular layout with sortable columns
- **Collaboration Share UI**: Share dialog with drag handle, presence row, invite code section, join code section, security notice
- **Wiki Links**: Bidirectional [[note links]] with searchable note picker triggered by typing `[[`, local-only storage via NoteLinksDao, NoteLinks table (schema v9)
- **Graph View**: Force-directed layout algorithm with interactive pan/zoom (0.5x-3x), hover effects, local data integration via NoteLinksDao, empty state and error handling
- **Advanced Link Features**: Content-based link suggestions (Jaccard similarity), orphaned notes detection, unified link management with delete capability
- **Transclusion**: Obsidian-style `![[note]]` embedding with live sync via Drift watch streams, expand/collapse toggle, max depth limit (5), broken transclusion handling
- **NotesFilterSheet**: Extracted filter sheet widget from notes list screen
- **InlineNoteDetail**: Extracted inline note detail widget for master-detail layout
- **StaggeredCardEntrance**: Extracted staggered entrance animation widget

### Changed

- NotesListScreen decomposed: extracted 4 widget files (filter sheet, batch actions, inline detail, staggered animation)
- EditorAppBarActions extracted from note editor screen

### Testing

- 2073 frontend tests pass, 0 failures

## [1.1.0] — 2026-04-24

### Added

- **Rich Widgets**: Custom Quill embed builders for embedded content (tables, code blocks, wiki links, transclusions)
- **Sync Progress Indicator**: Visual indicator showing sync status in app bar
- **Background Sync**: Working background sync replacing previous stub implementation
- **CI/CD Pipeline**: GitHub Actions workflows for automated testing, building, and release
- **Platform Polish**: Page transition durations standardized (300ms forward, 250ms reverse)

### Fixed

- Page transitions: explicit transition durations on CustomTransitionPage for test reliability
- Backend SSE JSON escaping in platform adapters (json.Marshal replacing raw fmt.Fprintf)

### Testing

- Backend integration test suite using testcontainers-go (13 tests covering PostgreSQL, Redis, concurrent operations)
- Performance documentation with benchmarks and production pool settings

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
