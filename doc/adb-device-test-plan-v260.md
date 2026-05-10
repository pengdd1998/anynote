# AnyNote v2.6.0 - Real Device ADB Test Plan

**Test Date:** 2026-05-09  
**Device:** Samsung Galaxy Note 9 (Android 10, 1440x2960, 560dpi)  
**Test Method:** ADB + Manual Testing + Automated Screenshots  
**Version:** v2.6.0 (Latest from GitHub)

---

## Executive Summary

Comprehensive real-device testing plan that combines:
1. **Automated ADB commands** for system-level testing
2. **Manual interaction testing** for UX validation
3. **Screenshot capture** for UI/UX review
4. **Performance monitoring** via ADB logs
5. **Multiple expert agents** for parallel testing execution

---

## Part 1: Device Setup & Preparation

### 1.1 Device Authorization
```bash
# User must authorize on phone when prompted
adb devices

# Expected output:
# List of devices attached
# 26f01ec875217ece    device
```

### 1.2 Device Information Collection
```bash
# Get device model
adb shell getprop ro.product.model

# Get Android version
adb shell getprop ro.build.version.release

# Get screen density
adb shell wm density

# Get screen resolution
adb shell wm size

# Get available memory
adb shell cat /proc/meminfo | grep MemTotal

# Get storage info
adb shell df -h
```

### 1.3 Enable Verbose Logging
```bash
# Enable detailed logging
adb shell setprop log.tag.AnyNote VERBOSE
adb shell setprop log.tag.flutter VERBOSE

# Clear logcat before testing
adb logcat -c
```

---

## Part 2: APK Download & Installation

### 2.1 Download Latest Release from GitHub
```bash
# Get latest release info
curl -s https://api.github.com/repos/anynote/anynote/releases/latest

# Download APK (adjust URL based on actual release)
# Option A: From GitHub Releases
wget https://github.com/anynote/anynote/releases/latest/download/app-release.apk -O anynote-v260.apk

# Option B: Build from source
cd frontend
flutter build apk --release --target-platform android-arm64
```

### 2.2 Install APK on Device
```bash
# Install fresh (remove old version first)
adb uninstall com.anynote.app 2>/dev/null || true
adb install anynote-v260.apk

# Or upgrade existing installation
adb install -r anynote-v260.apk

# Verify installation
adb shell pm list packages | grep anynote
adb shell dumpsys package com.anynote.app | grep versionName
```

### 2.3 Grant Required Permissions
```bash
# Grant storage permission
adb shell pm grant com.anynote.app android.permission.WRITE_EXTERNAL_STORAGE
adb shell pm grant com.anynote.app android.permission.READ_EXTERNAL_STORAGE

# Grant camera permission (for image capture)
adb shell pm grant com.anynote.app android.permission.CAMERA

# Grant internet permission (already in manifest)
# adb shell pm grant com.anynote.app android.permission.INTERNET

# Grant notification permission
adb shell pm grant com.anynote.app android.permission.POST_NOTIFICATIONS

# Grant fingerprint/biometric permission (if used)
adb shell pm grant com.anynote.app android.permission.USE_BIOMETRIC
```

---

## Part 3: Functional Verification Tests

### 3.1 App Launch & Startup Performance (P0)
```bash
# Measure cold start time
adb shell am force-stop com.anynote.app
adb logcat -c
adb shell am start -W -n com.anynote.app/.MainActivity | grep TotalTime

# Target: < 3000ms
# Capture screenshot after launch
adb shell screencap -p /sdcard/01_launch.png
adb pull /sdcard/01_launch.png ./test-screenshots/
```

**Manual Verification:**
- [ ] App launches successfully
- [ ] Splash screen displays correctly
- [ ] No ANR (Application Not Responding)
- [ ] No crash on startup
- [ ] Transition to home/main screen is smooth

### 3.2 Authentication Flow (P0)
```bash
# Navigate to registration/login
# Take screenshots at each step
adb shell screencap -p /sdcard/02_welcome.png
adb pull /sdcard/02_welcome.png ./test-screenshots/
```

