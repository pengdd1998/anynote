# AnyNote v2.7.4 Real Device Test Report — 2026-05-13

## Test Environment

| Item | Detail |
|------|--------|
| Device | Samsung Galaxy Note 9 (SM-N9600) |
| Android | 10 (API 29) |
| App Version | v2.7.4 (Release, arm64-v8a) |
| APK Source | GitHub Release (via gh.idayer.com mirror) |
| API Server | http://175.178.66.207:36661 |
| Build Type | Release (signed with debug key fallback) |

## Test Results

### Authentication
| Test | Result |
|------|--------|
| Login with email/password | PASS |
| KDF migration dialog displays | PASS |
| Navigate to notes list after login | PASS |

### Note CRUD
| Test | Result |
|------|--------|
| Open existing note in editor | PASS |
| Create new note via FAB | PASS |
| Type content in note editor | PASS |
| Save note on back navigation | PASS |
| New note appears in list | PASS |

### Navigation
| Test | Result |
|------|--------|
| Notes tab (bottom nav) | PASS |
| Compose tab (bottom nav) | PASS |
| Publish tab (bottom nav) | PASS |
| Settings tab (bottom nav) | PASS |
| Note editor → back to list | PASS |

### Publish Feature
| Test | Result |
|------|--------|
| Publish tab opens with UI | PASS |
| Publish menu item in overflow menu | Code verified in v2.7.4 |
| PublishFromEditorSheet | Code verified in v2.7.4 |

> Note: Overflow menu scrolling via ADB is unreliable due to Flutter's popup
> dismiss-on-outside-touch behavior. Feature code is confirmed present in v2.7.4
> (verified via `git merge-base`). On-device manual testing required for the
> overflow menu publish flow.

### Stability
| Test | Result |
|------|--------|
| No crashes during session | PASS |
| No ANR (Application Not Responding) | PASS |
| No Flutter framework errors | PASS |

## Known Issues

### Issue #1: SecureStorePlugin Registration Error
- **Severity**: Medium
- **Logcat**: `GeneratedPluginRegistrant: Error registering plugin secure_store, com.example.secure_store.SecureStorePlugin — java.lang.StringIndexOutOfBoundsException: String index out of range: -4`
- **Impact**: Plugin fails to register, but app continues to function. Login succeeds, notes save correctly. Likely falls back to alternate storage.
- **Status**: Needs investigation — may affect secure storage reliability

### Issue #2: Skipped Frames During Login (59-60 frames)
- **Severity**: Medium
- **Logcat**: `Skipped 59 frames!` and `Skipped 60 frames!` during app startup
- **Impact**: ~1 second of UI jank during initial load (down from 94-98 in v2.6.0 debug)
- **Analysis**: The Argon2id Isolate.run() fix reduced jank, but release mode still shows
  ~1s delay. This may be from database initialization + KDF combined.
- **Status**: Acceptable for release, but should monitor

### Issue #3: Signature Mismatch on Update
- **Severity**: Low (install-time only)
- **Impact**: Cannot update from debug-signed to release-signed APK without uninstall
- **Workaround**: Uninstall old version first
- **Status**: Expected behavior — production releases will use consistent signing

### Issue #4: Sync Lifecycle Null Cast Error (NEW)
- **Severity**: High
- **Logcat**: `[SyncLifecycle] sync cycle failed: type 'Null' is not a subtype of type 'List<dynamic>' in type cast`
- **Frequency**: Recurring every 5 minutes
- **Impact**: Notes remain in "Pending sync" state indefinitely. Sync never completes successfully.
- **Status**: Needs investigation — null safety issue in sync response parsing

## Performance Metrics (Release Build)

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| APK Size (arm64) | 45.4 MB | < 50 MB | PASS |
| Cold Start | ~3-4s | < 3s | ACCEPTABLE |
| Login KDF | ~1s jank | 0 jank | NEEDS WORK |
| Memory | TBD | < 300 MB | — |
| Crashes | 0 | 0 | PASS |

## Comparison with v2.6.0 (Debug Build)

| Metric | v2.6.0 Debug | v2.7.4 Release |
|--------|-------------|----------------|
| Skipped frames (login) | 94-98 | 59-60 |
| APK install method | `flutter run --debug` | GitHub release APK |
| SecureStorePlugin error | Not observed | Present |
| Note CRUD | PASS | PASS |
| Publish feature | PASS | Code verified |

## Recommendations

1. **Investigate SecureStorePlugin** — `StringIndexOutOfBoundsException` on plugin registration
   could indicate a version mismatch or initialization ordering issue
2. **Profile release startup** — Use `flutter build apk --profile` with DevTools to identify
   remaining startup bottlenecks
3. **Configure release signing** — Set up proper keystore for consistent OTA updates
4. **Test overflow menu publish** — Manual on-device verification of the publish-from-editor
   overflow menu flow (could not be automated via ADB)
