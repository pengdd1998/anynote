#!/usr/bin/env bash
# release.sh — One-command release for AnyNote
# Usage: ./scripts/release.sh [patch|minor|major] (default: patch)
#
# Steps:
#   1. Verify clean working tree
#   2. Read current version from git tags
#   3. Bump version
#   4. Generate changelog from conventional commits
#   5. Create git tag
#   6. Push tag (triggers CD pipeline)
#
set -euo pipefail

BUMP="${1:-patch}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# ── Colors ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Pre-flight checks ────────────────────────────────
command -v git >/dev/null || error "git not found"

# Verify clean working tree
if [[ -n $(git status --porcelain) ]]; then
    error "Working tree is not clean. Commit or stash changes first."
fi

# Verify we're on main/master
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
    error "Not on main/master branch (current: $BRANCH)"
fi

# Pull latest
info "Pulling latest changes..."
git pull --ff-only

# ── Version bump ────────────────────────────────────
# Get latest tag, strip 'v' prefix
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
CURRENT_VERSION="${LATEST_TAG#v}"

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$BUMP" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        error "Unknown bump type: $BUMP. Use: patch, minor, or major"
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_TAG="v${NEW_VERSION}"

info "Version: ${CURRENT_VERSION} → ${NEW_VERSION}"

# ── Generate changelog ──────────────────────────────
PREV_TAG="${LATEST_TAG}"
if [[ "$PREV_TAG" == "v0.0.0" ]]; then
    # No previous tag, use initial commit
    PREV_TAG=$(git rev-list --max-parents=0 HEAD)
fi

CHANGELOG=$(
    git log "${PREV_TAG}..HEAD" --pretty=format:"- %s (%h)" --no-merges | \
    sed -E '
        s/^- feat(\([^)]*\))?:/- **feat**:/p
        s/^- fix(\([^)]*\))?:/- **fix**:/p
        s/^- docs(\([^)]*\))?:/- **docs**:/p
        s/^- refactor(\([^)]*\))?:/- **refactor**:/p
        s/^- perf(\([^)]*\))?:/- **perf**:/p
        s/^- test(\([^)]*\))?:/- **test**:/p
        s/^- chore(\([^)]*\))?:/- **chore**:/p
    ' | head -100
)

if [[ -z "$CHANGELOG" ]]; then
    warn "No conventional commits found since ${PREV_TAG}"
    CHANGELOG="- No notable changes"
fi

# ── Update CHANGELOG.md ─────────────────────────────
CHANGELOG_FILE="CHANGELOG.md"
HEADER="## ${NEW_VERSION} ($(date +%Y-%m-%d))"

if [[ -f "$CHANGELOG_FILE" ]]; then
    # Insert new entry after the header
    TEMP=$(mktemp)
    {
        head -1 "$CHANGELOG_FILE"
        echo ""
        echo "$HEADER"
        echo ""
        echo "$CHANGELOG"
        echo ""
        tail -n +2 "$CHANGELOG_FILE"
    } > "$TEMP"
    mv "$TEMP" "$CHANGELOG_FILE"
else
    {
        echo "# Changelog"
        echo ""
        echo "$HEADER"
        echo ""
        echo "$CHANGELOG"
    } > "$CHANGELOG_FILE"
fi

info "Updated CHANGELOG.md"

# ── Confirm ──────────────────────────────────────────
echo ""
echo "──────────────────────────────────────"
echo "Release: ${NEW_TAG}"
echo ""
echo "Changes:"
echo "$CHANGELOG" | head -20
echo "──────────────────────────────────────"
echo ""

read -rp "Create tag ${NEW_TAG} and push? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    warn "Aborted. Changes to CHANGELOG.md are uncommitted."
    exit 0
fi

# ── Commit changelog and create tag ──────────────────
git add CHANGELOG.md
git commit -m "chore: release ${NEW_TAG}"
git tag -a "$NEW_TAG" -m "Release ${NEW_TAG}

$(echo "$CHANGELOG" | head -50)"

info "Created tag: ${NEW_TAG}"

# ── Push ─────────────────────────────────────────────
info "Pushing commit and tag..."
git push
git push origin "$NEW_TAG"

info "Release ${NEW_TAG} pushed! CD pipeline should trigger."
