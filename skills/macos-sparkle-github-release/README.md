# macOS Sparkle GitHub Release Skill

Codex skill for adding a macOS distribution flow with Sparkle auto-updates,
GitHub Pages appcast hosting, GitHub Releases asset publishing, release notes,
and a custom DMG installer.

## Install

Copy this directory into your Codex skills folder:

```bash
mkdir -p ~/.codex/skills
cp -R macos-sparkle-github-release ~/.codex/skills/
```

Restart Codex or open a new chat so the skill list refreshes.

## Use

In a macOS app project, ask Codex:

```text
Use $macos-sparkle-github-release to add Sparkle updates, GitHub release publishing, and a custom DMG installer to this macOS app.
```

## Contents

- `SKILL.md` is the main skill entry point.
- `references/release-architecture.md` contains detailed implementation notes,
  verification commands, and common pitfalls.
- `agents/openai.yaml` provides Codex UI metadata.
