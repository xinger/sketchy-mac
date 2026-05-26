import XCTest
@testable import SketchyCore

final class SVGDocumentTests: XCTestCase {
    func testSVGDocumentContainsStrokeAttributes() {
        let drawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!),
            updatedAt: Date(timeIntervalSince1970: 0),
            strokes: [
                DrawingStroke(
                    points: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 12, y: 8)],
                    color: .paletteBlue,
                    width: .large,
                    isDashed: true
                )
            ]
        )

        let svg = SVGDocument.encode(
            drawing: drawing,
            canvasSize: CanvasSize(width: 800, height: 600)
        )

        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("viewBox=\"0 0 800 600\""))
        XCTAssertTrue(svg.contains("stroke=\"#2563EB\""))
        XCTAssertTrue(svg.contains("stroke-width=\"6\""))
        XCTAssertTrue(svg.contains("stroke-dasharray=\"12 12\""))
    }

    func testSolidStrokeIsPersistedAsFilledFreehandPath() {
        let drawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!),
            updatedAt: Date(timeIntervalSince1970: 40),
            strokes: [
                DrawingStroke(
                    points: [
                        DrawingPoint(x: 0, y: 0),
                        DrawingPoint(x: 20, y: 0),
                        DrawingPoint(x: 40, y: 10)
                    ],
                    color: .paletteRed,
                    width: .medium,
                    isDashed: false
                )
            ]
        )

        let svg = SVGDocument.encode(drawing: drawing, canvasSize: CanvasSize(width: 100, height: 100))

        XCTAssertTrue(svg.contains("fill=\"#EF4444\""))
        XCTAssertFalse(svg.contains("stroke-width=\"4\""))
    }

    func testSVGDocumentDecodesEmbeddedDrawingMetadata() throws {
        let drawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!),
            updatedAt: Date(timeIntervalSince1970: 20),
            strokes: [
                DrawingStroke(
                    id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    points: [DrawingPoint(x: 5, y: 7), DrawingPoint(x: 9, y: 11)],
                    color: .paletteYellow,
                    width: .medium,
                    isDashed: false
                )
            ]
        )

        let svg = SVGDocument.encode(
            drawing: drawing,
            canvasSize: CanvasSize(width: 640, height: 480)
        )

        let decoded = try SVGDocument.decodeDrawing(from: svg)

        XCTAssertEqual(decoded, drawing)
    }

    func testSVGDocumentContainsEmbeddedImagesBeforeStrokes() {
        let image = DrawingImage(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            data: Data([0x89, 0x50, 0x4E, 0x47]),
            mimeType: "image/png",
            frame: DrawingImageFrame(x: 10, y: 20, width: 120, height: 80)
        )
        let drawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!),
            updatedAt: Date(timeIntervalSince1970: 30),
            strokes: [
                DrawingStroke(
                    points: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 10, y: 10)],
                    color: .paletteBlue,
                    width: .medium,
                    isDashed: false
                )
            ],
            images: [image]
        )

        let svg = SVGDocument.encode(drawing: drawing, canvasSize: CanvasSize(width: 300, height: 200))

        XCTAssertTrue(svg.contains("<image"))
        XCTAssertTrue(svg.contains("href=\"data:image/png;base64,iVBORw==\""))
        XCTAssertTrue(svg.contains("x=\"10\""))
        XCTAssertTrue(svg.contains("y=\"20\""))
        XCTAssertTrue(svg.contains("width=\"120\""))
        XCTAssertTrue(svg.contains("height=\"80\""))
        let imageOffset = svg.distance(from: svg.startIndex, to: svg.range(of: "<image")!.lowerBound)
        let pathOffset = svg.distance(from: svg.startIndex, to: svg.range(of: "<path")!.lowerBound)
        XCTAssertLessThan(imageOffset, pathOffset)
    }

    func testDrawingDecodesMetadataWithoutImagesAsEmptyImages() throws {
        let id = "88888888-8888-8888-8888-888888888888"
        let json = """
        {
          "id": { "rawValue": "\(id)" },
          "updatedAt": 0,
          "strokes": []
        }
        """
        let encoded = Data(json.utf8).base64EncodedString()
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <metadata id="sketchy-data">\(encoded)</metadata>
        </svg>
        """

        let decoded = try SVGDocument.decodeDrawing(from: svg)

        XCTAssertEqual(decoded.id, DrawingID(rawValue: UUID(uuidString: id)!))
        XCTAssertTrue(decoded.images.isEmpty)
    }
}
