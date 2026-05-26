# Sketchy Mac Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS 11+ SwiftUI drawing app with responsive smoothed handwriting, SVG autosave, hidden drawing history, a bottom floating toolbar, multi-window support, and a pin-above toggle.

**Architecture:** Use a SwiftPM GUI app. Keep the drawing and persistence core testable in a library target, then embed it in a SwiftUI executable target with narrow AppKit bridges for the canvas and window level. Store drawings as SVG files plus a JSON index in Application Support.

**Tech Stack:** Swift 5.9, SwiftPM, SwiftUI, AppKit, XCTest, SVG path/string encoding.

---

## File Structure

- `Package.swift`: SwiftPM package with `SketchyCore`, `SketchyMac`, and `SketchyCoreTests`.
- `Sources/SketchyCore/Models/DrawingModels.swift`: drawing ids, points, strokes, brush sizes, tool state, and color palette.
- `Sources/SketchyCore/Rendering/StrokeSmoother.swift`: live/final SVG path generation that keeps the live endpoint current.
- `Sources/SketchyCore/Rendering/SVGDocument.swift`: SVG encode/decode for full drawings.
- `Sources/SketchyCore/Persistence/DrawingLibraryStore.swift`: Application Support paths, JSON index, SVG loading/saving.
- `Sources/SketchyCore/Persistence/AutosaveScheduler.swift`: debounced autosave trigger.
- `Sources/SketchyMac/App/SketchyMacApp.swift`: SwiftUI app entrypoint, commands, app-level store.
- `Sources/SketchyMac/Views/SketchWindowView.swift`: root window composition and window-local state.
- `Sources/SketchyMac/Views/DrawingCanvasRepresentable.swift`: `NSViewRepresentable` bridge to a custom `NSView`.
- `Sources/SketchyMac/Views/BottomToolBarView.swift`: floating bottom pill toolbar.
- `Sources/SketchyMac/Views/HistorySidebarView.swift`: hidden/revealed thumbnail list.
- `Sources/SketchyMac/Support/WindowAccessor.swift`: tiny AppKit bridge for `NSWindow.level`.
- `script/build_and_run.sh`: build, bundle, and launch the SwiftPM GUI app.
- `.codex/environments/environment.toml`: Codex Run action.
- `Tests/SketchyCoreTests/StrokeSmootherTests.swift`: smoothing and endpoint tests.
- `Tests/SketchyCoreTests/SVGDocumentTests.swift`: SVG encoding tests.
- `Tests/SketchyCoreTests/DrawingLibraryStoreTests.swift`: persistence tests.
- `Tests/SketchyCoreTests/AutosaveSchedulerTests.swift`: debounce tests.

## Task 1: SwiftPM Skeleton And Core Models

**Files:**
- Create: `Package.swift`
- Create: `Sources/SketchyCore/Models/DrawingModels.swift`
- Test: `Tests/SketchyCoreTests/StrokeSmootherTests.swift`

- [ ] **Step 1: Write the first failing test**

```swift
import XCTest
@testable import SketchyCore

final class StrokeSmootherTests: XCTestCase {
    func testLivePathKeepsLastPointAsEndpoint() {
        let stroke = DrawingStroke(
            points: [
                DrawingPoint(x: 10, y: 10),
                DrawingPoint(x: 20, y: 20),
                DrawingPoint(x: 40, y: 18),
                DrawingPoint(x: 80, y: 30)
            ],
            color: .paletteRed,
            width: .medium,
            isDashed: false
        )

        let path = StrokeSmoother.livePath(for: stroke)

        XCTAssertTrue(path.hasSuffix("L 80.00 30.00"))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter StrokeSmootherTests/testLivePathKeepsLastPointAsEndpoint`

Expected: FAIL because `Package.swift` or `SketchyCore` symbols do not exist yet.

- [ ] **Step 3: Add the minimal package and model implementation**

Create `Package.swift` with a macOS 11 platform, `SketchyCore` library target,
`SketchyMac` executable target, and `SketchyCoreTests` test target. Create the
model types and a minimal `StrokeSmoother.livePath(for:)` implementation that
formats `M` and `L` SVG commands to two decimals.

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter StrokeSmootherTests/testLivePathKeepsLastPointAsEndpoint`

Expected: PASS.

- [ ] **Step 5: Commit**

Run: `git add Package.swift Sources/SketchyCore Tests/SketchyCoreTests && git commit -m "Add SwiftPM core drawing model"`

## Task 2: SVG Rendering And Persistence Core

**Files:**
- Modify: `Sources/SketchyCore/Rendering/StrokeSmoother.swift`
- Create: `Sources/SketchyCore/Rendering/SVGDocument.swift`
- Create: `Sources/SketchyCore/Persistence/DrawingLibraryStore.swift`
- Test: `Tests/SketchyCoreTests/SVGDocumentTests.swift`
- Test: `Tests/SketchyCoreTests/DrawingLibraryStoreTests.swift`

- [ ] **Step 1: Write SVG document tests**

```swift
import XCTest
@testable import SketchyCore

