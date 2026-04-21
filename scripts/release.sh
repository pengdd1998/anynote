#!/usr/bin/env bash
# release.sh — One-command release for AnyNote
# Usage: ./scripts/release.sh [patch|minor|major] (default: patch)
#
# Steps:
#   1. Verify clean working tree
#   2. Read current version from git tags (format: vX.Y.Z)
#   3. Bump version (patch/minor/major)
#   4. Create annotated git tag
#   5. Push tag to origin (triggers CD pipeline)
#   6. Print the new version
#
set -euo pipefail

BUMP="${1:-patch}"

# ── Pre-flight checks ────────────────────────────────
command -v git >/dev/null || { echo "[ERROR] git not found" >&2; exit 1; }

# Verify clean working tree
if [[ -n $(git status --porcelain) ]]; then
    echo "[ERROR] Working tree is not clean. Commit or stash changes first." >&2
    exit 1
fi

# Verify we are on main or master
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
    echo "[ERROR] Not on main/master branch (current: $BRANCH)" >&2
    exit 1
fi

# ── Read current version ─────────────────────────────
# Get the latest tag matching vX.Y.Z, default to v0.1.0 if none exists
LATEST_TAG=$(git tag --list 'v*' --sort=-version:refname | head -1 || true)

if [[ -z "$LATEST_TAG" ]]; then
    LATEST_TAG="v0.0.0"
fi

CURRENT_VERSION="${LATEST_TAG#v}"

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# ── Bump version ─────────────────────────────────────
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
        echo "[ERROR] Unknown bump type: $BUMP. Use: patch, minor, or major" >&2
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_TAG="v${NEW_VERSION}"

echo "[INFO] Version: ${LATEST_TAG} -> ${NEW_TAG}"

# ── Create annotated tag ─────────────────────────────
git tag -a "$NEW_TAG" -m "Release ${NEW_TAG}"

echo "[INFO] Created annotated tag: ${NEW_TAG}"

# ── Push tag to origin ───────────────────────────────
git push origin "$NEW_TAG"

echo "[INFO] Pushed tag ${NEW_TAG} to origin"
echo ""
echo "Release ${NEW_TAG} complete. CD pipeline should trigger."
