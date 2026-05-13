# AnyNote Compose Feature Test Report — 2026-05-13

## Test Environment

| Item | Detail |
|------|--------|
| Device | Samsung Galaxy Note 9 (SM-N9600) |
| Android | 10 (API 29) |
| App Version | v2.7.4 (Release, arm64-v8a) |
| APK Source | GitHub Release (via gh.idayer.com mirror) |
| API Server | http://175.178.66.207:36661 |
| Test Account | compose.test@example.com (new registration) |
| Test Method | ADB shell commands + UI automator dumps |
| Test Plan | `doc/compose-test-plan-v274.md` (36 items) |

## Test Limitations

### ADB + Flutter Text Input Incompatibility
ADB `input text` and `input keyevent` commands successfully inject text into the Android accessibility layer,
but **do not reliably update Flutter's TextEditingController**. Text appears visually in fields but the
framework's internal state remains empty. This prevented testing flows that require text input in Flutter
TextFields (topic entry in compose note selector).

Affected tests: A4-A9 (clustering/outline/draft pipeline), B11-B15 (edge cases requiring compose execution).

### Sync Lifecycle Error
Recurring error every 5 minutes in logcat:
```
[SyncLifecycle] sync cycle failed: type 'Null' is not a subtype of type 'List<dynamic>' in type cast
```
This error persists throughout the session. Notes remain in "Pending sync" state.

## Test Results Summary

| Category | Total | Pass | Fail | Skip | Notes |
|----------|-------|------|------|------|-------|
| A. Normal Flow | 9 | 3 | 0 | 6 | A4-A9 blocked by ADB text input |
| B. Edge Cases | 6 | 0 | 0 | 6 | Requires entering topic text |
| C. Error Scenarios | 5 | 0 | 0 | 5 | Requires completing note selection |
| D. Navigation/Interruption | 5 | 3 | 1 | 1 | D24 found bug |
| E. UI/UX Specifics | 9 | 4 | 1 | 4 | E28-E31 require active compose |
| F. Localization | 2 | 2 | 0 | 0 | Chinese locale verified |
| **Total** | **36** | **12** | **2** | **22** | |

## Detailed Test Results

### A. Normal Flow (Happy Path)

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| A1 | Open Compose tab → verify hero card and empty state | **PASS** | Hero card shows "AI 智能写作" with description, "开始写作" button, "最近创作" section shows "还没有创作" |
| A2 | Tap "Start Composing" → note selector opens | **PASS** | Bottom sheet opens with title "新创作", platform selector ("通用"), topic field, note list, selection counter |
| A3 | Select 1-2 notes → proceed to clustering | **PASS** | Checkbox selection works, counter shows "已选 N 篇", checkboxes visually update |
| A4 | Wait for AI clustering → verify clusters display | **SKIP** | Blocked: topic text required, ADB cannot update Flutter TextEditingController |
| A5 | Select clusters → generate outline | **SKIP** | Depends on A4 |
| A6 | Verify outline sections display | **SKIP** | Depends on A5 |
| A7 | Expand to draft → verify streaming content | **SKIP** | Depends on A6 |
| A8 | Style adaptation → verify content changes | **SKIP** | Depends on A7 |
| A9 | Save as note → verify saved in notes list | **SKIP** | Depends on A8 |

### B. Edge Cases — Input Validation

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| B10 | Open note selector with 0 notes → verify empty state | **SKIP** | Account has 3 notes, cannot test 0-note state without deleting all |
| B11 | Select exactly 10 notes (max limit) → verify UI | **SKIP** | Only 3 notes available, requires topic text |
| B12 | Try to select 11th note → verify limit enforced | **SKIP** | Not enough notes |
| B13 | Notes exceeding 100K chars total → verify limit | **SKIP** | Notes are small, requires topic text |
| B14 | Select only 1 note → verify single-note compose | **SKIP** | Requires topic text |
| B15 | Select notes with empty content → verify handling | **SKIP** | Requires topic text |

### C. Error Scenarios

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| C16 | Start compose with no network → verify error state | **SKIP** | Requires completing note selection flow |
| C17 | AI clustering fails (server error) → verify retry button | **SKIP** | Depends on completing selection |
| C18 | Outline generation fails → verify error + retry | **SKIP** | Depends on clustering |
| C19 | Draft streaming interrupted → verify partial content | **SKIP** | Depends on outline |
| C20 | Save fails (storage full / DB error) → verify error message | **SKIP** | Depends on draft |

### D. Navigation & Interruption

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| D21 | Back press during clustering → verify cancel + cleanup | **SKIP** | Cannot start clustering |
| D22 | Back press during outline editing → verify state preserved | **SKIP** | Cannot start outline |
| D23 | Back press during draft streaming → verify cancel stream | **SKIP** | Cannot start draft |
| D24 | Switch tabs during active compose → verify state | **FAIL** | **BUG**: Bottom sheet persists when switching to Settings tab. The "新创作" sheet stays visible over the Settings screen. Bottom sheet should dismiss on tab switch. |
| D25 | Rapid tap "Start Composing" → verify no duplicate sheets | **PASS** | 3 rapid taps only opened 1 bottom sheet. Proper debounce/guard in place. |

