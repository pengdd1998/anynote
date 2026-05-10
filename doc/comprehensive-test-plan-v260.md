# AnyNote v2.6.0 Comprehensive Test Plan

**Test Plan Date:** 2026-05-09  
**Target Version:** v2.6.0 (commit b90e634)  
**Test Lead:** AI Test Engineering Team  
**Duration:** 3 days (parallel execution with multiple expert agents)

---

## Executive Summary

This comprehensive test plan addresses 5 critical dimensions:
1. **Functional Verification** - End-to-end feature validation
2. **Performance Analysis** - Load testing, memory profiling, bottlenecks
3. **Security Assessment** - Encryption, authentication, input validation
4. **User Experience** - Interaction flows, accessibility, usability
5. **UI/UX Design** - Visual consistency, design system compliance

**Execution Strategy:** Deploy 6 expert agents in parallel for maximum coverage and efficiency.

---

## Test Environment

### Infrastructure
- **Backend:** Go 1.22+, PostgreSQL 16, Redis 7.2, Chrome headless
- **Frontend:** Flutter 3.3.19, Dart 3.3.0
- **Test Devices:**
  - Samsung Galaxy Note 9 (Android 10, 1440x2960, 560dpi)
  - iPhone 14 Pro (iOS 17.5, 393x852, 3x)
  - Desktop: Windows 10, macOS 14
  - Web: Chrome 125, Firefox 126, Safari 17.5

### Test Data
- 1,000 encrypted notes (various sizes)
- 50 tags with hierarchy
- 10 collections
- 5 platform connections (XHS, WordPress, etc.)
- Multiple users for collaboration testing

---

## Dimension 1: Functional Verification

### 1.1 Authentication & Authorization
**Priority:** P0  
**Test Owner:** Backend Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| AUTH-001 | User registration flow | 1. Generate salt<br>2. Derive master key via Argon2id<br>3. Send auth key hash to server<br>4. Store master key in secure storage | Registration succeeds, keys stored securely | P0 |
| AUTH-002 | Login with correct credentials | 1. Enter email/password<br>2. Derive auth key hash<br>3. Send to server<br>4. Receive JWT tokens | Login succeeds, tokens stored | P0 |
| AUTH-003 | Login with wrong password | 1. Enter wrong password<br>2. Attempt login | Login fails with appropriate error | P0 |
| AUTH-004 | Token refresh on 401 | 1. Wait for access token expiry<br>2. Make API call<br>3. Observe token refresh | Access token refreshed automatically | P0 |
| AUTH-005 | Refresh token rotation | 1. Use refresh token<br>2. Verify new refresh token issued<br>3. Old token invalidated | Token rotation works correctly | P1 |
| AUTH-006 | Logout clears tokens | 1. Login<br>2. Logout<br>3. Attempt API call | API calls fail after logout | P0 |
| AUTH-007 | BIP-39 recovery key | 1. Generate recovery key during registration<br>2. Logout<br>3. Recover with recovery key | Account recovered successfully | P0 |
| AUTH-008 | Account deletion | 1. Request account deletion<br>2. Verify data removed | All data deleted within 30 days | P1 |

#### Test Files
- `backend/internal/handler/e2e_auth_flow_test.go`
- `backend/internal/handler/e2e_auth_integration_test.go`
- `frontend/integration_test/auth_test.dart`

---

### 1.2 Encryption & Key Management
**Priority:** P0  
**Test Owner:** Crypto Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| CRYPTO-001 | XChaCha20-Poly1305 round-trip | 1. Encrypt plaintext<br>2. Decrypt ciphertext<br>3. Verify integrity | Plaintext matches original | P0 |
| CRYPTO-002 | Per-item key derivation | 1. Derive key from note_id<br>2. Verify determinism | Same note_id produces same key | P0 |
| CRYPTO-003 | Tampered ciphertext detection | 1. Encrypt data<br>2. Modify ciphertext<br>3. Attempt decryption | Decryption fails with auth error | P0 |
| CRYPTO-004 | Argon2id key derivation | 1. Derive master key<br>2. Measure time<br>3. Verify output | Takes 1-3s, deterministic | P0 |
| CRYPTO-005 | HKDF-SHA256 key expansion | 1. Expand master key<br>2. Verify subkey independence | Subkeys cryptographically independent | P0 |
| CRYPTO-006 | Master key storage | 1. Store master key<br>2. Restart app<br>3. Retrieve key | Key persists securely | P0 |
| CRYPTO-007 | Web crypto compatibility | 1. Test AES-256-GCM on web<br>2. Verify round-trip | Web encryption works | P1 |
| CRYPTO-008 | Random nonce generation | 1. Generate 1000 nonces<br>2. Verify uniqueness | All nonces unique | P0 |

