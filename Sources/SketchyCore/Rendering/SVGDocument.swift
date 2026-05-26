import Foundation

public enum SVGDocument {
    public enum DecodeError: Error, Equatable {
        case missingMetadata
        case invalidMetadata
    }

    public static func encode(drawing: Drawing, canvasSize: CanvasSize) -> String {
        let metadata = metadataElement(for: drawing)
        let paths = drawing.strokes
            .map(pathElement(for:))
            .joined(separator: "\n  ")

        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(attribute(canvasSize.width)) \(attribute(canvasSize.height))">
          \(metadata)
          \(paths)
        </svg>
        """
    }

    public static func decodeDrawing(from svg: String) throws -> Drawing {
        let opening = "<metadata id=\"sketchy-data\">"
        let closing = "</metadata>"

        guard
            let openingRange = svg.range(of: opening),
            let closingRange = svg.range(of: closing, range: openingRange.upperBound..<svg.endIndex)
        else {
            throw DecodeError.missingMetadata
        }

        let encoded = String(svg[openingRange.upperBound..<closingRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = Data(base64Encoded: encoded) else {
            throw DecodeError.invalidMetadata
        }

        return try JSONDecoder().decode(Drawing.self, from: data)
    }

    private static func pathElement(for stroke: DrawingStroke) -> String {
        if !stroke.isDashed {
            return """
            <path d="\(escape(FreehandStrokeRenderer.outlinePath(for: stroke)))" fill="\(escape(stroke.color.hex))"/>
            """
        }

        let dashAttribute: String
        if stroke.isDashed {
            let dash = stroke.width.lineWidth * 2
            dashAttribute = " stroke-dasharray=\"\(attribute(dash)) \(attribute(dash))\""
        } else {
            dashAttribute = ""
        }

        return """
        <path d="\(escape(StrokeSmoother.finalPath(for: stroke)))" fill="none" stroke="\(escape(stroke.color.hex))" stroke-width="\(attribute(stroke.width.lineWidth))" stroke-linecap="round" stroke-linejoin="round"\(dashAttribute)/>
        """
    }

    private static func metadataElement(for drawing: Drawing) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(drawing) else {
            return "<metadata id=\"sketchy-data\"></metadata>"
        }

        return "<metadata id=\"sketchy-data\">\(data.base64EncodedString())</metadata>"
    }

    private static func attribute(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", value)
    }

    private static func escape(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
