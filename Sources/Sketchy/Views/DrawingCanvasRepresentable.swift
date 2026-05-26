import AppKit
import SwiftUI
import SketchyCore

struct DrawingCanvasRepresentable: NSViewRepresentable {
    var strokes: [DrawingStroke]
    var activeStrokeID: UUID?
    @Binding var viewport: ViewportTransform
    var onBegin: (DrawingPoint) -> Void
    var onAppend: (DrawingPoint) -> Void
    var onEnd: () -> Void

    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.onBegin = onBegin
        view.onAppend = onAppend
        view.onEnd = onEnd
        view.onViewportChange = { viewport = $0 }
        return view
    }

    func updateNSView(_ nsView: DrawingCanvasView, context: Context) {
        nsView.strokes = strokes
        nsView.activeStrokeID = activeStrokeID
        nsView.viewport = viewport
        nsView.onBegin = onBegin
        nsView.onAppend = onAppend
        nsView.onEnd = onEnd
        nsView.onViewportChange = { viewport = $0 }
        nsView.needsDisplay = true
    }
}

final class DrawingCanvasView: NSView {
    var strokes: [DrawingStroke] = []
    var activeStrokeID: UUID?
    var viewport = ViewportTransform()
    var onBegin: ((DrawingPoint) -> Void)?
    var onAppend: ((DrawingPoint) -> Void)?
    var onEnd: (() -> Void)?
    var onViewportChange: ((ViewportTransform) -> Void)?

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onBegin?(worldPoint(from: event))
    }

    override func mouseDragged(with event: NSEvent) {
        onAppend?(worldPoint(from: event))
    }

    override func mouseUp(with event: NSEvent) {
        onAppend?(worldPoint(from: event))
        onEnd?()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            let factor = exp(-Double(event.scrollingDeltaY) / 80)
            updateViewport(
                viewport.zoomed(by: factor, aroundScreenPoint: screenPoint(from: event))
            )
        } else {
            updateViewport(
                viewport.pannedByScrollDelta(
                    deltaX: Double(event.scrollingDeltaX),
                    deltaY: Double(event.scrollingDeltaY),
                    isDirectionInvertedFromDevice: event.isDirectionInvertedFromDevice
                )
            )
        }
    }

    override func magnify(with event: NSEvent) {
        let factor = max(0.1, 1 + Double(event.magnification))
        let location = convert(event.locationInWindow, from: nil)
        updateViewport(
            viewport.zoomed(
                by: factor,
                aroundScreenPoint: DrawingPoint(x: Double(location.x), y: Double(location.y))
            )
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for stroke in strokes {
            draw(stroke: stroke, live: stroke.id == activeStrokeID)
        }
    }

    private func screenPoint(from event: NSEvent) -> DrawingPoint {
        let location = convert(event.locationInWindow, from: nil)
        return DrawingPoint(x: Double(location.x), y: Double(location.y))
    }

    private func worldPoint(from event: NSEvent) -> DrawingPoint {
        viewport.worldPoint(fromScreenPoint: screenPoint(from: event))
    }

    private func updateViewport(_ nextViewport: ViewportTransform) {
        viewport = nextViewport
        onViewportChange?(nextViewport)
        needsDisplay = true
    }

    private func draw(stroke: DrawingStroke, live: Bool) {
        guard stroke.points.count > 0 else {
            return
        }

        if stroke.isDashed {
            let path = centerlinePath(for: stroke.points, smooth: !live)
            path.lineWidth = CGFloat(stroke.width.lineWidth * viewport.scale)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            let dash = CGFloat(stroke.width.lineWidth * 2 * viewport.scale)
            var pattern = [dash, dash]
            path.setLineDash(&pattern, count: pattern.count, phase: 0)
            NSColor(sketchyColor: stroke.color).setStroke()
            path.stroke()
        } else {
            let outline = FreehandStrokeRenderer.outlinePoints(for: stroke)
                .map(viewport.screenPoint(fromWorldPoint:))
            let path = outlinePath(for: outline)
            NSColor(sketchyColor: stroke.color).setFill()
            path.fill()
        }
    }

    private func centerlinePath(for points: [DrawingPoint], smooth: Bool) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else {
            return path
        }

        let firstScreenPoint = viewport.screenPoint(fromWorldPoint: first)
        path.move(to: nsPoint(firstScreenPoint))

        guard points.count > 1 else {
            path.appendOval(
                in: NSRect(
                    x: CGFloat(firstScreenPoint.x) - 1,
                    y: CGFloat(firstScreenPoint.y) - 1,
                    width: 2,
                    height: 2
                )
            )
            return path
        }

        if smooth, points.count > 3 {
            for index in 1..<(points.count - 1) {
                let control = points[index]
                let next = points[index + 1]
                let end = viewport.screenPoint(
                    fromWorldPoint: DrawingPoint(
                        x: (control.x + next.x) / 2,
                        y: (control.y + next.y) / 2
                    )
                )
                let controlScreenPoint = viewport.screenPoint(fromWorldPoint: control)
                path.curve(
                    to: nsPoint(end),
                    controlPoint1: nsPoint(controlScreenPoint),
                    controlPoint2: nsPoint(controlScreenPoint)
                )
            }

            if let last = points.last {
                path.line(to: nsPoint(viewport.screenPoint(fromWorldPoint: last)))
            }
        } else {
            for point in points.dropFirst() {
                path.line(to: nsPoint(viewport.screenPoint(fromWorldPoint: point)))
            }
        }

        return path
    }

    private func outlinePath(for points: [DrawingPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else {
            return path
        }

        path.move(to: nsPoint(first))

        if points.count > 3 {
            for index in 1..<(points.count - 1) {
                let control = points[index]
                let next = points[index + 1]
                let end = DrawingPoint(
                    x: (control.x + next.x) / 2,
                    y: (control.y + next.y) / 2
                )
                path.curve(
                    to: nsPoint(end),
                    controlPoint1: nsPoint(control),
                    controlPoint2: nsPoint(control)
                )
            }
        } else {
            for point in points.dropFirst() {
                path.line(to: nsPoint(point))
            }
        }

        if let last = points.last {
            path.line(to: nsPoint(last))
        }

        path.close()
        return path
    }

    private func nsPoint(_ point: DrawingPoint) -> NSPoint {
        NSPoint(x: CGFloat(point.x), y: CGFloat(point.y))
    }
}

private extension NSColor {
    convenience init(sketchyColor: DrawingColor) {
        let hex = sketchyColor.hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255

        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
