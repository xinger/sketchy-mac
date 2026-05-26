import Foundation

public enum FreehandStrokeRenderer {
    public static func outlinePoints(for stroke: DrawingStroke) -> [DrawingPoint] {
        outlinePoints(points: stroke.points, baseWidth: stroke.width.lineWidth)
    }

    public static func outlinePath(for stroke: DrawingStroke) -> String {
        svgPath(from: outlinePoints(for: stroke), close: true)
    }

    public static func svgPath(from points: [DrawingPoint], close: Bool) -> String {
        guard let first = points.first else {
            return ""
        }

        guard points.count > 1 else {
            return "M \(format(first.x)) \(format(first.y))"
        }

        var commands = ["M \(format(first.x)) \(format(first.y))"]

        if points.count > 3 {
            for index in 1..<(points.count - 1) {
                let control = points[index]
                let next = points[index + 1]
                let end = midpoint(control, next)
                commands.append(
                    "Q \(format(control.x)) \(format(control.y)) \(format(end.x)) \(format(end.y))"
                )
            }
        } else {
            for point in points.dropFirst() {
                commands.append("L \(format(point.x)) \(format(point.y))")
            }
        }

        if let last = points.last {
            commands.append("L \(format(last.x)) \(format(last.y))")
        }

        if close {
            commands.append("Z")
        }

        return commands.joined(separator: " ")
    }

    private static func outlinePoints(points rawPoints: [DrawingPoint], baseWidth: Double) -> [DrawingPoint] {
        let points = streamlined(rawPoints, amount: 0.45)

        guard points.count > 1 else {
            guard let point = points.first else {
                return []
            }

            let radius = baseWidth / 2
            return [
                DrawingPoint(x: point.x - radius, y: point.y),
                DrawingPoint(x: point.x, y: point.y - radius),
                DrawingPoint(x: point.x + radius, y: point.y),
                DrawingPoint(x: point.x, y: point.y + radius)
            ]
        }

        var left: [DrawingPoint] = []
        var right: [DrawingPoint] = []
        var previousSpeed = 0.0

        for index in points.indices {
            let current = points[index]
            let previous = points[max(points.startIndex, index - 1)]
            let next = points[min(points.index(before: points.endIndex), index + 1)]
            let direction = normalized(
                DrawingPoint(
                    x: next.x - previous.x,
                    y: next.y - previous.y
                )
            )
            let normal = DrawingPoint(x: -direction.y, y: direction.x)
            let distance = hypot(current.x - previous.x, current.y - previous.y)
            let speed = previousSpeed * 0.6 + distance * 0.4
            previousSpeed = speed

            let pressure = max(0.35, min(1.0, 1.0 - speed / 80.0))
            let radius = baseWidth * (0.35 + pressure * 0.4)

            left.append(
                DrawingPoint(
                    x: current.x + normal.x * radius,
                    y: current.y + normal.y * radius
                )
            )
            right.append(
                DrawingPoint(
                    x: current.x - normal.x * radius,
                    y: current.y - normal.y * radius
                )
            )
        }

        // Keep the newest point represented exactly so live drawing never feels
        // like it is waiting for future samples.
        if let last = points.last {
            left.append(last)
        }

        return left + right.reversed()
    }

    private static func streamlined(_ points: [DrawingPoint], amount: Double) -> [DrawingPoint] {
        guard points.count > 2 else {
            return points
        }

        var result = [points[0]]
        var previous = points[0]
        let follow = min(max(amount, 0), 0.95)

        for point in points.dropFirst().dropLast() {
            let next = DrawingPoint(
                x: previous.x + (point.x - previous.x) * (1 - follow),
                y: previous.y + (point.y - previous.y) * (1 - follow)
            )
            result.append(next)
            previous = next
        }

        if let last = points.last {
            result.append(last)
        }

        return result
    }

    private static func normalized(_ point: DrawingPoint) -> DrawingPoint {
        let length = hypot(point.x, point.y)
        guard length > 0 else {
            return DrawingPoint(x: 1, y: 0)
        }

        return DrawingPoint(x: point.x / length, y: point.y / length)
    }

    private static func midpoint(_ first: DrawingPoint, _ second: DrawingPoint) -> DrawingPoint {
        DrawingPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
