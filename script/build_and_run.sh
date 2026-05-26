#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Sketchy"
BUNDLE_ID="com.xinger.SketchyMac"
MIN_SYSTEM_VERSION="11.0"
APP_VERSION="${SKETCHY_VERSION:-0.1.0}"
APP_BUILD="${SKETCHY_BUILD:-1}"
SWIFT_CONFIGURATION="${SKETCHY_CONFIGURATION:-debug}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://xinger.github.io/sketchy-mac/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-aDpl0L5YwOurr7XdpQNHayGZboAw3g5WaxRxxK0mO2E=}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PACKAGE_DIR="$DIST_DIR/releases"
ZIP_ARCHIVE="$PACKAGE_DIR/$APP_NAME-$APP_VERSION-$APP_BUILD.zip"
SOURCE_RESOURCES="$ROOT_DIR/Sources/Sketchy/Resources"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-module-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

find_sparkle_framework() {
  find "$ROOT_DIR/.build/artifacts" -path "*/Sparkle.framework" -type d | head -n 1
}

copy_sparkle_framework() {
  local sparkle_framework
  sparkle_framework="$(find_sparkle_framework)"

  if [[ -z "$sparkle_framework" ]]; then
    echo "Sparkle.framework was not found. Run: swift package resolve" >&2
    exit 1
  fi

  mkdir -p "$APP_FRAMEWORKS"
  ditto "$sparkle_framework" "$APP_FRAMEWORKS/Sparkle.framework"
}

copy_app_resources() {
  mkdir -p "$APP_RESOURCES"

  if [[ -d "$SOURCE_RESOURCES" ]]; then
    ditto "$SOURCE_RESOURCES" "$APP_RESOURCES"
  fi
}

add_framework_rpath() {
  if ! otool -l "$APP_BINARY" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY"
  fi
}

write_info_plist() {
  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
</dict>
</plist>
PLIST
}

build_bundle() {
  if [[ "$SWIFT_CONFIGURATION" == "release" ]]; then
    swift build --configuration release
    BUILD_BINARY="$(swift build --configuration release --show-bin-path)/$APP_NAME"
  else
    swift build
    BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
  fi

  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS"
  cp "$BUILD_BINARY" "$APP_BINARY"
  chmod +x "$APP_BINARY"

  copy_sparkle_framework
  copy_app_resources
  add_framework_rpath
  write_info_plist
  codesign --force --deep --sign - "$APP_BUNDLE"
}

package_archive() {
  mkdir -p "$PACKAGE_DIR"
  rm -f "$ZIP_ARCHIVE"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_ARCHIVE"
  shasum -a 256 "$ZIP_ARCHIVE"
}

build_bundle

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  build)
    echo "$APP_BUNDLE"
    ;;
  package)
    package_archive
    echo "$ZIP_ARCHIVE"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|build|package|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
