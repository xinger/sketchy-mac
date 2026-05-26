# Release Architecture Reference

This reference describes a portable macOS release setup for apps that use Sparkle and GitHub.

## Distribution Model

- GitHub Pages hosts `appcast.xml` and the website.
- GitHub Releases hosts `.zip` and `.dmg` assets.
- Website download points to the `.dmg`.
- Sparkle appcast points to the `.zip`.
- Release notes live in `docs/release-notes/<version>.md`.

This split keeps first install pleasant while keeping Sparkle updates simple and predictable.

## Required Inputs

- App name and stable bundle identifier.
- Build command that can produce a `.app`.
- Sparkle framework and `generate_appcast` binary.
- Sparkle EdDSA public key in `Info.plist`; private key available for appcast signing.
- GitHub Pages URL, repository slug, and authenticated `gh` CLI.
- Release tag convention, usually `v<version>`.

## App Integration

The app should keep a Sparkle updater controller alive for the app lifetime:

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

The final `Info.plist` needs at least:

```xml
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUFeedURL</key>
<string>https://OWNER.github.io/REPO/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>...</string>
```

## Script Responsibilities

### Build or Stage App

- Build release binary.
- Stage `dist/<App>.app`.
- Write/update `Info.plist`.
- Copy `Sparkle.framework` into `Contents/Frameworks`.
- Add framework rpath when needed.
- Ad-hoc sign unsigned builds.

### Package Sparkle Update

- Create `dist/releases/<App>-<version>-<build>.zip`.
- Use:

```bash
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_ARCHIVE"
```

- Start appcast generation from tracked `docs/appcast.xml`.
- Clean generated appcast staging directory before copying the new zip.
- Copy notes next to the zip as `<App>-<version>-<build>.md`.
- Run `generate_appcast --embed-release-notes` when notes exist.
- Use `--versions <build>` so the new item gets the intended Sparkle build.

### Package DMG

- Stage `<App>.app`.
- Add `Applications` symlink.
- Add optional `Launch.command`.
- Generate `.background/background.png`.
- Create a temporary read-write DMG.
- Mount it and use Finder AppleScript for icon positions, icon size, background, hidden extensions, and window bounds.
- Convert to compressed `UDZO`.
- Verify with `hdiutil verify`.

### Release

The one-command release script should:

- Reject dirty working trees.
- Accept `script/release.sh <version>`.
- Determine the next build number from the current appcast or project metadata.
- Auto-use `docs/release-notes/<version>.md` if present.
- Build zip and appcast.
- Build DMG.
- Copy generated appcast to `docs/appcast.xml`.
- Update website download link to the DMG.
- Commit release files in one commit.
- Push the branch.
- Create or update GitHub Release and upload both assets.

## Release Notes

Write product-facing notes, not raw commit logs:

```markdown
## App 1.2.3

- Added faster canvas export.
- Improved first-launch onboarding.
- Fixed update checks on slow networks.
```

Use the same notes file for:

- GitHub Release body.
- Sparkle appcast description.
- Local release history.

## Verification Checklist

```bash
bash -n script/release.sh
bash -n script/package_update.sh
bash -n script/package_dmg.sh
bash -n script/publish_release.sh
```

```bash
script/package_update.sh 1.2.3 4 "" docs/release-notes/1.2.3.md
rg -n "description|sparkle:version|enclosure" dist/appcast/appcast.xml
```

Check:

- New appcast item has the new version and build.
- New enclosure URL points to the new zip.
- Old item URLs keep their original release tags.
- Notes appear as `<description sparkle:format="markdown">`.

```bash
script/package_dmg.sh 1.2.3 4
hdiutil verify dist/releases/App-1.2.3-4.dmg
```

After publishing:

```bash
gh api repos/OWNER/REPO/releases/tags/v1.2.3 \
  --jq '.assets[] | {name, size, digest, browser_download_url}'

curl -sL https://OWNER.github.io/REPO/appcast.xml | sed -n '1,80p'
```

## Common Pitfalls

- Do not point the website at the zip when the intended install UX is DMG.
- Do not point Sparkle at the DMG unless that path was explicitly tested.
- Do not regenerate appcast from a stale staging directory.
- Do not change `CFBundleIdentifier` after users install the app.
- Do not edit signed appcast output manually; regenerate it.
- Do not treat `Launch.command` as notarization. It is only a convenience helper for unsigned builds.
- Account for Finder chrome differences when tuning DMG size; tight backgrounds can cause clipped labels or bottom strips.