final class SVGDocumentTests: XCTestCase {
    func testSVGDocumentContainsStrokeAttributes() {
        let drawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!),
            updatedAt: Date(timeIntervalSince1970: 0),
            strokes: [
                DrawingStroke(
                    points: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 12, y: 8)],
                    color: .paletteBlue,
                    width: .large,
                    isDashed: true
                )
            ]
        )

        let svg = SVGDocument.encode(drawing: drawing, canvasSize: CanvasSize(width: 800, height: 600))

        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("viewBox=\"0 0 800 600\""))
        XCTAssertTrue(svg.contains("stroke=\"#2D7DD2\""))
        XCTAssertTrue(svg.contains("stroke-width=\"6\""))
        XCTAssertTrue(svg.contains("stroke-dasharray=\"12 12\""))
    }
}
```

- [ ] **Step 2: Run SVG tests and verify failure**

Run: `swift test --filter SVGDocumentTests/testSVGDocumentContainsStrokeAttributes`

Expected: FAIL because `SVGDocument` and `CanvasSize` do not exist.

- [ ] **Step 3: Implement SVG encoding**

Add `CanvasSize`, escaped SVG helpers, final path generation, and SVG document
encoding. Final paths use smoothed quadratic commands for stable interior points
and line commands for short strokes.

- [ ] **Step 4: Run SVG tests and verify pass**

Run: `swift test --filter SVGDocumentTests/testSVGDocumentContainsStrokeAttributes`

Expected: PASS.

- [ ] **Step 5: Write persistence tests**

```swift
import XCTest
@testable import SketchyCore

final class DrawingLibraryStoreTests: XCTestCase {
    func testSaveAndReloadDrawingRoundTripsIndexAndSVG() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DrawingLibraryStore(rootDirectory: root)
        let drawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!),
            updatedAt: Date(timeIntervalSince1970: 10),
            strokes: [
                DrawingStroke(
                    points: [DrawingPoint(x: 1, y: 2), DrawingPoint(x: 3, y: 4)],
                    color: .paletteTeal,
                    width: .small,
                    isDashed: false
                )
            ]
        )

        try store.save(drawing: drawing, canvasSize: CanvasSize(width: 320, height: 240))

        let summaries = try store.loadIndex()
        XCTAssertEqual(summaries.map(\.id), [drawing.id])
        let svg = try String(contentsOf: store.svgURL(for: drawing.id), encoding: .utf8)
        XCTAssertTrue(svg.contains("#19C8BE"))
    }
}
```

- [ ] **Step 6: Run persistence tests and verify failure**

Run: `swift test --filter DrawingLibraryStoreTests/testSaveAndReloadDrawingRoundTripsIndexAndSVG`

Expected: FAIL because `DrawingLibraryStore` does not exist.

- [ ] **Step 7: Implement persistence store**

Create the root directory, save SVG files as `<uuid>.svg`, and save/load an
`index.json` containing `DrawingSummary` values sorted by update time.

- [ ] **Step 8: Run focused and full tests**

Run: `swift test`

Expected: all tests PASS.

- [ ] **Step 9: Commit**

Run: `git add Sources/SketchyCore Tests/SketchyCoreTests && git commit -m "Add SVG persistence core"`

## Task 3: Autosave Scheduler

**Files:**
- Create: `Sources/SketchyCore/Persistence/AutosaveScheduler.swift`
- Test: `Tests/SketchyCoreTests/AutosaveSchedulerTests.swift`

- [ ] **Step 1: Write debounce test**

```swift
import XCTest
@testable import SketchyCore

