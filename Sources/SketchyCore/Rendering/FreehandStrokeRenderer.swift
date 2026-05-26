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
        guard rawPoints.count > 1 else {
            guard let point = rawPoints.first else {
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
        var directions: [DrawingPoint] = []
        var radii: [Double] = []
        var previousSpeed = 0.0

        for index in rawPoints.indices {
            let current = rawPoints[index]
            let previous = rawPoints[max(rawPoints.startIndex, index - 1)]
            let next = rawPoints[min(rawPoints.index(before: rawPoints.endIndex), index + 1)]
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
            directions.append(direction)
            radii.append(radius)

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

        guard
            let first = rawPoints.first,
            let last = rawPoints.last,
            let firstDirection = directions.first,
            let lastDirection = directions.last,
            let firstRadius = radii.first,
            let lastRadius = radii.last
        else {
            return left + right.reversed()
        }

        let startCap = capPoints(
            center: first,
            direction: DrawingPoint(x: -firstDirection.x, y: -firstDirection.y),
            radius: firstRadius,
            fromLeftToRight: true
        )
        let endCap = capPoints(
            center: last,
            direction: lastDirection,
            radius: lastRadius,
            fromLeftToRight: true
        )

        return left + endCap.dropFirst() + right.dropLast().reversed() + startCap.dropFirst()
    }

    private static func capPoints(
        center: DrawingPoint,
        direction: DrawingPoint,
        radius: Double,
        fromLeftToRight: Bool
    ) -> [DrawingPoint] {
        let normal = DrawingPoint(x: -direction.y, y: direction.x)
        let angles: [Double] = fromLeftToRight ? [0, 0.25, 0.5, 0.75, 1] : [1, 0.75, 0.5, 0.25, 0]

        return angles.map { progress in
            let theta = Double.pi * progress
            let forward = sin(theta)
            let sideways = cos(theta)

            return DrawingPoint(
                x: center.x + direction.x * radius * forward + normal.x * radius * sideways,
                y: center.y + direction.y * radius * forward + normal.y * radius * sideways
            )
        }
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
