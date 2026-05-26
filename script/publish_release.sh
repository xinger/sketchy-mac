#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SketchyMac"
REPO="${GITHUB_REPOSITORY:-xinger/sketchy-mac}"

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <version> <build> [release-notes-file]" >&2
  exit 2
fi

VERSION="$1"
BUILD="$2"
RELEASE_NOTES_FILE="${3:-}"
TAG="v$VERSION"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="$ROOT_DIR/dist/releases/$APP_NAME-$VERSION-$BUILD.zip"

if [[ ! -f "$ARCHIVE" ]]; then
  echo "release archive not found: $ARCHIVE" >&2
  echo "run: script/package_update.sh $VERSION $BUILD" >&2
  exit 1
fi

if [[ -n "$RELEASE_NOTES_FILE" && ! -f "$RELEASE_NOTES_FILE" ]]; then
  echo "release notes file not found: $RELEASE_NOTES_FILE" >&2
  exit 1
fi

cd "$ROOT_DIR"

if [[ -n "$(git status --short)" ]]; then
  echo "working tree has uncommitted changes; commit and push before publishing a release" >&2
  git status --short >&2
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "not on a branch; checkout the release branch before publishing" >&2
  exit 1
fi

UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -z "$UPSTREAM" ]]; then
  UPSTREAM="origin/$CURRENT_BRANCH"
fi

LOCAL_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse "$UPSTREAM" 2>/dev/null || true)"
if [[ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]]; then
  echo "current commit is not pushed to $UPSTREAM; push before publishing a release" >&2
  exit 1
fi

notes_args=(--notes "Sketchy $VERSION")
if [[ -n "$RELEASE_NOTES_FILE" ]]; then
  notes_args=(--notes-file "$RELEASE_NOTES_FILE")
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ARCHIVE" --clobber --repo "$REPO"

  if [[ -n "$RELEASE_NOTES_FILE" ]]; then
    gh release edit "$TAG" --repo "$REPO" --title "Sketchy $VERSION" --notes-file "$RELEASE_NOTES_FILE"
  fi
else
  gh release create "$TAG" "$ARCHIVE" \
    --repo "$REPO" \
    --target "$CURRENT_BRANCH" \
    --title "Sketchy $VERSION" \
    "${notes_args[@]}"
fi

gh api "repos/$REPO/releases/tags/$TAG" \
  --jq ".assets[] | select(.name == \"$APP_NAME-$VERSION-$BUILD.zip\") | {name, size, digest, browser_download_url}"
