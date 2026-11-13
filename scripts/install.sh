#!/bin/bash
# Build reMarkable Share and install it to /Applications, then launch it.
#
# Usage: ./scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="reMarkable Share"
DEST="/Applications/$APP_NAME.app"

./scripts/build.sh

# Quit a running copy (it stops any active stream on the way out).
osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -xq RemarkableShare || break
  sleep 1
done

echo "Installing to $DEST..."
rm -rf "$DEST"
ditto "build.noindex/$APP_NAME.app" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

open "$DEST"
echo "Done. Look for the reMarkable Share icon in your menu bar (top-right)."
