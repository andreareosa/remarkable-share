#!/bin/bash
# Publish a GitHub release: tag vX.Y.Z, build a universal app, zip it, upload it with
# the matching CHANGELOG section as the release notes.
#
# Before running:
#   1. Put the new version in VERSION (e.g. 1.1.0).
#   2. Move the changes under "## [Unreleased]" in CHANGELOG.md to "## [1.1.0] - YYYY-MM-DD"
#      and add the compare/tag links at the bottom.
#   3. Commit both on main.
#
# Usage: ./scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="reMarkable Share"
VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v$VERSION"
ZIP="build.noindex/reMarkable-Share-$VERSION.zip"

die() { echo "error: $*" >&2; exit 1; }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION '$VERSION' isn't MAJOR.MINOR.PATCH."
[[ "$(git branch --show-current)" == "main" ]] || die "Releases are cut from main."
[[ -z "$(git status --porcelain)" ]] || die "Commit or stash your changes first."
git fetch -q origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main isn't in sync with origin/main."
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "Tag $TAG already exists."

# Release notes = the CHANGELOG section for this version.
NOTES="$(awk -v v="$VERSION" '
  $0 ~ "^## \\[" v "\\]" { on = 1; next }
  on && /^## \[/ { exit }
  on && /^\[[^]]+\]: / { exit }
  on { print }
' CHANGELOG.md)"
[[ -n "${NOTES//[[:space:]]/}" ]] || die "No '## [$VERSION]' section in CHANGELOG.md."

echo "── Tests ──"
swift test -q

echo "── Universal build ──"
UNIVERSAL=1 ./scripts/build.sh
lipo -archs "build.noindex/$APP_NAME.app/Contents/MacOS/RemarkableShare"
rm -f "$ZIP"
ditto -c -k --keepParent "build.noindex/$APP_NAME.app" "$ZIP"

INSTALL_NOTE='### Install

1. Download **reMarkable-Share-'"$VERSION"'.zip** below, unzip it and move **reMarkable Share** to Applications.
2. The app is not notarized by Apple, so the first launch is blocked. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** (or run `xattr -dr com.apple.quarantine "/Applications/reMarkable Share.app"`).
3. Plug in your tablet and choose **Set Up…** from the menu bar icon.

Prefer to build it yourself? See the [README](https://github.com/andreareosa/remarkable-share#install).'

echo "── Tag + release $TAG ──"
git tag -a "$TAG" -m "$APP_NAME $VERSION"
git push -q origin "$TAG"
gh release create "$TAG" "$ZIP" \
  --repo andreareosa/remarkable-share \
  --title "$APP_NAME $VERSION" \
  --notes "$NOTES

$INSTALL_NOTE" \
  --verify-tag

echo "Released: https://github.com/andreareosa/remarkable-share/releases/tag/$TAG"
