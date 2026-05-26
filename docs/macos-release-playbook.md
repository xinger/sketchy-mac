# macOS Release Playbook: Sparkle, GitHub Pages, GitHub Releases, DMG

This playbook captures the release setup used by Sketchy. The goal is to ship a
Mac app without an Apple Developer certificate while still giving users a
pleasant download flow and giving the app a reliable Sparkle update channel.

## Distribution Shape

- GitHub Pages hosts the website and the Sparkle appcast.
- GitHub Releases hosts downloadable release assets.
- The website download button points to a `.dmg`.
- Sparkle appcast points to a `.zip`.
- Release notes live in `docs/release-notes/<version>.md`.
- The release script builds both artifacts, updates the site/appcast, commits the
  release files, pushes the branch, and uploads assets to GitHub Release.

This split is intentional: DMG is nicer for first install, while zip is simpler
and reliable for Sparkle updates.

## Requirements

- SwiftPM or another repeatable command that can build a `.app`.
- Sparkle dependency integrated into the app.
- GitHub repository with GitHub Pages enabled from `/docs`.
- GitHub CLI authenticated for the repository.
- Sparkle EdDSA key pair.
- A bundle identifier that stays stable after the first public release.

For unsigned distribution, users may need to remove quarantine manually:

```bash
xattr -dr com.apple.quarantine "/Applications/Sketchy.app"
```

## App Integration

Add Sparkle to the app and keep the updater alive for the app lifetime. In
Sketchy, the app creates a standard updater controller:

```swift
import Sparkle

final class SparkleUpdater {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
}
```

The generated `Info.plist` must include:

```xml
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUFeedURL</key>
<string>https://xinger.github.io/sketchy-mac/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>...</string>
```

Keep `CFBundleIdentifier` stable. Renaming the visible app from `SketchyMac` to
`Sketchy` is fine if the bundle identifier remains the same.

## Files and Directories

```text
docs/
  index.html
  appcast.xml
  release-notes/
    1.2.3.md

script/
  build_and_run.sh
  package_update.sh
  package_dmg.sh
  publish_release.sh
  release.sh

dist/                 # ignored
  Sketchy.app
  releases/
    Sketchy-1.2.3-4.zip
    Sketchy-1.2.3-4.dmg
  appcast/
    appcast.xml
```

## Release Notes

Write short product-facing notes, not raw commit messages:

```markdown
## Sketchy 1.2.3

- Added image paste and drag-and-drop support.
- Improved multi-window drawing history sync.
- Refined freehand drawing for fast strokes.
```

Save them as:

```text
docs/release-notes/<version>.md
```

`script/release.sh <version>` automatically uses that file when present. The
same file is passed to GitHub Release and embedded into Sparkle appcast so
Sparkle can show it in the update window.

Because `script/release.sh` rejects dirty working trees, create and commit the
release notes file before running the release command.

## Packaging Script Responsibilities

### `script/build_and_run.sh`

Build the release binary, stage `dist/<AppName>.app`, write `Info.plist`, copy
Sparkle.framework into the bundle, add the framework rpath, and ad-hoc sign the
app.

The package mode should create:

```text
dist/releases/<AppName>-<version>-<build>.zip
```

Use `ditto` for Sparkle zips:

```bash
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_ARCHIVE"
```

### `script/package_update.sh`

Build the zip and generate the appcast. Important details:

- Start appcast generation from tracked `docs/appcast.xml`.
- Clean stale files from `dist/appcast` before staging the new zip.
- Copy release notes next to the zip as `<AppName>-<version>-<build>.md`.
- Run `generate_appcast --embed-release-notes` when notes are present.
- Use `--versions <build>` to generate the current build entry.

This avoids accidentally rewriting old appcast items with the new release URL.

### `script/package_dmg.sh`

Build a custom DMG for first-time install:

- Stage `Sketchy.app`.
- Add `Applications` symlink.
- Add `Launch.command`.
- Generate a `.background/background.png`.
- Create a read-write temporary DMG.
- Mount it and use Finder AppleScript to set icon view, positions, background,
  window bounds, icon size, and hidden extension for `Launch.command`.
- Convert the temporary image to compressed `UDZO`.
- Verify with `hdiutil verify`.

The Sketchy layout is:

```text
Sketchy.app -> Applications -> Launch
```

`Launch.command` removes quarantine from `/Applications/Sketchy.app` and opens
the app. It is a convenience helper, not a replacement for notarization.

### `script/release.sh`

