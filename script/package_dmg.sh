#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Sketchy"

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <build>" >&2
  exit 2
fi

VERSION="$1"
BUILD="$2"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
PACKAGE_DIR="$DIST_DIR/releases"
DMG_ROOT="$DIST_DIR/dmg"
DMG_STAGE="$DMG_ROOT/$APP_NAME-$VERSION-$BUILD"
DMG_ARCHIVE="$PACKAGE_DIR/$APP_NAME-$VERSION-$BUILD.dmg"
DMG_TEMP="$DMG_ROOT/$APP_NAME-$VERSION-$BUILD.rw.dmg"
DMG_MOUNT="$DMG_ROOT/mount-$APP_NAME-$VERSION-$BUILD"
DMG_BACKGROUND="$DMG_STAGE/.background/background.png"
BACKGROUND_SCRIPT="$DMG_ROOT/create_dmg_background.swift"
DMG_ATTACHED=0

cleanup() {
  if [[ "$DMG_ATTACHED" -eq 1 ]]; then
    hdiutil detach "$DMG_MOUNT" >/dev/null 2>&1 || true
  fi

  rm -rf "$DMG_MOUNT"
}

trap cleanup EXIT

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST" 2>/dev/null || true
}

bundle_matches_release() {
  [[ -d "$APP_BUNDLE" ]] || return 1
  [[ "$(plist_value CFBundleShortVersionString)" == "$VERSION" ]] || return 1
  [[ "$(plist_value CFBundleVersion)" == "$BUILD" ]] || return 1
}

if ! bundle_matches_release; then
  SKETCHY_VERSION="$VERSION" \
  SKETCHY_BUILD="$BUILD" \
  SKETCHY_CONFIGURATION=release \
  "$ROOT_DIR/script/build_and_run.sh" build >/dev/null
fi

mkdir -p "$PACKAGE_DIR" "$DMG_ROOT"
rm -rf "$DMG_STAGE" "$DMG_MOUNT" "$DMG_ARCHIVE" "$DMG_TEMP"
mkdir -p "$DMG_STAGE/.background"

ditto "$APP_BUNDLE" "$DMG_STAGE/$APP_NAME.app"
ln -s /Applications "$DMG_STAGE/Applications"

cat >"$DMG_STAGE/Launch.command" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

APP_PATH="/Applications/Sketchy.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Sketchy.app was not found in Applications."
  echo "Drag Sketchy.app to Applications first, then run Launch again."
  echo
  read -r -p "Press Return to close this window..."
  exit 1
fi

if ! /usr/bin/xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null; then
  echo "Could not remove quarantine automatically."
  echo "Run this command manually:"
  echo
  echo "xattr -dr com.apple.quarantine \"$APP_PATH\""
  echo
  read -r -p "Press Return to close this window..."
  exit 1
fi

/usr/bin/open "$APP_PATH"
SCRIPT

chmod +x "$DMG_STAGE/Launch.command"

cat >"$BACKGROUND_SCRIPT" <<'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let canvasSize = NSSize(width: 600, height: 320)
let image = NSImage(size: canvasSize)

func drawCentered(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let rect = NSRect(x: 0, y: y, width: canvasSize.width, height: font.pointSize + 12)
    NSString(string: text).draw(in: rect, withAttributes: attributes)
}

image.lockFocus()

NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.91, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

func drawArrow(from startX: CGFloat, to endX: CGFloat, y: CGFloat) {
    let color = NSColor(calibratedRed: 0.76, green: 0.70, blue: 0.60, alpha: 1)

    let path = NSBezierPath()
    path.lineWidth = 4
    path.lineCapStyle = .round
    path.move(to: NSPoint(x: startX, y: y))
    path.line(to: NSPoint(x: endX - 18, y: y))
    color.setStroke()
    path.stroke()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: endX, y: y))
    arrow.line(to: NSPoint(x: endX - 20, y: y + 12))
    arrow.line(to: NSPoint(x: endX - 20, y: y - 12))
    arrow.close()
    color.setFill()
    arrow.fill()
}

drawArrow(from: 170, to: 238, y: 188)
drawArrow(from: 370, to: 438, y: 188)

drawCentered(
    "Drag Sketchy to Applications and then run Launch script",
    y: 30,
    font: NSFont.systemFont(ofSize: 13, weight: .medium),
    color: NSColor(calibratedRed: 0.35, green: 0.32, blue: 0.28, alpha: 1)
)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not render DMG background")
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

swift "$BACKGROUND_SCRIPT" "$DMG_BACKGROUND"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDRW \
  "$DMG_TEMP"

mkdir -p "$DMG_MOUNT"
hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$DMG_MOUNT" \
  "$DMG_TEMP" >/dev/null
DMG_ATTACHED=1

osascript <<APPLESCRIPT
tell application "Finder"
  tell folder POSIX file "$DMG_MOUNT"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    try
      set pathbar visible of container window to false
    end try
    set bounds of container window to {100, 100, 700, 475}

    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 80
    set text size of viewOptions to 13
    set background picture of viewOptions to POSIX file "$DMG_MOUNT/.background/background.png"

    set position of item "$APP_NAME.app" to {95, 130}
    set position of item "Applications" to {300, 130}
    set position of item "Launch.command" to {505, 130}
    set extension hidden of item "Launch.command" to true

    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DMG_MOUNT" >/dev/null
DMG_ATTACHED=0
rm -rf "$DMG_MOUNT"

hdiutil convert "$DMG_TEMP" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_ARCHIVE" >/dev/null

rm -f "$DMG_TEMP"

shasum -a 256 "$DMG_ARCHIVE"
echo "DMG: $DMG_ARCHIVE"