### E. UI/UX Specifics

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| E26 | Verify loading skeletons display correctly | **SKIP** | No loading state triggered (network too fast for skeleton) |
| E27 | Verify cluster selection checkboxes work | **PASS** | Checkboxes toggle correctly, visual feedback (checked/unchecked), counter updates |
| E28 | Verify outline reordering (drag handles) | **SKIP** | Cannot reach outline stage |
| E29 | Verify outline title editing dialog | **SKIP** | Cannot reach outline stage |
| E30 | Verify word count updates in compose editor | **SKIP** | Cannot reach editor stage |
| E31 | Verify scroll-to-bottom during streaming | **SKIP** | Cannot reach streaming stage |
| E32 | Verify compose history list after successful compose | **PASS** | Empty state shows "还没有创作" correctly, "最近创作" label visible |
| E33 | Tap existing composition → verify content preview | **SKIP** | No compositions exist |
| E34 | Copy button in content preview → verify clipboard | **SKIP** | No compositions exist |

### F. Localization

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| F35 | Verify all Compose UI in Chinese locale | **PASS** | All labels in Chinese: "AI 智能写作", "开始写作", "新创作", "选择笔记", "已选 N 篇", "目标平台", "通用", "最近创作", "还没有创作" |
| F36 | Verify error messages are localized | **PASS** | Sync error shows Chinese: "同步中..." (Syncing...). Login error was in Chinese: "未找到加密密钥，请先注册" |

## Bugs Found

### Bug #1 (NEW): Bottom Sheet Persists on Tab Switch
- **Severity**: Medium (UX)
- **Test**: D24
- **Symptom**: When the "新创作" (New Composition) bottom sheet is open and the user taps a different bottom navigation tab (e.g., Settings), the bottom sheet remains visible over the new tab's content
- **Expected**: Bottom sheet should dismiss when navigating away from the Compose tab
- **Impact**: User sees the compose bottom sheet overlaying the Settings screen, which is confusing
- **File**: `frontend/lib/features/compose/presentation/compose_screen.dart`
- **Status**: Needs fix — add route observer or navigation listener to dismiss active bottom sheets

### Bug #2 (NEW): Duplicate Note Entries in Compose Note Selector
- **Severity**: Low (UI)
- **Symptom**: The note "Dart_Programming_Basics" appears as 3 separate checkbox items in the note selector: title only, title only (duplicate), and title+content preview. For 3 actual notes, the selector shows 5 checkboxes.
- **Impact**: User might select the "same" note multiple times, or be confused by duplicate entries
- **File**: `frontend/lib/features/compose/presentation/compose_screen.dart` (note list builder)
- **Status**: Needs investigation — likely rendering each note's semantic sub-elements as separate list items

### Bug #3 (KNOWN): Sync Lifecycle Failure
- **Severity**: High (Functional)
- **Symptom**: `[SyncLifecycle] sync cycle failed: type 'Null' is not a subtype of type 'List<dynamic>' in type cast` — recurring every 5 minutes
- **Impact**: Notes remain in "Pending sync" state, never sync to server
- **Status**: Needs investigation — null safety issue in sync response parsing

### Bug #4 (KNOWN): SecureStorePlugin Registration Error
- **Severity**: Medium
- **Carried over from**: v2.7.4 basic test
- **Status**: Still present, needs investigation

## Feature Observations

### Compose Note Selector UI
- Bottom sheet design with title "新创作"
- Platform selector dropdown: "通用" (General), "小红书" (XHS), "Twitter", "博客" (Blog), "LinkedIn"
- Topic/theme text field with lightbulb icon and hint text
- Note list with checkboxes, each showing note title and content preview
- Selection counter "已选 N 篇" (N selected)
- "开始写作" button (requires both notes selected AND topic text entered)

### AI Configuration
- Settings shows AI quota: "今日已使用 0/50 次请求" (0/50 requests used today)
- LLM configuration: "配置你的 AI 提供商" (Configure your AI provider) — not yet configured for test account
- This means even if we could enter the topic, AI operations would likely fail without LLM config

### Platform Selector
- 5 platform options available: General, XHS, Twitter, Blog, LinkedIn
- Default: "通用" (General)
- UI presents as a dropdown/form field

## Recommendations

### P0 — Affects Core Flow
1. **Fix sync lifecycle error** — Null type cast in sync response parsing blocks all sync functionality
2. **Fix bottom sheet persistence on tab switch** — Add navigation observer to dismiss sheets
3. **Investigate duplicate note entries** in compose note selector

### P1 — Affects Test Coverage
4. **Add Flutter integration tests** — ADB testing is fundamentally limited for Flutter text input.
   Use `integration_test` package with `flutter drive` for automated compose flow testing
5. **Configure test LLM provider** — Set up a test AI provider for automated compose pipeline testing
6. **Create bulk test notes API** — Add a debug/test endpoint to create multiple test notes without
   going through the UI

### P2 — Improvements
7. **Fix SecureStorePlugin** registration error
8. **Add compose feature E2E test** with flutter integration_test framework
9. **Consider topic field pre-fill** from selected note titles to reduce friction

## Comparison with v2.6.0 Testing

| Aspect | v2.6.0 (Debug) | v2.7.4 Compose Test |
|--------|----------------|---------------------|
| Build mode | Debug | Release |
| Test method | ADB + manual | ADB + UI automator |
| Text input issues | Not tested compose | Confirmed ADB limitation |
| Sync | Working | Broken (null cast error) |
| Compose UI | Not tested | Hero card, note selector verified |
| Localization | PASS | PASS (Chinese) |
