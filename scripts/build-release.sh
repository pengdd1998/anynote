#!/usr/bin/env bash
# build-release.sh — Build release artifacts for AnyNote
# Usage: ./scripts/build-release.sh [android|ios|web|all] (default: all)
#
# Prerequisites:
#   - Flutter SDK installed and in PATH
#   - Android: ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD,
#     ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD set in environment
#   - iOS: macOS with Xcode, valid signing certificate, and provisioning profile
#   - Web: None extra required
#
# Steps:
#   1. Check for required tools
#   2. Run tests
#   3. Generate Drift code
#   4. Generate localization files
#   5. Build for specified platform(s)
#   6. Report output locations
#
set -euo pipefail

PLATFORM="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTEND_DIR="${PROJECT_DIR}/frontend"
BACKEND_DIR="${PROJECT_DIR}/backend"

cd "$PROJECT_DIR"

# ── Colors ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
step()  { echo -e "${BLUE}[STEP]${NC} $*"; }

# ── Version info ────────────────────────────────────
VERSION=$(grep '^version:' frontend/pubspec.yaml | sed 's/version: //')
info "Building AnyNote version: ${VERSION}"

# ── Check required tools ────────────────────────────
step "Checking required tools..."

command -v flutter >/dev/null || error "flutter not found in PATH"
flutter --version | head -1

if [[ "$PLATFORM" == "android" || "$PLATFORM" == "all" ]]; then
    command -v java >/dev/null || warn "java not found (needed for Android build)"
fi

if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
    if [[ "$(uname)" != "Darwin" ]]; then
        warn "iOS builds require macOS with Xcode. Skipping iOS."
        if [[ "$PLATFORM" == "ios" ]]; then
            error "Cannot build iOS on non-macOS system"
        fi
        PLATFORM="android_web"
    fi
fi

# ── Run tests ───────────────────────────────────────
step "Running frontend tests..."
cd "$FRONTEND_DIR"
flutter test --reporter compact 2>&1 | tail -5
info "Frontend tests passed"

# ── Run backend tests (if building all or backend present) ──
if [[ -d "$BACKEND_DIR" ]]; then
    step "Running backend tests..."
    cd "$BACKEND_DIR"
    go test ./... -count=1 2>&1 | tail -5
    info "Backend tests passed"
fi

cd "$FRONTEND_DIR"

# ── Generate code ────────────────────────────────────
step "Generating Drift code..."
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -3
info "Drift code generated"

step "generating localization files..."
flutter gen-l10n 2>&1 | tail -3
info "Localization files generated"

# ── Get dependencies ────────────────────────────────
step "Getting Flutter dependencies..."
flutter pub get 2>&1 | tail -3

# ── Build functions ──────────────────────────────────

build_android_apk() {
    step "Building Android release APK..."
    if [[ -z "${ANDROID_KEYSTORE_PATH:-}" ]]; then
        warn "ANDROID_KEYSTORE_PATH not set. Build will use debug signing."
        warn "Set these environment variables for a signed release:"
        warn "  ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD,"
        warn "  ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD"
    fi
    flutter build apk --release 2>&1 | tail -5
    info "Android APK: ${FRONTEND_DIR}/build/app/outputs/flutter-apk/app-release.apk"
}

build_android_aab() {
    step "Building Android release AAB (App Bundle)..."
    flutter build appbundle --release 2>&1 | tail -5
    info "Android AAB: ${FRONTEND_DIR}/build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
    step "Building iOS release IPA..."
    flutter build ipa --release 2>&1 | tail -5
    info "iOS IPA: ${FRONTEND_DIR}/build/ios/ipa/anynote.ipa"
}

build_web() {
    step "Building web release..."
    flutter build web --release 2>&1 | tail -5
    info "Web: ${FRONTEND_DIR}/build/web/"
}

# ── Execute builds ───────────────────────────────────
case "$PLATFORM" in
    android)
        build_android_apk
        build_android_aab
        ;;
    ios)
        build_ios
        ;;
    web)
        build_web
        ;;
    android_web)
        build_android_apk
        build_android_aab
        build_web
        ;;
    all)
        build_android_apk
        build_android_aab
        build_ios
        build_web
        ;;
    *)
        error "Unknown platform: ${PLATFORM}. Use: android, ios, web, or all"
        ;;
esac

# ── Summary ──────────────────────────────────────────
echo ""
echo "============================================"
echo "  AnyNote ${VERSION} build complete"
echo "============================================"
echo ""

if [[ "$PLATFORM" == "android" || "$PLATFORM" == "all" || "$PLATFORM" == "android_web" ]]; then
    echo "  Android APK: frontend/build/app/outputs/flutter-apk/app-release.apk"
    echo "  Android AAB: frontend/build/app/outputs/bundle/release/app-release.aab"
fi
if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
    echo "  iOS IPA:     frontend/build/ios/ipa/anynote.ipa"
fi
if [[ "$PLATFORM" == "web" || "$PLATFORM" == "all" || "$PLATFORM" == "android_web" ]]; then
    echo "  Web:         frontend/build/web/"
fi
echo ""
info "Build complete!"
