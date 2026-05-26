#!/usr/bin/env bash
set -euo pipefail

APPCAST_PATH="docs/appcast.xml"
SITE_INDEX_PATH="docs/index.html"
RELEASE_NOTES_DIR="docs/release-notes"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <version> [release-notes-file]" >&2
  echo "if release-notes-file is omitted, $RELEASE_NOTES_DIR/<version>.md is used when present" >&2
  exit 2
fi

VERSION="$1"
RELEASE_NOTES_FILE="${2:-}"

if [[ ! "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "version must look like 1.5.0, without a leading v" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "$RELEASE_NOTES_FILE" && -f "$RELEASE_NOTES_DIR/$VERSION.md" ]]; then
  RELEASE_NOTES_FILE="$RELEASE_NOTES_DIR/$VERSION.md"
fi

if [[ -n "$(git status --short)" ]]; then
  echo "working tree has uncommitted changes; commit or stash them before release" >&2
  git status --short >&2
  exit 1
fi

if [[ -n "$RELEASE_NOTES_FILE" && ! -f "$RELEASE_NOTES_FILE" ]]; then
  echo "release notes file not found: $RELEASE_NOTES_FILE" >&2
  exit 1
fi

if [[ -n "$RELEASE_NOTES_FILE" ]]; then
  echo "Using release notes: $RELEASE_NOTES_FILE"
fi

next_build_number() {
  if [[ ! -f "$APPCAST_PATH" ]]; then
    echo 1
    return
  fi

  local latest
  latest="$(
    awk -F'[<>]' '/<sparkle:version>/{ print $3 }' "$APPCAST_PATH" |
      sort -nr |
      head -n 1
  )"

  if [[ -z "$latest" ]]; then
    echo 1
  else
    echo $((latest + 1))
  fi
}

BUILD="$(next_build_number)"

"$ROOT_DIR/script/package_update.sh" "$VERSION" "$BUILD" "" "$RELEASE_NOTES_FILE"
"$ROOT_DIR/script/package_dmg.sh" "$VERSION" "$BUILD"
cp "$ROOT_DIR/dist/appcast/appcast.xml" "$APPCAST_PATH"

python3 - "$SITE_INDEX_PATH" "$VERSION" "$BUILD" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
version = sys.argv[2]
build = sys.argv[3]
text = path.read_text()

text = re.sub(
    r"https://github[.]com/xinger/sketchy-mac/releases/download/v[^/]+/(?:SketchyMac|Sketchy)-[^\"/]+[.](?:zip|dmg)",
    f"https://github.com/xinger/sketchy-mac/releases/download/v{version}/Sketchy-{version}-{build}.dmg",
    text,
)
text = re.sub(
    r"https://github[.]com/xinger/sketchy-mac/releases/tag/v[^\"#?]+",
    f"https://github.com/xinger/sketchy-mac/releases/tag/v{version}",
    text,
)
text = re.sub(
    r"Get Sketchy [0-9]+[.][0-9]+[.][0-9]+(?:[-+][0-9A-Za-z.-]+)?",
    f"Get Sketchy {version}",
    text,
)

path.write_text(text)
PY

if git diff --quiet -- "$APPCAST_PATH" "$SITE_INDEX_PATH"; then
  echo "$APPCAST_PATH is unchanged; no release commit needed"
else
  git add "$APPCAST_PATH" "$SITE_INDEX_PATH"
  git commit -m "release: $VERSION"
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "not on a branch; checkout the release branch before publishing" >&2
  exit 1
fi

git push origin "$CURRENT_BRANCH"
"$ROOT_DIR/script/publish_release.sh" "$VERSION" "$BUILD" "$RELEASE_NOTES_FILE"