One-command release:

```bash
script/release.sh 1.2.3
```

Expected behavior:

- Reject dirty working trees.
- Pick next build number from `docs/appcast.xml`.
- Auto-use `docs/release-notes/<version>.md` if present.
- Run `package_update.sh` to create zip and appcast.
- Run `package_dmg.sh` to create DMG.
- Copy generated appcast to `docs/appcast.xml`.
- Update `docs/index.html` download URL to the DMG.
- Commit site/appcast release files.
- Push current branch.
- Run `publish_release.sh`.

### `script/publish_release.sh`

Publish to GitHub Release:

- Require clean working tree.
- Require local head to match upstream.
- Create the GitHub Release and tag when absent, or upload assets to an existing
  GitHub Release.
- Upload both zip and DMG.
- Use release notes file for GitHub Release body when present.
- Print uploaded asset metadata.

## DMG Design Notes

The DMG should feel like a normal Mac installer:

- Keep the window compact.
- Use one row: app, Applications symlink, Launch helper.
- Use a plain background with subtle arrows.
- Hide `Launch.command` extension so Finder shows `Launch`.
- Avoid README files when the visual layout is enough.
- Leave enough vertical room for icon labels; Finder chrome varies by macOS
  version and can clip tight layouts.

If a white strip appears at the bottom, the Finder window content area is taller
than the background image. Increase background height or reduce window height.

If labels are clipped, increase window height or move icons upward.

## Verification Checklist

Run before claiming a release setup works:

```bash
bash -n script/release.sh
bash -n script/package_update.sh
bash -n script/package_dmg.sh
bash -n script/publish_release.sh
```

Build and inspect the update package:

```bash
script/package_update.sh 1.2.3 4 "" docs/release-notes/1.2.3.md
rg -n "description|sparkle:version|enclosure" dist/appcast/appcast.xml
```

Expected appcast checks:

- New item has the new version and build.
- New enclosure URL points to the new zip.
- Old item URLs still point to their original release tags.
- Release notes appear as `<description sparkle:format="markdown">`.

Build and inspect the DMG:

```bash
script/package_dmg.sh 1.2.3 4
hdiutil verify dist/releases/Sketchy-1.2.3-4.dmg
```

Mount and inspect layout if needed:

```bash
hdiutil attach -readonly -noverify -noautoopen \
  -mountpoint "$PWD/dist/dmg-mount" \
  "$PWD/dist/releases/Sketchy-1.2.3-4.dmg"

osascript -e 'tell application "Finder" to get position of item "Sketchy.app" of folder POSIX file "'"$PWD"'/dist/dmg-mount"'
osascript -e 'tell application "Finder" to get position of item "Applications" of folder POSIX file "'"$PWD"'/dist/dmg-mount"'
osascript -e 'tell application "Finder" to get position of item "Launch.command" of folder POSIX file "'"$PWD"'/dist/dmg-mount"'

hdiutil detach "$PWD/dist/dmg-mount"
```

Check the final release after publishing:

```bash
gh api repos/<owner>/<repo>/releases/tags/v1.2.3 \
  --jq '.assets[] | {name, size, digest, browser_download_url}'

curl -sL https://<owner>.github.io/<repo>/appcast.xml | sed -n '1,80p'
```

## Common Pitfalls

- Do not point the website at the zip if the desired install UX is DMG.
- Do not point Sparkle at the DMG unless you explicitly test that path.
- Do not regenerate appcast from a dirty `dist/appcast` directory; stale zips can
  produce wrong URLs or unwanted deltas.
- Do not change `CFBundleIdentifier` after users install the app.
- Do not edit appcast manually after signing unless you re-run `generate_appcast`.
- Do not rely on `Launch.command` as a security bypass; it is only a convenience
  for unsigned builds.
- Be careful with mounted test DMGs. Finder may auto-mount in `/Volumes` or a
  temporary directory, and stale mounts can confuse AppleScript.

## Future Skill Extraction

When converting this playbook into a Codex skill, keep the skill concise and put
long script templates in `assets/` or `references/`. The skill should trigger on
requests like:

- "Add Sparkle auto-update and GitHub release publishing to this Mac app."
- "Set up DMG + Sparkle zip release flow."
- "Make a one-command release script for a macOS app with GitHub Pages appcast."

The skill should first inspect the app name, bundle identifier, project type,
existing release scripts, and GitHub Pages setup, then adapt this workflow to the
project instead of copying Sketchy-specific values blindly.