#### Test Files
- `frontend/test/core/crypto/e2e_encryption_roundtrip_test.dart`
- `frontend/test/core/crypto/crypto_service_test.dart`
- `backend/internal/llm/crypto_test.go`

---

### 1.3 Synchronization
**Priority:** P0  
**Test Owner:** Sync Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| SYNC-001 | Pull new notes from server | 1. Create note on device A<br>2. Sync device B | Note appears on device B | P0 |
| SYNC-002 | Push local changes | 1. Create note offline<br>2. Connect<br>3. Sync | Note uploaded to server | P0 |
| SYNC-003 | LWW conflict resolution | 1. Edit same note on both devices<br>2. Sync both | Last write wins | P0 |
| SYNC-004 | Version vector tracking | 1. Check version vector<br>2. Modify note<br>3. Verify version increment | Version incremented correctly | P0 |
| SYNC-005 | Image sync | 1. Create note with image<br>2. Sync to server<br>3. Download on device B | Image encrypted and synced | P0 |
| SYNC-006 | Partial sync (pagination) | 1. Create 1000 notes<br>2. Sync with limit | Sync completes in batches | P1 |
| SYNC-007 | Background sync | 1. Enable background sync<br>2. Trigger sync condition | Sync runs in background | P1 |
| SYNC-008 | Sync status indicators | 1. Start sync<br>2. Observe UI | Status shows correctly | P2 |

#### Test Files
- `backend/internal/handler/e2e_sync_flow_test.go`
- `frontend/test/e2e/sync_e2e_test.dart`
- `frontend/test/core/sync/sync_queue_manager_test.dart`

---

### 1.4 AI Composition & Proxy
**Priority:** P1  
**Test Owner:** AI Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| AI-001 | 4-stage composition pipeline | 1. Select notes<br>2. Cluster<br>3. Outline<br>4. Draft<br>5. Style adapt | All stages complete | P0 |
| AI-002 | SSE streaming | 1. Start AI request<br>2. Observe streaming | Response streams token-by-token | P0 |
| AI-003 | Quota enforcement | 1. Use up quota<br>2. Make AI request | Request denied with quota error | P0 |
| AI-004 | User LLM config | 1. Configure custom LLM<br>2. Test connection | Custom LLM used | P1 |
| AI-005 | Fallback to shared LLM | 1. No user config<br>2. Make AI request | Shared LLM used with rate limiting | P1 |
| AI-006 | Content limits | 1. Send oversized content | Content truncated with error | P1 |
| AI-007 | Concurrency guard | 1. Start multiple AI requests | Only one runs at a time | P1 |
| AI-008 | Error mapping | 1. Trigger various errors | User-friendly error messages | P2 |

#### Test Files
- `backend/internal/handler/e2e_ai_proxy_flow_test.go`
- `backend/internal/llm/gateway_test.go`
- `frontend/test/features/compose/compose_service_test.dart`

---

### 1.5 Platform Publishing
**Priority:** P1  
**Test Owner:** Platform Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| PUB-001 | XHS QR code auth | 1. Initiate auth<br>2. Display QR<br>3. Scan<br>4. Verify completion | Auth completes successfully | P0 |
| PUB-002 | XHS publish with images | 1. Create note with images<br>2. Publish to XHS | Post published with images | P0 |
| PUB-003 | WordPress publish | 1. Configure WordPress<br>2. Publish article | Article published correctly | P1 |
| PUB-004 | Webhook publish | 1. Configure webhook<br>2. Publish | Webhook called with data | P1 |
| PUB-005 | Publish history | 1. Publish note<br>2. Check history | History shows entry | P2 |
| PUB-006 | Async publish queue | 1. Queue multiple publishes | All processed correctly | P1 |
| PUB-007 | Publish failure handling | 1. Simulate failure<br>2. Check retry | Retry scheduled | P1 |

#### Test Files
- `backend/internal/handler/e2e_publish_flow_test.go`
- `backend/internal/platform/xiaohongshu/adapter_test.go`
- `frontend/test/features/publish/publish_service_test.dart`

---

### 1.6 Real-time Collaboration
**Priority:** P1  
**Test Owner:** Collab Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| COLLAB-001 | CRDT merge | 1. Two users edit<br>2. Observe merge | Edits merge correctly | P0 |
| COLLAB-002 | Cursor presence | 1. Two users in same note<br>2. Observe cursors | Both cursors visible | P1 |
| COLLAB-003 | WebSocket reconnection | 1. Disconnect network<br>2. Reconnect | Connection resumes | P1 |
| COLLAB-004 | Room-based access | 1. User A creates note<br>2. User B tries to edit | Access control enforced | P0 |
| COLLAB-005 | Operation persistence | 1. Edit note<br>2. Close/reopen<br>3. Verify CRDT state | CRDT state persists | P1 |