**Test Cases:**
| Step | Action | Expected Result | Screenshot |
|------|--------|----------------|------------|
| 1 | Open app | Welcome/onboarding screen | `02_welcome.png` |
| 2 | Tap "Sign Up" | Registration form displays | `03_register.png` |
| 3 | Enter email/password | Form accepts input | `04_register_filled.png` |
| 4 | Tap "Create Account" | Account created, logged in | `05_registered.png` |
| 5 | Logout & Login | Login screen displays | `06_login.png` |
| 6 | Enter credentials | Successful login | `07_logged_in.png` |

**ADB Commands for Each Step:**
```bash
# Wait between interactions for screenshots
sleep 2
adb shell screencap -p /sdcard/step_name.png
adb pull /sdcard/step_name.png ./test-screenshots/
```

### 3.3 Note Creation & Editing (P0)
```bash
# Test creating a new note
adb shell input tap 500 1000  # Tap FAB button (adjust coordinates)
sleep 1
adb shell screencap -p /sdcard/08_editor_empty.png
adb pull /sdcard/08_editor_empty.png ./test-screenshots/

# Type test content
adb shell input text "Test note content for verification"
sleep 1
adb shell screencap -p /sdcard/09_editor_with_text.png
adb pull /sdcard/09_editor_with_text.png ./test-screenshots/

# Press back to save
adb shell input keyevent 4
sleep 1
adb shell screencap -p /sdcard/10_notes_list.png
adb pull /sdcard/10_notes_list.png ./test-screenshots/
```

**Manual Test Checklist:**
- [ ] FAB creates note directly (1 tap)
- [ ] Haptic feedback on FAB press
- [ ] Editor opens smoothly
- [ ] Keyboard doesn't hide content
- [ ] Auto-save indicator appears
- [ ] Note appears in list after save
- [ ] Note title/preview displays correctly

### 3.4 AI Composition Feature (P1)
**Navigation Path:** Notes List → Compose → Select Notes → AI Generate

```bash
# Navigate to compose
# Screenshots at each stage
# 11_compose_home.png
# 12_note_selector.png
# 13_cluster_screen.png
# 14_outline_screen.png
# 15_compose_editor.png
# 16_publish_preview.png
```

**Test Cases:**
- [ ] Can select multiple notes
- [ ] AI clustering produces sensible groups
- [ ] Outline generation works
- [ ] Streaming response displays correctly
- [ ] Can edit AI-generated content
- [ ] Platform-specific formatting applied

### 3.5 Publish to Platforms (P1)
**Test Platforms:** Xiaohongshu, WordPress, Webhook

```bash
# Navigate to publish
# Screenshots:
# 17_platform_select.png
# 18_platform_connect.png (XHS QR code)
# 19_publish_form.png
# 20_publish_history.png
```

**Test Cases:**
- [ ] Platform connection flow works
- [ ] XHS QR code displays
- [ ] Platform-specific formatting applied
- [ ] Publish history shows previous attempts

### 3.6 Settings & Configuration (P1)
```bash
# Navigate through all settings screens
# Screenshots:
# 21_settings_home.png
# 22_settings_account.png
# 23_settings_ai.png
# 24_settings_llm_config.png
# 25_settings_platforms.png
# 26_settings_encryption.png
# 27_settings_sync.png
# 28_settings_theme.png
```

### 3.7 Dark Mode Theme (P0)
```bash
# Toggle dark mode
# Take screenshots of all major screens in dark mode
# Compare with .impeccable.md requirements
```

**Dark Mode Checklist:**
- [ ] Background uses warm hue (~30°, not 250° cool)
- [ ] Text contrast meets WCAG AA (4.5:1)
- [ ] All themed elements update correctly
- [ ] No visual glitches or artifacts

---

## Part 4: Performance Analysis

### 4.1 Startup Performance (P0)
```bash
# Measure cold start time (3 runs, take average)
for i in {1..3}; do
  adb shell am force-stop com.anynote.app
  sleep 2
  adb shell am start -W -n com.anynote.app/.MainActivity | grep TotalTime
done

# Measure warm start time
adb shell am start -W -n com.anynote.app/.MainActivity | grep TotalTime

# Target:
# - Cold start: < 3000ms
# - Warm start: < 1000ms
```

### 4.2 Memory Usage (P1)
```bash
# Monitor memory during various operations
adb shell dumpsys meminfo com.anynote.app

# Key metrics:
# - TOTAL: Total memory used
# - Heap Size: Java heap allocation
# - Native Heap: Native memory allocation

# Target:
# - Steady state: < 300MB
# - Peak during AI: < 500MB
```

