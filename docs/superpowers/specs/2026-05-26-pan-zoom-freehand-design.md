# Pan Zoom Freehand Design

## Goal

Add canvas pan and zoom, and replace the current "raw while drawing, smoothed
after mouse up" rendering with a live freehand-style algorithm inspired by the
`perfect-freehand` usage in `xinger/sketchy`.

## Reference

The Tauri/Vue `xinger/sketchy` app uses `paper` for canvas rendering and
`perfect-freehand` for ordinary freehand strokes. Its normal stroke path is a
filled outline generated from pointer points; dashed strokes remain centerline
paths with dash arrays.

## Interaction

- Scroll without a modifier pans the canvas.
- Command-scroll, control-scroll, or trackpad magnification zooms the canvas.
- Zoom is anchored at the cursor location so the focused point stays under the
  pointer.
- Drawing coordinates are stored in world/canvas space, not screen space.
- The bottom toolbar and history sidebar remain screen-space overlays and do not
  scale with the canvas.

## Rendering

Ordinary strokes render as a live filled outline. The outline width varies based
on local pointer speed, approximating `perfect-freehand` pressure/thinning
behavior without embedding JavaScript or a WebView. The live renderer keeps the
newest point present in the output, so handwriting does not lag behind the
cursor.

Dashed strokes remain stroked centerline paths with dash patterns because filled
outline dashes do not produce the expected dashed-pen look.

SVG persistence continues to store drawings as SVG. Ordinary strokes are saved
as filled paths; dashed strokes are saved as centerline paths with
`stroke-dasharray`.

## Testing

Core tests cover:

- screen-to-world and world-to-screen viewport transforms;
- cursor-anchored zoom;
- freehand outlines closing with `Z`;
- live freehand output retaining the newest point.
