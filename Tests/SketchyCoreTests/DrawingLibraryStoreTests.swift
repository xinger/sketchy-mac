import XCTest
@testable import SketchyCore

final class DrawingLibraryStoreTests: XCTestCase {
    func testSaveAndReloadDrawingRoundTripsIndexAndSVG() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DrawingLibraryStore(rootDirectory: root)
        let drawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!),
            updatedAt: Date(timeIntervalSince1970: 10),
            strokes: [
                DrawingStroke(
                    points: [DrawingPoint(x: 1, y: 2), DrawingPoint(x: 3, y: 4)],
                    color: .paletteTeal,
                    width: .small,
                    isDashed: false
                )
            ]
        )

        try store.save(drawing: drawing, canvasSize: CanvasSize(width: 320, height: 240))

        let summaries = try store.loadIndex()
        XCTAssertEqual(summaries.map(\.id), [drawing.id])
        let svg = try String(contentsOf: store.svgURL(for: drawing.id), encoding: .utf8)
        XCTAssertTrue(svg.contains("#19C8BE"))
    }

    func testLoadDrawingDecodesSavedSVGMetadata() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DrawingLibraryStore(rootDirectory: root)
        let drawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!),
            updatedAt: Date(timeIntervalSince1970: 30),
            strokes: [
                DrawingStroke(
                    id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                    points: [DrawingPoint(x: 20, y: 30), DrawingPoint(x: 40, y: 50)],
                    color: .paletteOcean,
                    width: .large,
                    isDashed: true
                )
            ]
        )

        try store.save(drawing: drawing, canvasSize: CanvasSize(width: 400, height: 300))

        let loaded = try store.loadDrawing(id: drawing.id)

        XCTAssertEqual(loaded, drawing)
    }
}
