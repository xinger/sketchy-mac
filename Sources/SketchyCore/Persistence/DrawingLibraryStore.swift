import Foundation

public struct DrawingLibraryStore: Sendable {
    public let rootDirectory: URL

    private var indexURL: URL {
        rootDirectory.appendingPathComponent("index.json", isDirectory: false)
    }

    public init(rootDirectory: URL = DrawingLibraryStore.defaultRootDirectory()) {
        self.rootDirectory = rootDirectory
    }

    public func svgURL(for id: DrawingID) -> URL {
        rootDirectory
            .appendingPathComponent(id.rawValue.uuidString, isDirectory: false)
            .appendingPathExtension("svg")
    }

    public func loadIndex() throws -> [DrawingSummary] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }

        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode([DrawingSummary].self, from: data)
    }

    public func save(drawing: Drawing, canvasSize: CanvasSize) throws {
        try ensureRootDirectory()

        let svg = SVGDocument.encode(drawing: drawing, canvasSize: canvasSize)
        try svg.write(to: svgURL(for: drawing.id), atomically: true, encoding: .utf8)

        var summaries = try loadIndex()
        let summary = DrawingSummary(
            id: drawing.id,
            updatedAt: drawing.updatedAt,
            title: Self.title(for: drawing.updatedAt)
        )

        summaries.removeAll { $0.id == drawing.id }
        summaries.append(summary)
        summaries.sort { $0.updatedAt > $1.updatedAt }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(summaries)
        try data.write(to: indexURL, options: .atomic)
    }

    public func loadSVG(for id: DrawingID) throws -> String {
        try String(contentsOf: svgURL(for: id), encoding: .utf8)
    }

    public func loadDrawing(id: DrawingID) throws -> Drawing {
        try SVGDocument.decodeDrawing(from: loadSVG(for: id))
    }

    private func ensureRootDirectory() throws {
        try FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func title(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public static func defaultRootDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return applicationSupport.appendingPathComponent("SketchyMac", isDirectory: true)
    }
}
