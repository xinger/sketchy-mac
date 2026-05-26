import Foundation

public struct ViewportTransform: Codable, Equatable, Sendable {
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double

    public init(scale: Double = 1, offsetX: Double = 0, offsetY: Double = 0) {
        self.scale = Self.clampScale(scale)
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    public func worldPoint(fromScreenPoint point: DrawingPoint) -> DrawingPoint {
        DrawingPoint(
            x: (point.x - offsetX) / scale,
            y: (point.y - offsetY) / scale
        )
    }

    public func screenPoint(fromWorldPoint point: DrawingPoint) -> DrawingPoint {
        DrawingPoint(
            x: point.x * scale + offsetX,
            y: point.y * scale + offsetY
        )
    }

    public func pannedBy(deltaX: Double, deltaY: Double) -> ViewportTransform {
        ViewportTransform(scale: scale, offsetX: offsetX - deltaX, offsetY: offsetY - deltaY)
    }

    public func zoomed(by factor: Double, aroundScreenPoint anchor: DrawingPoint) -> ViewportTransform {
        let worldAnchor = worldPoint(fromScreenPoint: anchor)
        let nextScale = Self.clampScale(scale * factor)

        return ViewportTransform(
            scale: nextScale,
            offsetX: anchor.x - worldAnchor.x * nextScale,
            offsetY: anchor.y - worldAnchor.y * nextScale
        )
    }

    private static func clampScale(_ scale: Double) -> Double {
        min(max(scale, 0.15), 8)
    }
}
