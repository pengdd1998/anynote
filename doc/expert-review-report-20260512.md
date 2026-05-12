# AnyNote Expert Review Report — 2026-05-12

## Review Context

- **Subject**: Real device test results of AnyNote v2.6.0 on Samsung SM-N9600
- **Date**: 2026-05-12
- **Panel**: 5 domain experts (Security, Mobile QA, Backend, Product, DevOps)
- **Reference**: `doc/device-test-report-20260512.md`

## Overall Score: 7.8/10

| Dimension | Score | Verdict |
|-----------|-------|---------|
| Security | 8.5 | Architecture correct, penetration testing needed |
| Mobile Quality | 8.0 | Core flows pass, automated tests missing |
| Backend Integration | 7.5 | API port config inconsistency |
| Product Experience | 8.0 | Flow complete, overflow menu UX concern |
| Release Readiness | 7.0 | No release signing, no CI test gates |

## Expert Opinions

### 1. Security Auditor — 8.5/10

**Strengths**:
- E2E encryption architecture is sound (XChaCha20-Poly1305 + Argon2id)
- Server zero-knowledge design verified — server only stores encrypted blobs
- Argon2id KDF now runs in background isolate (no UI blocking)
- `flutter_secure_storage` with `FlutterFragmentActivity` for hardware-backed key storage

**Risks**:
- No penetration testing performed (OWASP Top 10 not verified)
- Key storage security untested on rooted devices
- AI proxy logging safeguards need code-level audit to confirm no data leakage

**Recommendations**:
- Conduct security penetration test (OWASP Mobile Top 10)
- Test on rooted device for key extraction attempts
- Add automated security scanning to CI pipeline

### 2. Mobile QA Engineer — 8.0/10

**Strengths**:
- Memory usage 116MB (39% of 300MB target) — excellent
- CPU idle 0.8%, cold start 2-3s — excellent
- 4-language localization (EN/ZH/JA/KO) code-verified
- No crashes observed during testing

**Risks**:
- All testing manual via ADB — no automated regression suite
- PopupMenuButton overflow menu has 20+ items, scrolling is unintuitive on device
- Device auto-lock disrupted testing multiple times
- Only tested on Android 10 (API 29), no iOS coverage

**Recommendations**:
- Add `integration_test` suite for core user flows
- Restructure overflow menu (grouped sections, collapsible, or BottomSheet)
- Test on iOS physical device
- Add `adb shell svc power stayon true` to test scripts

### 3. Backend Architect — 7.5/10

**Strengths**:
- Thin server architecture correct (Go + chi + PostgreSQL)
- Sync protocol design sound (version vectors + LWW)
- AI proxy dual-mode flexible (user LLM direct / shared server LLM)

**Risks**:
- Port configuration confusion: user stated 8080, actual API on 36661, nginx returns 404 on 8080
- Sync conflict resolution not tested on real devices
- Platform publishing adapter (chromedp XHS) not end-to-end tested
- AI SSE streaming reconnection untested

**Recommendations**:
- Document and unify API endpoint (nginx reverse proxy or direct)
- Set up dual-device sync test environment
- Verify SSE endpoint with `curl` for streaming format
- Test XHS publishing flow end-to-end

### 4. Product Manager — 8.0/10

**Strengths**:
- Note → AI Polish → Publish flow complete and functional
- Pre-filled title/content/tags reduce user effort
- "Connect a Platform" CTA when no platforms configured
- 4-language support for international users

**Risks**:
- UX break when no platform connected (must leave editor → settings → return)
- Overflow menu cognitive overload (20+ options)
- AI polish quality not verified (sheet opens, but LLM output untested)

**Recommendations**:
- Add inline platform connection flow in publish sheet
- Reorganize overflow menu into logical groups
- Collect AI output quality metrics from users

### 5. Release/DevOps Engineer — 7.0/10

**Strengths**:
- Docker Compose infrastructure complete
- CD pipeline configured (GitHub Actions)
- Debug APK builds successfully (~38s)

**Risks**:
- No release keystore/signing configuration
- No automated test gates in CI
- All testing in Debug mode — Release performance unknown
- R8/ProGuard obfuscation compatibility with FFI libraries (sodium_libs) unverified

**Recommendations**:
- Configure release keystore and signing
- Add `flutter test` and `flutter build apk --release` to CI
- Test Release APK on device
- Verify R8 compatibility with sodium_libs FFI

## Consensus Action Items

### P0 — Blocks Release

1. Configure Release APK signing (keystore, passwords, build type)
2. Unify API port configuration and document endpoint mapping
3. Test Release APK on device (verify R8 + sodium_libs compatibility)

### P1 — Before Release

4. Add `integration_test` suite for core flows (login, note CRUD, publish)
5. Conduct security penetration test (OWASP Mobile Top 10)
6. Verify AI SSE streaming on real device with actual LLM

### P2 — Post-Release Iteration

7. Restructure overflow menu (grouped/collapsible)
8. Add inline platform connection in publish sheet
9. Dual-device sync conflict real-scenario testing

### P3 — Ongoing

10. iOS physical device testing
11. Performance regression benchmarks (encryption timing, FTS5 query latency)
12. Accessibility compliance (WCAG contrast ratio measurement)
