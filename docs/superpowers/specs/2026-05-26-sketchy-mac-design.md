# Sketchy Mac Design

## Goal

Build a fast native macOS drawing app for quick handwritten notes and sketches.
The app should feel immediate enough for writing words, preserve old drawings
automatically, and keep the main canvas visually quiet.

## Platform

- SwiftUI macOS app with the lowest practical modern SwiftUI deployment target:
  macOS 11.
- SwiftPM GUI app structure.
- Use AppKit only for narrow macOS behaviors SwiftUI cannot express cleanly,
  especially direct drawing input and window level control.

## Core Experience

The main window is a large adaptive drawing canvas. A compact floating toolbar
sits near the bottom center of the canvas, matching the provided screenshot:
a low, rounded pill with brush size dots, a dashed toggle, and color swatches.
The toolbar must not cover most drawing space and should remain usable in both
light and dark appearance.

The sidebar with previous drawings is hidden by default. It appears either when
the user clicks a sidebar button or after a long hover near the left edge. It
shows compact thumbnails of past drawings and lets the user switch quickly
between them.

Multiple windows are supported. Each window can display its own drawing state,
and users can create more than one drawing window.

## Drawing Model

Drawing input is captured in a custom AppKit-backed canvas embedded in SwiftUI.
This keeps pointer sampling, pressure-independent mouse drawing, and redraw
timing under direct control on macOS 11.

The smoothing algorithm must not wait for future points before showing the end
of the line. While a stroke is active, the newest segment is rendered immediately
from current points so handwriting stays responsive. Older stable segments can
be smoothed into quadratic or cubic curve commands once enough neighboring
points exist. When the stroke ends, the full stroke is finalized into SVG path
data.

This gives smooth lines without the delayed trailing point that makes written
words feel mushy.

## Tools

- Three brush sizes: small, medium, large.
- Dashed mode toggle.
- Six color swatches.
- The current tool state is window-local while drawing.
- Tool choices should be exposed through the bottom floating toolbar and can be
  mirrored later in menu commands if needed.

## Persistence

Drawings are stored as SVG files in the app's Application Support directory.
Each drawing has an id, title or timestamp label, updated date, and SVG path
content. A small JSON index stores drawing metadata for the sidebar.

Autosave runs after drawing changes with a short debounce and also when the user
switches drawings or the app/window is closing. The SVG is the source of truth
for persisted drawings.

## Window Behavior

The app uses `WindowGroup` so users can create multiple windows. A window-level
toggle pins the current window above normal app windows. The implementation uses
a tiny SwiftUI-to-AppKit bridge to access the hosting `NSWindow` and switch its
level between normal and floating.

The app should use normal macOS window chrome and adaptive system colors. It
does not rely on macOS 15-only window modifiers.

## Architecture

- `App/`: SwiftUI app entry point and app-level commands.
- `Models/`: drawing ids, drawings, strokes, brush sizes, colors, tool state.
- `Stores/`: drawing library, SVG persistence, autosave scheduling.
- `Views/`: root window, canvas host, sidebar, thumbnail rows, bottom toolbar.
- `Support/`: AppKit bridges, SVG encoding/decoding helpers, geometry helpers.
- `script/build_and_run.sh`: project-local build and launch entrypoint.
- `.codex/environments/environment.toml`: Codex app Run action.

SwiftUI owns app and window state. AppKit bridges expose narrow callbacks and
bindings back into SwiftUI rather than duplicating state.

## Testing

Focused automated tests should cover:

- SVG path generation for normal and dashed strokes.
- Smoothing behavior that keeps the live stroke endpoint current.
- SVG document encoding and metadata index persistence.
- Autosave debounce logic where practical.

Manual verification should cover:

- Build and launch through `./script/build_and_run.sh`.
- Drawing responsiveness while writing words.
- Light and dark appearance.
- Sidebar reveal by button and long hover.
- Multiple windows.
- Pin window above other windows.