#### Test Files
- `backend/internal/handler/e2e_collab_integration_test.go`
- `frontend/test/core/collab/crdt_editor_controller_test.dart`
- `frontend/test/core/collab/merge_engine_test.dart`

---

## Dimension 2: Performance Analysis

### 2.1 Backend Performance
**Priority:** P1  
**Test Owner:** Performance Test Agent

#### Test Cases
| ID | Test Case | Metric | Target | Priority |
|----|-----------|--------|--------|----------|
| PERF-001 | API response time | p50 latency | <100ms | P0 |
| PERF-002 | API response time | p99 latency | <500ms | P0 |
| PERF-003 | Concurrent connections | 1000 simultaneous | No failures | P1 |
| PERF-004 | Database query time | FTS5 search (10K notes) | <200ms | P1 |
| PERF-005 | Sync throughput | 100 notes batch | <5s | P1 |
| PERF-006 | Memory usage | Steady state | <512MB | P2 |
| PERF-007 | Goroutine leakage | 1 hour load | No leaks | P1 |
| PERF-008 | Connection pool | Max connections | Properly bounded | P1 |

#### Test Files
- `backend/internal/handler/middleware_bench_test.go`
- `backend/internal/service/benchmark_test.go`
- `backend/cmd/load_test/` (create if needed)

---

### 2.2 Frontend Performance
**Priority:** P1  
**Test Owner:** Flutter Test Agent

#### Test Cases
| ID | Test Case | Metric | Target | Priority |
|----|-----------|--------|--------|----------|
| PERF-101 | App startup time | Cold start | <3s | P0 |
| PERF-102 | Frame rendering | Janky frames | <5% | P0 |
| PERF-103 | List scrolling | 1000 notes | 60fps | P1 |
| PERF-104 | Encryption/decryption | 100KB note | <100ms | P1 |
| PERF-105 | Key derivation | Argon2id | 1-3s | P0 |
| PERF-106 | Database query | FTS5 search | <100ms | P1 |
| PERF-107 | Memory usage | Steady state | <300MB | P2 |
| PERF-108 | APK size | Release build | <50MB | P2 |

#### Test Files
- `frontend/test/performance/frame_timing_test.dart`
- `frontend/test/core/crypto/crypto_performance_test.dart`
- `frontend/test/core/database/fts5_test.dart`

---

## Dimension 3: Security Assessment

### 3.1 Input Validation
**Priority:** P0  
**Test Owner:** Security Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| SEC-001 | SQL injection | 1. Submit malicious input | Input sanitized/rejected | P0 |
| SEC-002 | XSS prevention | 1. Submit script tags | Escaped safely | P0 |
| SEC-003 | Path traversal | 1. Submit "../../etc/passwd" | Blocked | P0 |
| SEC-004 | Command injection | 1. Submit shell commands | Blocked | P0 |
| SEC-005 | JWT tampering | 1. Modify token | Token rejected | P0 |
| SEC-006 | Overflow attacks | 1. Send oversized payload | Size limit enforced | P1 |
| SEC-007 | Type confusion | 1. Send wrong types | Validation error | P1 |

#### Test Files
- `backend/internal/handler/security_test.go`
- `backend/internal/handler/validation_test.go`
- `backend/internal/handler/e2e_full_server_test.go`

---

### 3.2 Authentication Security
**Priority:** P0  
**Test Owner:** Security Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| SEC-101 | Password strength | 1. Test weak passwords | Rejected or warned | P1 |
| SEC-102 | Rate limiting login | 1. Attempt 10 failed logins | Account locked | P0 |
| SEC-103 | Session hijacking | 1. Steal session token | Invalidated by refresh | P0 |
| SEC-104 | CSRF protection | 1. Submit cross-origin request | Blocked | P0 |
| SEC-105 | Secure headers | 1. Check response headers | All security headers present | P0 |

#### Test Files
- `backend/internal/handler/security_middleware_test.go`
- `backend/internal/handler/rate_limit_middleware_test.go`
- `backend/internal/repository/refresh_token_integration_test.go`

---

