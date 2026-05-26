import AppKit
import SwiftUI
import SketchyCore

struct DrawingCanvasRepresentable: NSViewRepresentable {
    var images: [DrawingImage]
    var strokes: [DrawingStroke]
    var activeStrokeID: UUID?
    @Binding var viewport: ViewportTransform
    var onBegin: (DrawingPoint) -> Void
    var onAppend: (DrawingPoint) -> Void
    var onEnd: () -> Void
    var onInsertImage: (DrawingImage) -> Void
    var onCanvasMouseDown: () -> Void

    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.onBegin = onBegin
        view.onAppend = onAppend
        view.onEnd = onEnd
        view.onInsertImage = onInsertImage
        view.onCanvasMouseDown = onCanvasMouseDown
        view.onViewportChange = { viewport = $0 }
        return view
    }

    func updateNSView(_ nsView: DrawingCanvasView, context: Context) {
        nsView.images = images
        nsView.strokes = strokes
        nsView.activeStrokeID = activeStrokeID
        nsView.viewport = viewport
        nsView.onBegin = onBegin
        nsView.onAppend = onAppend
        nsView.onEnd = onEnd
        nsView.onInsertImage = onInsertImage
        nsView.onCanvasMouseDown = onCanvasMouseDown
        nsView.onViewportChange = { viewport = $0 }
        nsView.needsDisplay = true
    }
}

final class DrawingCanvasView: NSView {
    var images: [DrawingImage] = [] {
        didSet {
            let imageIDs = Set(images.map(\.id))
            renderedImageCache = renderedImageCache.filter { imageIDs.contains($0.key) }
        }
    }
    var strokes: [DrawingStroke] = []
    var activeStrokeID: UUID?
    var viewport = ViewportTransform()
    var onBegin: ((DrawingPoint) -> Void)?
    var onAppend: ((DrawingPoint) -> Void)?
    var onEnd: (() -> Void)?
    var onInsertImage: ((DrawingImage) -> Void)?
    var onCanvasMouseDown: (() -> Void)?
    var onViewportChange: ((ViewportTransform) -> Void)?
    private var renderedImageCache: [UUID: NSImage] = [:]

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        registerImageDraggingTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        registerImageDraggingTypes()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onCanvasMouseDown?()
        onBegin?(worldPoint(from: event))
    }

    override func mouseDragged(with event: NSEvent) {
        onAppend?(worldPoint(from: event))
    }

    override func mouseUp(with event: NSEvent) {
        onAppend?(worldPoint(from: event))
        onEnd?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        imagePayload(from: sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        insertImage(from: sender.draggingPasteboard)
    }

    @objc func paste(_ sender: Any?) {
        if !insertImage(from: .general) {
            nextResponder?.tryToPerform(#selector(paste(_:)), with: sender)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .keyDown,
           modifiers.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            return insertImage(from: .general) || super.performKeyEquivalent(with: event)
        }

        return super.performKeyEquivalent(with: event)
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

        for image in images {
            draw(image: image)
        }

        for stroke in strokes {
            draw(stroke: stroke, live: stroke.id == activeStrokeID)
        }
    }

    private func registerImageDraggingTypes() {
        registerForDraggedTypes([.fileURL, .tiff, .pngImage, .jpegImage])
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

    private func insertImage(from pasteboard: NSPasteboard) -> Bool {
        guard let payload = imagePayload(from: pasteboard) else {
            return false
        }

        let frame = DrawingImagePlacement.centeredFrame(
            imageSize: payload.size,
            viewport: viewport,
            canvasSize: CanvasSize(width: Double(bounds.width), height: Double(bounds.height))
        )
        onInsertImage?(
            DrawingImage(
                data: payload.data,
                mimeType: payload.mimeType,
                frame: frame
            )
        )
        return true
    }

    private func imagePayload(from pasteboard: NSPasteboard) -> ImagePayload? {
        if let payload = imagePayloadFromFileURL(in: pasteboard) {
            return payload
        }

        if let data = pasteboard.data(forType: .pngImage),
           let image = NSImage(data: data) {
            return ImagePayload(data: data, mimeType: "image/png", size: pixelSize(for: image))
        }

        if let data = pasteboard.data(forType: .jpegImage),
           let image = NSImage(data: data) {
            return ImagePayload(data: data, mimeType: "image/jpeg", size: pixelSize(for: image))
        }

        if let data = pasteboard.data(forType: .tiff),
           let image = NSImage(data: data) {
            return pngPayload(from: image)
        }

        return nil
    }

    private func imagePayloadFromFileURL(in pasteboard: NSPasteboard) -> ImagePayload? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL]
        guard
            let url = urls?.first as URL?,
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        if let mimeType = supportedRasterMimeType(for: url),
           let data = try? Data(contentsOf: url) {
            return ImagePayload(data: data, mimeType: mimeType, size: pixelSize(for: image))
        }

        return pngPayload(from: image)
    }

    private func supportedRasterMimeType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        default:
            return nil
        }
    }

    private func pngPayload(from image: NSImage) -> ImagePayload? {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            return nil
        }

        return ImagePayload(data: pngData, mimeType: "image/png", size: pixelSize(for: image))
    }

    private func pixelSize(for image: NSImage) -> CanvasSize {
        let bitmapRepresentations = image.representations.compactMap { $0 as? NSBitmapImageRep }
        if let representation = bitmapRepresentations.first,
           representation.pixelsWide > 0,
           representation.pixelsHigh > 0 {
            return CanvasSize(
                width: Double(representation.pixelsWide),
                height: Double(representation.pixelsHigh)
            )
        }

        return CanvasSize(width: max(Double(image.size.width), 1), height: max(Double(image.size.height), 1))
    }

    private func draw(image drawingImage: DrawingImage) {
        guard let image = renderedImage(for: drawingImage) else {
            return
        }

        let origin = viewport.screenPoint(
            fromWorldPoint: DrawingPoint(
                x: drawingImage.frame.x,
                y: drawingImage.frame.y
            )
        )
        let rect = NSRect(
            x: CGFloat(origin.x),
            y: CGFloat(origin.y),
            width: CGFloat(drawingImage.frame.width * viewport.scale),
            height: CGFloat(drawingImage.frame.height * viewport.scale)
        )
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    private func renderedImage(for drawingImage: DrawingImage) -> NSImage? {
        if let cachedImage = renderedImageCache[drawingImage.id] {
            return cachedImage
        }

        guard let image = NSImage(data: drawingImage.data) else {
            return nil
        }

        renderedImageCache[drawingImage.id] = image
        return image
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

private struct ImagePayload {
    var data: Data
    var mimeType: String
    var size: CanvasSize
}

private extension NSPasteboard.PasteboardType {
    static let pngImage = NSPasteboard.PasteboardType("public.png")
    static let jpegImage = NSPasteboard.PasteboardType("public.jpeg")
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
