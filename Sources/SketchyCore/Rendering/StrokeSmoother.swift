import Foundation

public enum StrokeSmoother {
    public static func livePath(for stroke: DrawingStroke) -> String {
        path(points: stroke.points, smoothInterior: false)
    }

    public static func finalPath(for stroke: DrawingStroke) -> String {
        path(points: stroke.points, smoothInterior: true)
    }

    private static func path(points: [DrawingPoint], smoothInterior: Bool) -> String {
        guard let first = points.first else {
            return ""
        }

        guard points.count > 1 else {
            return "M \(format(first.x)) \(format(first.y))"
        }

        var commands = ["M \(format(first.x)) \(format(first.y))"]

        for point in points.dropFirst() {
            commands.append("L \(format(point.x)) \(format(point.y))")
        }

        return commands.joined(separator: " ")
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