final class AutosaveSchedulerTests: XCTestCase {
    func testDebounceCoalescesRapidChanges() {
        let scheduler = AutosaveScheduler(interval: 0.2)
        var fireCount = 0

        scheduler.schedule { fireCount += 1 }
        scheduler.schedule { fireCount += 1 }
        scheduler.flush()

        XCTAssertEqual(fireCount, 1)
    }
}
```

- [ ] **Step 2: Run test and verify failure**

Run: `swift test --filter AutosaveSchedulerTests/testDebounceCoalescesRapidChanges`

Expected: FAIL because `AutosaveScheduler` does not exist.

- [ ] **Step 3: Implement scheduler**

Use `DispatchWorkItem` to cancel pending saves before scheduling a new one, and
provide `flush()` for immediate save on window/drawing switches.

- [ ] **Step 4: Run tests**

Run: `swift test`

Expected: all tests PASS.

- [ ] **Step 5: Commit**

Run: `git add Sources/SketchyCore/Persistence/AutosaveScheduler.swift Tests/SketchyCoreTests/AutosaveSchedulerTests.swift && git commit -m "Add autosave scheduler"`

## Task 4: SwiftUI App Shell, Canvas, Toolbar, And Sidebar

**Files:**
- Create: `Sources/SketchyMac/App/SketchyMacApp.swift`
- Create: `Sources/SketchyMac/Views/SketchWindowView.swift`
- Create: `Sources/SketchyMac/Views/DrawingCanvasRepresentable.swift`
- Create: `Sources/SketchyMac/Views/BottomToolBarView.swift`
- Create: `Sources/SketchyMac/Views/HistorySidebarView.swift`
- Create: `Sources/SketchyMac/Support/WindowAccessor.swift`

- [ ] **Step 1: Add executable app entrypoint**

Create `SketchyMacApp` with `WindowGroup`, a shared `DrawingLibraryStore`, and
commands for new window and new drawing.

- [ ] **Step 2: Implement root window**

Create `SketchWindowView` with a full-window adaptive canvas, a hidden left
history sidebar, a bottom floating pill toolbar, and window-local tool state.

- [ ] **Step 3: Implement AppKit canvas bridge**

Create an `NSViewRepresentable` that wraps a custom `NSView`, captures mouse
down/drag/up, appends `DrawingPoint` values to the active stroke, and calls back
into SwiftUI. Render finalized strokes through `SVGDocument`/`StrokeSmoother`
path logic and render the active stroke with live endpoint preservation.

- [ ] **Step 4: Implement bottom toolbar**

Expose three brush size dots, a dashed toggle, six color swatches, a sidebar
button, a new drawing button, and a pin toggle. Keep it bottom-centered and
usable in light/dark mode.

- [ ] **Step 5: Implement sidebar**

Show drawing thumbnails from the JSON index, reveal via button, and reveal after
a delayed hover near the left window edge.

- [ ] **Step 6: Implement window pin bridge**

Use `WindowAccessor` to capture the hosting `NSWindow` and set `.level` to
`.floating` when pinned and `.normal` otherwise.

- [ ] **Step 7: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 8: Commit**

Run: `git add Sources/SketchyMac && git commit -m "Add SwiftUI drawing app shell"`

## Task 5: Run Script, Codex Run Button, And Manual Verification

**Files:**
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`
- Modify: `Sources/SketchyMac/App/SketchyMacApp.swift` if launch activation needs adjustment.

- [ ] **Step 1: Add build/run script**

Create a script that kills an existing `SketchyMac` process, runs `swift build`,
stages `dist/SketchyMac.app`, writes `Info.plist` with macOS 11 minimum, and
launches the bundle with `/usr/bin/open -n`.

- [ ] **Step 2: Add Codex Run action**

Point `.codex/environments/environment.toml` at `./script/build_and_run.sh`.

- [ ] **Step 3: Verify build and launch**

Run: `./script/build_and_run.sh --verify`

Expected: build succeeds and `pgrep -x SketchyMac` finds the launched app.

- [ ] **Step 4: Verify full test suite**

Run: `swift test`

Expected: all tests PASS.

- [ ] **Step 5: Commit**

Run: `git add script/build_and_run.sh .codex/environments/environment.toml Sources/SketchyMac && git commit -m "Add SketchyMac run workflow"`

## Self-Review

- Spec coverage: bottom toolbar, hidden history sidebar, smooth live drawing,
  SVG persistence, autosave, light/dark adaptive colors, multi-window support,
  and pin-above behavior are all mapped to tasks.
- Placeholder scan: no TBD/TODO/fill-in-later placeholders remain.
- Type consistency: plan uses `DrawingID`, `DrawingPoint`, `DrawingStroke`,
  `Drawing`, `CanvasSize`, `StrokeSmoother`, `SVGDocument`,
  `DrawingLibraryStore`, and `AutosaveScheduler` consistently across tasks.