### 3.3 Data Privacy
**Priority:** P0  
**Test Owner:** Crypto Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| SEC-201 | Server zero-knowledge | 1. Check server DB | Only encrypted data | P0 |
| SEC-202 | No plaintext logging | 1. Scan all logs | No plaintext content | P0 |
| SEC-203 | API key encryption | 1. Check LLM config storage | Keys encrypted at rest | P0 |
| SEC-204 | Key storage security | 1. Verify platform storage | Uses Keychain/Keystore | P0 |
| SEC-205 | Memory cleanup | 1. Check memory after use | Sensitive data zeroed | P1 |

#### Test Files
- `backend/internal/llm/crypto_test.go`
- `frontend/test/core/crypto/key_storage_test.dart`
- Custom audit scripts

---

## Dimension 4: User Experience

### 4.1 Accessibility
**Priority:** P0  
**Test Owner:** UX Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| UX-001 | Screen reader navigation | 1. Enable TalkBack/VoiceOver | All elements announced | P0 |
| UX-002 | Semantic labels | 1. Inspect widget tree | Semantic labels present | P0 |
| UX-003 | Touch target size | 1. Measure interactive elements | Min 48x48dp | P0 |
| UX-004 | Keyboard navigation | 1. Tab through UI | Logical order | P1 |
| UX-005 | Color blindness | 1. Simulate color blindness | Information still accessible | P1 |

#### Test Files
- `frontend/test/core/accessibility/a11y_test.dart`
- `frontend/integration_test/accessibility_test.dart`
- `frontend/lib/core/accessibility/a11y_utils.dart`

---

### 4.2 Interaction Design
**Priority:** P1  
**Test Owner:** UX Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| UX-101 | Long press context menu | 1. Long press note card | Context menu appears | P0 |
| UX-102 | FAB direct creation | 1. Tap FAB | Opens editor directly | P0 |
| UX-103 | Swipe actions | 1. Swipe note card | Quick actions appear | P1 |
| UX-104 | Keyboard shortcuts | 1. Press Cmd/Ctrl+N | New note created | P1 |
| UX-105 | Haptic feedback | 1. Tap buttons | Appropriate haptic | P1 |
| UX-106 | Loading states | 1. Trigger slow operation | Loading indicator shows | P2 |

#### Test Files
- `frontend/test/widgets/note_card_test.dart`
- `frontend/test/core/widgets/keyboard_shortcuts_test.dart`
- `frontend/integration_test/compose_test.dart`

---

### 4.3 Error Handling
**Priority:** P1  
**Test Owner:** UX Test Agent

#### Test Cases
| ID | Test Case | Steps | Expected | Priority |
|----|-----------|-------|----------|----------|
| UX-201 | Network error | 1. Disconnect network<br>2. Make API call | User-friendly error shown | P0 |
| UX-202 | Sync conflict | 1. Create conflict | Resolution UI appears | P1 |
| UX-203 | Validation error | 1. Submit invalid form | Inline errors show | P1 |
| UX-204 | Error recovery | 1. Trigger error<br>2. Attempt recovery | Recovery works smoothly | P1 |
| UX-205 | Error boundary | 1. Crash app | Error boundary catches | P0 |

#### Test Files
- `frontend/test/core/error/error_display_test.dart`
- `frontend/test/core/error/error_mapper_test.dart`
- `frontend/test/core/widgets/error_boundary_test.dart`

---

## Dimension 5: UI/UX Design

### 5.1 Visual Consistency
**Priority:** P1  
**Test Owner:** Design Test Agent

#### Test Cases
| ID | Test Case | Checks | Expected | Priority |
|----|-----------|--------|----------|----------|
| UI-001 | Dark mode warmth | Check color temperature | Warm hue (~30°) | P0 |
| UI-002 | WCAG contrast | Measure all text | Min 4.5:1 ratio | P0 |
| UI-003 | Typography scale | Check font sizes | Consistent scale | P1 |
| UI-004 | Spacing system | Check margins/padding | Consistent units | P1 |
| UI-005 | Icon consistency | Check all icons | All Phosphor (or consistent) | P2 |
| UI-006 | Color usage | Check semantic colors | Used consistently | P1 |

#### Test Files
- `frontend/test/core/theme/app_theme_test.dart`
- `frontend/test/core/theme/app_colors_test.dart`
- Design verification scripts

---

### 5.2 Component Quality
**Priority:** P1  
**Test Owner:** Design Test Agent

#### Test Cases
| ID | Test Case | Checks | Expected | Priority |
|----|-----------|--------|----------|----------|
| UI-101 | Button states | Check all button variants | All states defined | P1 |
| UI-102 | Form fields | Check text fields | Consistent styling | P1 |
| UI-103 | Card design | Check note cards | Proper elevation | P1 |
| UI-104 | AppBar consistency | Check all screens | Consistent AppBar | P2 |
| UI-105 | FAB placement | Check all lists | Consistent position | P1 |

