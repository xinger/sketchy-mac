#!/usr/bin/env bash
set -euo pipefail

APPCAST_PATH="docs/appcast.xml"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <version> [release-notes-file]" >&2
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

if [[ -n "$(git status --short)" ]]; then
  echo "working tree has uncommitted changes; commit or stash them before release" >&2
  git status --short >&2
  exit 1
fi

if [[ -n "$RELEASE_NOTES_FILE" && ! -f "$RELEASE_NOTES_FILE" ]]; then
  echo "release notes file not found: $RELEASE_NOTES_FILE" >&2
  exit 1
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
cp "$ROOT_DIR/dist/appcast/appcast.xml" "$APPCAST_PATH"

if git diff --quiet -- "$APPCAST_PATH"; then
  echo "$APPCAST_PATH is unchanged; no release commit needed"
else
  git add "$APPCAST_PATH"
  git commit -m "release: $VERSION"
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "not on a branch; checkout the release branch before publishing" >&2
  exit 1
fi

git push origin "$CURRENT_BRANCH"
"$ROOT_DIR/script/publish_release.sh" "$VERSION" "$BUILD" "$RELEASE_NOTES_FILE"
