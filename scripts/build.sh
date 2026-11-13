#!/bin/bash
# Build "reMarkable Share.app" into ./build (Release, ad-hoc signed for this Mac).
#
# Usage: ./scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="reMarkable Share"
BUNDLE_ID="com.areosa.remarkable-share"
VERSION="$(cat VERSION)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
OUT="build.noindex/$APP_NAME.app"  # .noindex: keep Spotlight/Launchpad from listing a second copy

if ! xcrun --find swift >/dev/null 2>&1; then
  echo "error: Swift toolchain not found. Install Xcode or the Command Line Tools." >&2
  exit 1
fi

echo "Building $APP_NAME $VERSION ($BUILD_NUMBER)..."
swift build -c release --product RemarkableShare
BIN="$(swift build -c release --show-bin-path)/RemarkableShare"

# Icon is generated once and committed; regenerate by deleting Resources/AppIcon.icns.
if [[ ! -f Resources/AppIcon.icns ]]; then
  echo "Rendering app icon..."
  tmp="$(mktemp -d)"
  swift scripts/make-icon.swift "$tmp" >/dev/null
  iconutil -c icns "$tmp/AppIcon.iconset" -o Resources/AppIcon.icns
  rm -rf "$tmp"
fi

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/RemarkableShare"
cp Resources/AppIcon.icns "$OUT/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$OUT/Contents/Info.plist"
plutil -lint "$OUT/Contents/Info.plist" >/dev/null

# Ad-hoc signature with a stable identifier, so macOS keeps the Local Network
# and Keychain decisions attached to this app across rebuilds.
codesign --force --sign - --identifier "$BUNDLE_ID" --options runtime \
  --entitlements Resources/RemarkableShare.entitlements "$OUT"
codesign --verify --strict "$OUT"

echo "Built: $OUT"
