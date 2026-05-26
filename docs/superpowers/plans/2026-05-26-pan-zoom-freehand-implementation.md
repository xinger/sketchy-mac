# Pan Zoom Freehand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pan/zoom to the canvas and render ordinary strokes with a live freehand outline algorithm.

**Architecture:** Add testable viewport and freehand rendering units to `SketchyCore`, then let the AppKit canvas own transient viewport input and convert events between screen and world coordinates. Keep dashed strokes on centerlines and ordinary strokes as filled SVG/NSBezierPath outlines.

**Tech Stack:** Swift 5.9, SwiftPM, AppKit `NSView`, XCTest.

---

## Tasks

- [ ] Add `ViewportTransform` core tests and implementation for screen/world conversion and cursor-anchored zoom.
- [ ] Add `FreehandStrokeRenderer` tests and implementation for filled outline paths that preserve the live last point.
- [ ] Update `SVGDocument` so ordinary strokes persist as filled outline paths while dashed strokes use centerline dash paths.
- [ ] Update `DrawingCanvasRepresentable` to support scroll panning, command/control scroll zoom, magnification gestures, and world-coordinate drawing.
- [ ] Run `swift test`, `swift build`, and `./script/build_and_run.sh --verify`.

## Self-Review

- Spec coverage: pan, zoom, cursor anchoring, live freehand, dashed centerline behavior, SVG persistence, and overlay behavior are covered.
- Placeholder scan: no TBD/TODO placeholders.
- Type consistency: plan uses `ViewportTransform`, `FreehandStrokeRenderer`, `SVGDocument`, and `DrawingCanvasRepresentable`.