#### Test Files
- `frontend/test/widgets/app_components_test.dart`
- `frontend/test/core/widgets/empty_state_test.dart`
- `frontend/test/core/widgets/master_detail_layout_test.dart`

---

### 5.3 Responsive Design
**Priority:** P2  
**Test Owner:** Design Test Agent

#### Test Cases
| ID | Test Case | Screen Sizes | Expected | Priority |
|----|-----------|--------------|----------|----------|
| UI-201 | Phone layout | 360x640 | No horizontal overflow | P0 |
| UI-202 | Tablet layout | 768x1024 | Master-detail view | P1 |
| UI-203 | Desktop layout | 1920x1080 | Proper window sizing | P1 |
| UI-204 | Landscape mode | Rotate device | Layout adapts | P1 |
| UI-205 | Keyboard avoidance | Open keyboard | Form not hidden | P0 |

#### Test Files
- `frontend/test/core/widgets/adaptive_layout_test.dart`
- `frontend/test/core/widgets/adaptive_scaffold_test.dart`
- `frontend/integration_test/responsive_test.dart`

---

## Test Execution Plan

### Phase 1: Parallel Expert Agent Deployment (Day 1)

Launch 6 expert agents simultaneously:

1. **Backend Functional Test Agent**
   - Scope: AUTH, SYNC, AI, PUBLISH, COLLAB backend tests
   - Deliverables: Test results, coverage report, bug list

2. **Frontend Functional Test Agent**
   - Scope: AUTH, SYNC, AI, PUBLISH, COLLAB frontend tests
   - Deliverables: Test results, coverage report, bug list

3. **Security & Crypto Test Agent**
   - Scope: All security tests, encryption validation
   - Deliverables: Security audit report, vulnerability findings

4. **Performance Test Agent**
   - Scope: Backend and frontend performance tests
   - Deliverables: Performance baselines, bottleneck analysis

5. **UX & Accessibility Test Agent**
   - Scope: Interaction design, accessibility, error handling
   - Deliverables: UX issues list, accessibility audit

6. **UI/UX Design Test Agent**
   - Scope: Visual consistency, component quality, responsive design
   - Deliverables: Design compliance report, visual regression findings

### Phase 2: Integration & Regression Testing (Day 2)

1. **Cross-feature integration tests**
   - Auth → Sync → Collab flow
   - AI → Publish flow
   - Multi-device sync scenarios

2. **Performance regression detection**
   - Compare against v2.5.0 baselines
   - Identify degradations

3. **Security regression**
   - Verify no new vulnerabilities introduced

### Phase 3: Reporting & Recommendations (Day 3)

1. **Consolidate findings from all agents**
2. **Prioritize issues by impact**
3. **Create fix recommendations**
4. **Generate comprehensive test report**

---

## Success Criteria

### Must Have (P0)
- All P0 functional tests pass
- All P0 security tests pass
- No critical vulnerabilities
- All P0 accessibility tests pass
- Performance within 20% of baseline

### Should Have (P1)
- 95%+ P1 test pass rate
- No P1 security vulnerabilities
- Performance within 10% of baseline
- All P1 UX issues addressed

### Nice to Have (P2)
- 90%+ P2 test pass rate
- Performance improvements over baseline
- All P2 design inconsistencies addressed

---

## Deliverables

1. **Comprehensive Test Report** (`test-report-v260-final.md`)
   - Executive summary
   - Detailed findings by dimension
   - Issue prioritization
   - Recommendations

2. **Security Audit Report** (`security-audit-v260.md`)
   - Vulnerability findings
   - Risk assessment
   - Remediation steps

3. **Performance Baseline Report** (`performance-baseline-v260.md`)
   - Metrics for all perf tests
   - Comparison with v2.5.0
   - Optimization recommendations

4. **UX/UX Review Report** (`ux-compliance-v260.md`)
   - Design compliance score
   - Accessibility audit
   - Visual consistency issues

5. **Test Coverage Report** (`coverage-report-v260.md`)
   - Backend coverage percentage
   - Frontend coverage percentage
   - Gaps and recommendations

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Agent rate limits | Delayed testing | Limit to 3 parallel agents initially |
| Infrastructure issues | Blocked tests | Use mocked services where possible |
| Test data corruption | Invalid results | Use isolated test databases |
| Device unavailability | Incomplete testing | Prioritize emulator/simulator testing |

---

*Test Plan Version: 1.0*  
*Last Updated: 2026-05-09*  
*Next Review: After Phase 1 completion*
