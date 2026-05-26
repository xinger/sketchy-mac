---
name: macos-sparkle-github-release
description: Use when a macOS app needs Sparkle auto-updates, GitHub Pages appcast hosting, GitHub Releases asset publishing, release notes, one-command release automation, or a custom DMG installer flow.
---

# macOS Sparkle GitHub Release

## Overview

Use this skill to add a practical unsigned macOS distribution flow: DMG for first install, zip for Sparkle updates, GitHub Pages for the appcast, and GitHub Releases for downloadable assets.

The default architecture is:

```text
Website download -> DMG
Sparkle appcast  -> ZIP
Release notes    -> GitHub Release body + Sparkle update window
```

## First Pass

Inspect before editing:

- Project type: SwiftPM, Xcode project, or custom build.
- App name, bundle identifier, marketing version, build number, and generated `Info.plist` path.
- Existing Sparkle dependency, updater controller, signing, and release scripts.
- GitHub owner/repo, Pages source, Release tag format, and current appcast URL.

Preserve `CFBundleIdentifier` once any user has installed the app. Renaming the visible app is fine; changing the bundle identifier can break update continuity.

## Implementation Shape

Create or adapt these pieces:

- Sparkle integration in the app, with `SUFeedURL`, `SUPublicEDKey`, and automatic checks in `Info.plist`.
- `docs/appcast.xml` hosted by GitHub Pages.
- `docs/release-notes/<version>.md` for short product-facing notes.
- A zip packaging script that stages a clean `.app`, ad-hoc signs if needed, creates a Sparkle-compatible zip, and runs `generate_appcast`.
- A DMG packaging script that stages the `.app`, an `Applications` symlink, and an optional `Launch.command` helper for unsigned quarantine removal.
- A release script that accepts a version, chooses/increments build number, builds zip and DMG, updates `docs/appcast.xml` and the website download URL, commits release files, pushes, and publishes GitHub Release assets.

Use `ditto -c -k --sequesterRsrc --keepParent` for Sparkle zips. Keep appcast generation deterministic: start from the tracked appcast, clean stale generated files, and embed release notes when present.

## DMG Defaults

Make the DMG feel like a normal Mac installer:

```text
App.app -> Applications -> Launch
```

Use a compact icon-view Finder window, a generated background, hidden `.command` extension, and enough vertical space for Finder labels. The `Launch.command` helper should only remove quarantine from `/Applications/<App>.app` and open the app; treat it as a convenience for unsigned builds, not notarization.

## Verification

Run syntax checks for every shell script and build both artifacts before claiming the setup works. Inspect the generated appcast for the new version, zip URL, build number, and embedded release notes. Verify the DMG with `hdiutil verify` and mount it when layout was changed.

For detailed script responsibilities, release checks, and common pitfalls, read `references/release-architecture.md`.
