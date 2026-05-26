import Foundation

public enum StrokeSmoother {
    public static func livePath(for stroke: DrawingStroke) -> String {
        path(points: stroke.points, smoothInterior: false)
    }

    public static func finalPath(for stroke: DrawingStroke) -> String {
        path(points: stroke.points, smoothInterior: stroke.points.count > 3)
    }

    private static func path(points: [DrawingPoint], smoothInterior: Bool) -> String {
        guard let first = points.first else {
            return ""
        }

        guard points.count > 1 else {
            return "M \(format(first.x)) \(format(first.y))"
        }

        var commands = ["M \(format(first.x)) \(format(first.y))"]

        if smoothInterior {
            for index in 1..<(points.count - 1) {
                let control = points[index]
                let next = points[index + 1]
                let end = midpoint(control, next)
                commands.append(
                    "Q \(format(control.x)) \(format(control.y)) \(format(end.x)) \(format(end.y))"
                )
            }

            if let last = points.last {
                commands.append("L \(format(last.x)) \(format(last.y))")
            }

            return commands.joined(separator: " ")
        }

        for point in points.dropFirst() {
            commands.append("L \(format(point.x)) \(format(point.y))")
        }

        return commands.joined(separator: " ")
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func midpoint(_ first: DrawingPoint, _ second: DrawingPoint) -> DrawingPoint {
        DrawingPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}
