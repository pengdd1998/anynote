# AnyNote Real Device Test Report — 2026-05-12

## Test Environment

| Item | Detail |
|------|--------|
| Device | Samsung Galaxy Note 9 (SM-N9600) |
| Android | 10 (API 29) |
| Resolution | 1440x2960 |
| Flutter | 3.41.9 / Dart 3.11.5 |
| AGP | 8.11.1 / NDK 28.2.13676358 |
| Build Mode | Debug |
| API Server | http://175.178.66.207:36661 |
| App Version | v2.6.0 (dev) |

## Bugs Found & Fixed

### Bug #5: NDK Version Mismatch Warning

- **Severity**: Low (build warning)
- **Symptom**: Plugins require NDK 28.2.13676358 but project had 27.0.12077973
- **File**: `frontend/android/app/build.gradle`
- **Fix**: Added `ndkVersion "28.2.13676358"` to android block
- **Status**: Fixed, verified in subsequent builds

### Bug #6: Argon2id KDF Blocks Main Thread (Critical)

- **Severity**: Critical
- **Symptom**: 94-98 skipped frames during login, UI frozen for ~1.5s
- **Root Cause**: `sodium.crypto.pwhash.call()` is synchronous FFI that runs Argon2id
  memory-hard KDF on the main isolate
- **File**: `frontend/lib/core/crypto/master_key_native_compat.dart`
- **Fix**: Wrapped pwhash call in `Isolate.run()` — spawns background isolate for
  memory-intensive KDF, returns result without blocking UI
- **Verification**: 0 skipped frames during subsequent logins
- **Status**: Fixed

### Bug #7: API Port Mismatch (8080 vs 36661)

- **Severity**: High
- **Symptom**: Login silently fails, no error shown
- **Root Cause**: App built with `--dart-define=API_BASE_URL=http://175.178.66.207:8080`
  but port 8080 serves nginx (404 on /api/v1/). Actual API on port 36661.
- **Fix**: Rebuilt with `--dart-define=API_BASE_URL=http://175.178.66.207:36661`
- **Status**: Fixed, login succeeds with correct port

### Bug #8: Import Path Error in Note Editor

- **Severity**: High (build error)
- **Symptom**: `uri_does_not_exist` — import `'../../../publish/...'` resolves to
  `lib/publish/...` instead of `lib/features/publish/...`
- **File**: `frontend/lib/features/notes/presentation/note_editor_screen.dart:45`
- **Fix**: Changed to `'../../../features/publish/...'` matching cross-feature import pattern
- **Status**: Fixed

## Feature Verification: Publish from Editor

### Flow Tested

1. Login with email/password → PASS
2. Navigate to notes list → PASS
3. Open note in editor → PASS
4. Open overflow menu → PASS
5. Select "Publish to Platform" → PASS
6. Verify `PublishFromEditorSheet` opens with:
   - Pre-filled title from note → PASS
   - Pre-filled content from note → PASS
   - Pre-filled tags from note → PASS
7. Tap AI Polish button → WritingAssistSheet opens → PASS
8. Platform selection displays connected platforms → PASS (shows "Connect a Platform" when none configured)
9. Publish button visible → PASS

### Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `lib/features/publish/presentation/widgets/publish_from_editor_sheet.dart` | Created | Bridge widget for note→publish |
| `lib/features/notes/presentation/widgets/editor_app_bar_actions.dart` | Modified | Added `onPublishToPlatform` callback + menu item |
| `lib/features/notes/presentation/note_editor_screen.dart` | Modified | Added `_showPublishSheet` method |
| `lib/l10n/app_{en,zh,ja,ko}.arb` | Modified | Added 4 localization keys |

## Test Coverage Summary

| Area | Tested | Result |
|------|--------|--------|
| Authentication (login) | Yes | PASS |
| Note editor (open, content) | Yes | PASS |
| Publish from editor (full flow) | Yes | PASS |
| AI Polish (nested sheet) | Yes | PASS |
| Localization (zh on device) | Yes | PASS |
| Crypto (Argon2id KDF) | Yes | PASS (after Isolate fix) |
| Sync | No | — |
| AI Chat (SSE streaming) | No | — |
| Platform publish (actual POST) | No | — |
| iOS | No | — |

## Remaining Risks

1. All testing performed in **Debug mode** — Release mode performance may differ
2. **No automated integration tests** — all testing was manual via ADB
3. Device auto-lock interfered with testing — screen timeout mitigation needed
4. PopupMenuButton with 20+ items requires scrolling — UX concern for production
