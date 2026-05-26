import XCTest
@testable import Sketchy
@testable import SketchyCore

final class SketchWindowModelTests: XCTestCase {
    func testNewWindowStartsWithFreshDrawingWhenStoreHasSavedDrawings() throws {
        let store = DrawingLibraryStore(rootDirectory: uniqueStoreURL())
        let savedDrawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!),
            updatedAt: Date(timeIntervalSince1970: 10),
            strokes: [
                DrawingStroke(
                    points: [DrawingPoint(x: 1, y: 2), DrawingPoint(x: 3, y: 4)],
                    color: .paletteBlue,
                    width: .medium,
                    isDashed: false
                )
            ]
        )
        try store.save(drawing: savedDrawing, canvasSize: CanvasSize(width: 320, height: 240))

        let model = SketchWindowModel(store: store)

        XCTAssertNotEqual(model.drawing.id, savedDrawing.id)
        XCTAssertTrue(model.drawing.strokes.isEmpty)
        XCTAssertTrue(model.drawing.images.isEmpty)
        XCTAssertEqual(model.summaries.map(\.id), [savedDrawing.id])
    }

    func testEmptyNewDrawingIsNotAutosavedByCanvasSizeOrNewDrawing() throws {
        let store = DrawingLibraryStore(rootDirectory: uniqueStoreURL())
        let model = SketchWindowModel(store: store)

        model.updateCanvasSize(width: 640, height: 480)
        model.newDrawing()
        model.flushAutosave()

        XCTAssertTrue(try store.loadIndex().isEmpty)
    }

    private func uniqueStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