### 4.3 Frame Rate & Rendering (P0)
```bash
# Enable profile rendering
adb shell setprop debug.hwui.profile true

# Monitor frame drops during scrolling
adb shell dumpsys gfxinfo com.anynote.app reset
# [Perform scroll action]
adb shell dumpsys gfxinfo com.anynote.app | grep -A 5 "gfxinfo"

# Target:
# - Janky frames: < 5%
# - 90th percentile frame time: < 16ms (60fps)
```

### 4.4 Battery & CPU Usage (P2)
```bash
# Monitor CPU usage during operations
adb shell top -n 1 | grep anynote

# Check battery stats
adb shell dumpsys batterystats com.anynote.app
```

### 4.5 Network Performance (P1)
```bash
# Monitor API calls during sync
adb logcat | grep -E "AnyNote|API|Sync"

# Measure sync time
time_start=$(date +%s)
# [Trigger sync]
time_end=$(date +%s)
duration=$((time_end - time_start))
echo "Sync took: ${duration}s"

# Target: Sync 100 notes in < 5s
```

---

## Part 5: Security Assessment

### 5.1 Local Data Encryption (P0)
```bash
# Check if database is encrypted
adb shell run-as com.anynote.app ls -la /data/data/com.anynote.app/databases/

# Try to read database directly
adb shell run-as com.anynote.app cat /data/data/com.anynote.app/databases/anynote.db

# Expected: Data should be encrypted (unreadable)
```

### 5.2 Key Storage (P0)
```bash
# Verify keys are in secure storage
adb shell run-as com.anynote.app ls -la /data/data/com.anynote.app/shared_prefs/

# Keys should NOT be in plaintext in shared_prefs
```

### 5.3 Network Traffic (P0)
```bash
# Capture network traffic during login
# Requires root or mitmproxy setup
# Verify HTTPS only, no plaintext credentials
```

### 5.4 Screenshot Security (P1)
```bash
# Verify app prevents screenshots in sensitive areas
# (if implemented)
adb shell /system/bin/screencap -p /sdcard/test_secure.png
```

### 5.5 Log Sanitization (P0)
```bash
# Monitor logs for sensitive data leakage
adb logcat -c
# [Perform login, note creation with sensitive content]
adb logcat -d | grep -i -E "password|token|key|secret"

# Expected: No sensitive data in logs
```

---

## Part 6: UI/UX Design Verification

### 6.1 Design System Compliance (P0)
**Reference: `.impeccable.md`**

```bash
# Capture all major screens for design review
# Compare against design principles:
# - Warm privacy
# - Quiet confidence
# - Elegant restraint
# - Writing-first
# - Platform-native warmth
```

### 6.2 Typography Verification (P0)
```bash
# Screenshots for typography review:
# - Heading sizes (displayLarge, headlineLarge, titleLarge)
# - Body text hierarchy
# - Font consistency across screens
```

**Checklist:**
- [ ] displayLarge ≥ 36px (was 28px in v1.0)
- [ ] Font family correct (Inter for Android)
- [ ] Heading hierarchy clear
- [ ] Line height appropriate

### 6.3 Color & Contrast (P0)
```bash
# Use color picker on screenshots to verify:
# - Dark mode hue is warm (~30°, not 250° cool)
# - Light mode hue is warm (~35°)
# - WCAG contrast ratios met
```

**Checklist:**
- [ ] Dark background: #1E1A16 (warm brown)
- [ ] Light background: #FAF8F5 (warm white)
- [ ] Primary accent: #D9774A (coral-amber)
- [ ] Text contrast ≥ 4.5:1
- [ ] Input border contrast ≥ 3:1

### 6.4 Spacing & Layout (P1)
```bash
# Verify consistent spacing:
# - Corner radius: 8px, 12px, 16px
# - Padding/margin consistency
# - Card spacing in lists
```

### 6.5 Component Quality (P1)
**Key Components to Verify:**

**FAB (Floating Action Button):**
- [ ] Single tap creates note (not 2 taps)
- [ ] Haptic feedback on press
- [ ] Long-press shows template options
- [ ] Correct icon (Phosphor, not Material)

