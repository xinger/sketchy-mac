#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Sketchy"

if [[ $# -lt 2 || $# -gt 4 ]]; then
  echo "usage: $0 <version> <build> [download-url-prefix] [release-notes-file]" >&2
  exit 2
fi

VERSION="$1"
BUILD="$2"
DOWNLOAD_URL_PREFIX="${3:-https://github.com/xinger/sketchy-mac/releases/download/v$VERSION}"
RELEASE_NOTES_FILE="${4:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
UPDATES_DIR="$DIST_DIR/appcast"
ARCHIVE="$DIST_DIR/releases/$APP_NAME-$VERSION-$BUILD.zip"
TRACKED_APPCAST="$ROOT_DIR/docs/appcast.xml"

DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX%/}/"

find_generate_appcast() {
  find "$ROOT_DIR/.build/artifacts" -path "*/bin/generate_appcast" -type f | head -n 1
}

GENERATE_APPCAST="$(find_generate_appcast)"
if [[ -z "$GENERATE_APPCAST" ]]; then
  echo "generate_appcast was not found. Run: swift package resolve" >&2
  exit 1
fi

SKETCHY_VERSION="$VERSION" \
SKETCHY_BUILD="$BUILD" \
SKETCHY_CONFIGURATION=release \
"$ROOT_DIR/script/build_and_run.sh" package

mkdir -p "$UPDATES_DIR"
rm -f "$UPDATES_DIR"/*.zip \
  "$UPDATES_DIR"/*.dmg \
  "$UPDATES_DIR"/*.delta \
  "$UPDATES_DIR"/*.md \
  "$UPDATES_DIR"/*.html \
  "$UPDATES_DIR"/*.txt

if [[ -f "$TRACKED_APPCAST" ]]; then
  cp "$TRACKED_APPCAST" "$UPDATES_DIR/appcast.xml"
fi

cp "$ARCHIVE" "$UPDATES_DIR/"

if [[ -n "$RELEASE_NOTES_FILE" ]]; then
  cp "$RELEASE_NOTES_FILE" "$UPDATES_DIR/$APP_NAME-$VERSION-$BUILD.md"
fi

generate_appcast_args=(
  --download-url-prefix "$DOWNLOAD_URL_PREFIX"
  --versions "$BUILD"
)

if [[ -n "$RELEASE_NOTES_FILE" ]]; then
  generate_appcast_args+=(--embed-release-notes)
fi

"$GENERATE_APPCAST" "${generate_appcast_args[@]}" "$UPDATES_DIR"

echo "Archive: $ARCHIVE"
echo "Appcast: $UPDATES_DIR/appcast.xml"
