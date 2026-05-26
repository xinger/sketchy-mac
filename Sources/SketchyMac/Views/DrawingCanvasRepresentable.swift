import AppKit
import SwiftUI
import SketchyCore

struct DrawingCanvasRepresentable: NSViewRepresentable {
    var strokes: [DrawingStroke]
    var activeStrokeID: UUID?
    var onBegin: (DrawingPoint) -> Void
    var onAppend: (DrawingPoint) -> Void
    var onEnd: () -> Void

    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.onBegin = onBegin
        view.onAppend = onAppend
        view.onEnd = onEnd
        return view
    }

    func updateNSView(_ nsView: DrawingCanvasView, context: Context) {
        nsView.strokes = strokes
        nsView.activeStrokeID = activeStrokeID
        nsView.onBegin = onBegin
        nsView.onAppend = onAppend
        nsView.onEnd = onEnd
        nsView.needsDisplay = true
    }
}

final class DrawingCanvasView: NSView {
    var strokes: [DrawingStroke] = []
    var activeStrokeID: UUID?
    var onBegin: ((DrawingPoint) -> Void)?
    var onAppend: ((DrawingPoint) -> Void)?
    var onEnd: (() -> Void)?

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
        onBegin?(drawingPoint(from: event))
    }

    override func mouseDragged(with event: NSEvent) {
        onAppend?(drawingPoint(from: event))
    }

    override func mouseUp(with event: NSEvent) {
        onAppend?(drawingPoint(from: event))
        onEnd?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for stroke in strokes {
            draw(stroke: stroke, live: stroke.id == activeStrokeID)
        }
    }

    private func drawingPoint(from event: NSEvent) -> DrawingPoint {
        let location = convert(event.locationInWindow, from: nil)
        return DrawingPoint(x: Double(location.x), y: Double(location.y))
    }

    private func draw(stroke: DrawingStroke, live: Bool) {
        guard stroke.points.count > 0 else {
            return
        }

        let path = bezierPath(for: stroke.points, smooth: !live)
        path.lineWidth = CGFloat(stroke.width.lineWidth)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        if stroke.isDashed {
            var pattern = [CGFloat(stroke.width.lineWidth * 2), CGFloat(stroke.width.lineWidth * 2)]
            path.setLineDash(&pattern, count: pattern.count, phase: 0)
        }

        NSColor(sketchyColor: stroke.color).setStroke()
        path.stroke()
    }

    private func bezierPath(for points: [DrawingPoint], smooth: Bool) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else {
            return path
        }

        path.move(to: NSPoint(x: CGFloat(first.x), y: CGFloat(first.y)))

        guard points.count > 1 else {
            path.appendOval(
                in: NSRect(
                    x: CGFloat(first.x) - 1,
                    y: CGFloat(first.y) - 1,
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
                let end = NSPoint(
                    x: CGFloat((control.x + next.x) / 2),
                    y: CGFloat((control.y + next.y) / 2)
                )
                path.curve(
                    to: end,
                    controlPoint1: NSPoint(x: CGFloat(control.x), y: CGFloat(control.y)),
                    controlPoint2: NSPoint(x: CGFloat(control.x), y: CGFloat(control.y))
                )
            }

            if let last = points.last {
                path.line(to: NSPoint(x: CGFloat(last.x), y: CGFloat(last.y)))
            }
        } else {
            for point in points.dropFirst() {
                path.line(to: NSPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            }
        }

        return path
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