**Note Cards:**
- [ ] Proper elevation/shadow
- [ ] Tap and long-press both work
- [ ] Long-press shows context menu
- [ ] Visual hierarchy clear

**AppBars:**
- [ ] 3-4 icons visible, not 7-9
- [ ] Overflow menu works
- [ ] Sync status shown subtly
- [ ] Consistent across screens

**Buttons:**
- [ ] FilledButton corner radius = 12px
- [ ] All states defined (normal, hover, pressed, disabled)
- [ ] Proper contrast on button text

### 6.6 Accessibility (P0)
```bash
# Enable TalkBack
adb shell settings put secure enabled_accessibility_services com.google.android.marvin.talkback/com.android.talkback.TalkBackService

# Take screenshots with TalkBack enabled
# Verify semantic labels
```

**Checklist:**
- [ ] All interactive elements have semantic labels
- [ ] Touch targets ≥ 48x48dp
- [ ] Color-only information has alternatives
- [ ] Focus order logical

### 6.7 Dark Mode Completeness (P0)
**Compare all screens in light and dark mode:**

```bash
# Create side-by-side comparison for:
# - Welcome/Login screens
# - Notes list
# - Note editor
# - Settings screens
# - Compose screens
```

---

## Part 7: User Experience Testing

### 7.1 Critical User Journeys

**Journey 1: Lightning Capture (from PRODUCT-ANALYSIS.md)**
```
Scenario: User has a quick idea while commuting
Steps: Open app → Tap FAB → Type → Done
Target: < 3 seconds total
Screenshots: capture_journey_*.png
```

**Journey 2: AI-Powered Assembly**
```
Scenario: User wants to write an article from scattered notes
Steps: Open Compose → Select notes → AI cluster → Outline → Draft
Target: < 5 minutes to first draft
Screenshots: compose_journey_*.png
```

**Journey 3: Multi-Platform Publishing**
```
Scenario: User publishes finished article to multiple platforms
Steps: Open publish → Select platforms → Format → Publish
Target: < 2 minutes per platform
Screenshots: publish_journey_*.png
```

### 7.2 Interaction Quality Check

**Gesture Recognition:**
- [ ] Tap responsive
- [ ] Long-press works on note cards
- [ ] Swipe actions function correctly
- [ ] Pinch-to-zoom (if applicable)
- [ ] Scroll smooth

**Haptic Feedback:**
- [ ] FAB press
- [ ] Note selection
- [ ] Note deletion
- [ ] Sync completion
- [ ] Form validation errors

**Keyboard Handling:**
- [ ] Keyboard doesn't hide form fields
- [ ] Auto-focus on login email field
- [ ] Done button dismisses keyboard
- [ ] Emoji keyboard works in editor

### 7.3 Error Handling (P1)

**Test Scenarios:**
- [ ] No internet connection
- [ ] Server timeout
- [ ] Invalid credentials
- [ ] Sync conflict
- [ ] AI quota exceeded
- [ ] Publish failure

**For each:**
- Capture error screenshot
- Verify user-friendly message
- Check recovery path exists
- Confirm no crash/ANR

### 7.4 Loading States (P2)

**Verify loading indicators for:**
- [ ] App launch
- [ ] Sync in progress
- [ ] AI generation
- [ ] Platform connection
- [ ] Image upload

---

## Part 8: Regression Testing vs Previous Reports

### 8.1 v2.5.0 Issues Verification

**From `test-report-v260-2026-05-08.md`:**

| Issue | v2.5.0 Status | v2.6.0 Expected | Verification |
|-------|---------------|-----------------|--------------|
| Dark mode hue (250° cool) | BROKEN | Fixed to 30° warm | [ ] |
| FAB requires 2 taps | BROKEN | Fixed to 1 tap | [ ] |
| Long press broken | BROKEN | Still broken? | [ ] |
| Tag filter UI unclear | UNCLEAR | Implemented? | [ ] |
| Editor chrome consolidated | UNCLEAR | Consolidated? | [ ] |

### 8.2 v1.0.0 Expert Review Issues

**From `ui-ux-review-report.md`:**

**P0 Issues to Verify Fixed:**
- [ ] Font fallback (Inter for Android)
- [ ] Login keyboard avoidance fixed
- [ ] Long press gesture conflict resolved
- [ ] WCAG contrast fixed
- [ ] Auth back navigation fixed

