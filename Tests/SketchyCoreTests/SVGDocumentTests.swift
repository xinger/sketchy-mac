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
        XCTAssertTrue(svg.contains("stroke=\"#2D7DD2\""))
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

        XCTAssertTrue(svg.contains("fill=\"#FF5A5F\""))
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
}
