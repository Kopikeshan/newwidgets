#!/usr/bin/env bash
#
# Builds Liby in Release and installs it to /Applications, so it runs on its
# own without Xcode open.
#
#   ./Scripts/install.sh
#
# Re-run it after pulling changes. The build happens in a temporary directory,
# so nothing is left behind in the repo.

set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="StudyTimer.xcodeproj"
SCHEME="StudyTimer"
APP_NAME="Liby.app"
DEST="/Applications/$APP_NAME"

command -v xcodebuild >/dev/null || {
    echo "xcodebuild not found. Install Xcode, then:"
    echo "  sudo xcode-select -s /Applications/Xcode.app"
    exit 1
}

derived=$(mktemp -d)
trap 'rm -rf "$derived"' EXIT

echo "Building $SCHEME (Release)..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$derived" \
    build

built="$derived/Build/Products/Release/$APP_NAME"
[ -d "$built" ] || { echo "No app at $built — did the build fail?"; exit 1; }

# Close the running copy so the bundle can be replaced underneath it.
if pgrep -x Liby >/dev/null; then
    echo "Quitting the running copy..."
    osascript -e 'quit app "Liby"' || true
    sleep 1
fi

# Guard the delete: only ever remove a directory at exactly this path.
if [ -e "$DEST" ]; then
    [ -d "$DEST" ] || { echo "$DEST exists but is not an app bundle — stopping."; exit 1; }
    rm -rf "$DEST"
fi

cp -R "$built" "$DEST"
echo "Installed $DEST"

open "$DEST"
echo
echo "If the widget still shows the old build, remove it from the desktop and"
echo "add it again — the system caches widget bundles by location."