**P1 Issues to Verify Fixed:**
- [ ] AppBar icon consolidation (7-9 → 3-4 icons)
- [ ] FAB direct creation
- [ ] Password visibility toggle
- [ ] Display typography scale (≥36px)
- [ ] Editor chrome consolidated
- [ ] Button corner radius (12px)
- [ ] Haptic feedback added
- [ ] System UI overlay theming

---

## Part 9: Expert Agent Testing Execution

### 9.1 Agent 1: Functional Verification Agent
**Scope:** All functional tests from Part 3
**Deliverables:** Functional test results, bug report

### 9.2 Agent 2: Performance Analysis Agent
**Scope:** All performance tests from Part 4
**Deliverables:** Performance metrics, bottleneck analysis

### 9.3 Agent 3: Security Assessment Agent
**Scope:** All security tests from Part 5
**Deliverables:** Security audit report, vulnerability findings

### 9.4 Agent 4: UI/UX Design Agent
**Scope:** All design tests from Part 6
**Deliverables:** Design compliance report, visual issues

### 9.5 Agent 5: User Experience Agent
**Scope:** All UX tests from Part 7
**Deliverables:** UX findings, usability issues

---

## Part 10: Test Report Generation

### 10.1 Report Structure

**File: `doc/device-test-report-v260-20260509.md`**

```markdown
# AnyNote v2.6.0 Real Device Test Report

## Executive Summary
- Overall score: X/10
- P0 issues: Y critical
- P1 issues: Z high priority
- Recommendation: [Ready for release | Needs fixes]

## Device & Environment
- Device: Samsung Galaxy Note 9
- Android: 10
- Resolution: 1440x2960 (560dpi)
- App Version: v2.6.0

## Test Results by Dimension

### 1. Functional Verification
| Test | Result | Notes |
|------|--------|-------|
| App Launch | ✅/❌ | ... |
| Auth Flow | ✅/❌ | ... |

### 2. Performance
| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Cold Start | <3000ms | Xms | ✅/❌ |
| Memory | <300MB | XMB | ✅/❌ |

### 3. Security
| Test | Result | Severity |
|------|--------|----------|
| Encryption | ✅/❌ | P0-P3 |
| Logs | ✅/❌ | P0-P3 |

### 4. UI/UX Design
| Principle | Score | Issues |
|-----------|-------|--------|
| Warm Privacy | X/10 | ... |
| Quiet Confidence | X/10 | ... |

### 5. User Experience
| Journey | Score | Issues |
|---------|-------|--------|
| Lightning Capture | X/10 | ... |

## Regression vs v2.5.0
| Issue | Fixed? | Evidence |
|-------|--------|----------|

## Critical Issues Found
List all P0 and P1 issues with:
- Description
- Screenshot reference
- File location (if known)
- Severity
- Fix recommendation

## Screenshots
Organized by screen/feature

## Recommendations
Prioritized fix list

## Conclusion
Overall assessment and release recommendation
```

---

## Part 11: Execution Timeline

### Phase 1: Setup (30 min)
- [ ] Authorize ADB
- [ ] Download APK
- [ ] Install app
- [ ] Grant permissions
- [ ] Enable logging

### Phase 2: Automated Testing (1 hour)
- [ ] Performance metrics collection
- [ ] Security verification
- [ ] Screenshot capture automation

### Phase 3: Manual Testing (2 hours)
- [ ] Functional test walkthrough
- [ ] UX journey testing
- [ ] Design compliance verification

### Phase 4: Analysis & Reporting (1 hour)
- [ ] Compile agent findings
- [ ] Generate screenshots
- [ ] Write final report

**Total Time: ~4.5 hours**

---

## Part 12: Success Criteria

### Must Have (P0) for Release
- All P0 functional tests pass
- No crashes or ANRs
- Performance within acceptable range
- All P0 security requirements met
- All P0 accessibility requirements met

### Should Have (P1) for Quality Release
- 90%+ P1 tests pass
- No major UX friction points
- Design system compliance ≥ 8/10
- All P1 v2.5.0 issues resolved

---

*Test Plan Version: 1.0*  
*Created: 2026-05-09*  
*Device: Samsung Galaxy Note 9 (26f01ec875217ece)*
