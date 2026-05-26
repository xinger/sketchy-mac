import Foundation

public struct DrawingID: Codable, Hashable, Identifiable, Sendable {
    public var rawValue: UUID

    public var id: UUID { rawValue }

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct DrawingPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CanvasSize: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct DrawingColor: Codable, Equatable, Hashable, Sendable {
    public var name: String
    public var hex: String

    public init(name: String, hex: String) {
        self.name = name
        self.hex = hex
    }

    public static let paletteInk = DrawingColor(name: "Ink", hex: "#F4F4F5")
    public static let paletteBlue = DrawingColor(name: "Blue", hex: "#2563EB")
    public static let paletteRed = DrawingColor(name: "Red", hex: "#EF4444")
    public static let paletteYellow = DrawingColor(name: "Amber", hex: "#F59E0B")
    public static let paletteOcean = DrawingColor(name: "Green", hex: "#16A34A")
    public static let paletteTeal = DrawingColor(name: "Teal", hex: "#14B8A6")

    public static let palette: [DrawingColor] = [
        .paletteInk,
        .paletteBlue,
        .paletteRed,
        .paletteYellow,
        .paletteOcean,
        .paletteTeal
    ]
}

public enum BrushSize: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large

    public var lineWidth: Double {
        switch self {
        case .small:
            return 2
        case .medium:
            return 4
        case .large:
            return 6
        }
    }
}

public struct DrawingStroke: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var points: [DrawingPoint]
    public var color: DrawingColor
    public var width: BrushSize
    public var isDashed: Bool

    public init(
        id: UUID = UUID(),
        points: [DrawingPoint],
        color: DrawingColor,
        width: BrushSize,
        isDashed: Bool
    ) {
        self.id = id
        self.points = points
        self.color = color
        self.width = width
        self.isDashed = isDashed
    }
}

public struct DrawingImageFrame: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct DrawingImage: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var data: Data
    public var mimeType: String
    public var frame: DrawingImageFrame

    public init(
        id: UUID = UUID(),
        data: Data,
        mimeType: String,
        frame: DrawingImageFrame
    ) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.frame = frame
    }
}

public struct Drawing: Codable, Equatable, Identifiable, Sendable {
    public var id: DrawingID
    public var updatedAt: Date
    public var strokes: [DrawingStroke]
    public var images: [DrawingImage]

    public init(
        id: DrawingID = DrawingID(),
        updatedAt: Date = Date(),
        strokes: [DrawingStroke] = [],
        images: [DrawingImage] = []
    ) {
        self.id = id
        self.updatedAt = updatedAt
        self.strokes = strokes
        self.images = images
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case updatedAt
        case strokes
        case images
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(DrawingID.self, forKey: .id)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        strokes = try container.decode([DrawingStroke].self, forKey: .strokes)
        images = try container.decodeIfPresent([DrawingImage].self, forKey: .images) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(strokes, forKey: .strokes)
        try container.encode(images, forKey: .images)
    }
}

public struct DrawingSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: DrawingID
    public var updatedAt: Date
    public var title: String

    public init(id: DrawingID, updatedAt: Date, title: String) {
        self.id = id
        self.updatedAt = updatedAt
        self.title = title
    }
}

public struct ToolState: Codable, Equatable, Sendable {
    public var color: DrawingColor
    public var brushSize: BrushSize
    public var isDashed: Bool

    public init(
        color: DrawingColor = .paletteInk,
        brushSize: BrushSize = .medium,
        isDashed: Bool = false
    ) {
        self.color = color
        self.brushSize = brushSize
        self.isDashed = isDashed
    }
}

public extension DrawingPoint {
    static func distance(_ first: DrawingPoint, _ second: DrawingPoint) -> Double {
        hypot(first.x - second.x, first.y - second.y)
    }
}
