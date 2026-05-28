import Combine
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

    func testSavingInOneWindowRefreshesAnotherWindowSidebar() {
        let store = DrawingLibraryStore(rootDirectory: uniqueStoreURL())
        let writer = SketchWindowModel(store: store)
        let reader = SketchWindowModel(store: store)
        var cancellables = Set<AnyCancellable>()
        let expectation = expectation(description: "Reader window reloads saved drawing summary")

        reader.$summaries
            .dropFirst()
            .sink { summaries in
                if summaries.contains(where: { $0.id == writer.drawing.id }) {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        writer.beginStroke(at: DrawingPoint(x: 0, y: 0))
        writer.appendStrokePoint(DrawingPoint(x: 20, y: 10))
        writer.finishStroke()
        writer.flushAutosave()

        wait(for: [expectation], timeout: 1)
    }

    func testUndoAndRedoFinishedStroke() {
        let model = SketchWindowModel(store: DrawingLibraryStore(rootDirectory: uniqueStoreURL()))

        let stroke = finishStroke(in: model, xOffset: 10)

        XCTAssertTrue(model.canUndo)
        XCTAssertFalse(model.canRedo)

        model.undo()

        XCTAssertTrue(model.drawing.strokes.isEmpty)
        XCTAssertFalse(model.canUndo)
        XCTAssertTrue(model.canRedo)

        model.redo()

        XCTAssertEqual(model.drawing.strokes, [stroke])
        XCTAssertTrue(model.canUndo)
        XCTAssertFalse(model.canRedo)
    }

    func testRedoHistoryClearsAfterNewDrawingStep() {
        let model = SketchWindowModel(store: DrawingLibraryStore(rootDirectory: uniqueStoreURL()))

        let firstStroke = finishStroke(in: model, xOffset: 0)
        _ = finishStroke(in: model, xOffset: 20)
        model.undo()

        let thirdStroke = finishStroke(in: model, xOffset: 40)

        XCTAssertEqual(model.drawing.strokes, [firstStroke, thirdStroke])
        XCTAssertFalse(model.canRedo)
    }

    func testUndoHistoryKeepsOnlyLastFiftySteps() {
        let model = SketchWindowModel(store: DrawingLibraryStore(rootDirectory: uniqueStoreURL()))

        for index in 0..<55 {
            _ = finishStroke(in: model, xOffset: Double(index * 10))
        }

        for _ in 0..<50 {
            model.undo()
        }

        XCTAssertEqual(model.drawing.strokes.count, 5)
        XCTAssertFalse(model.canUndo)
    }

    func testUndoAndRedoInsertedImage() {
        let model = SketchWindowModel(store: DrawingLibraryStore(rootDirectory: uniqueStoreURL()))
        let image = DrawingImage(
            data: Data([0x89, 0x50, 0x4E, 0x47]),
            mimeType: "image/png",
            frame: DrawingImageFrame(x: 10, y: 20, width: 30, height: 40)
        )

        model.insertImage(image)
        model.undo()

        XCTAssertTrue(model.drawing.images.isEmpty)
        XCTAssertTrue(model.canRedo)

        model.redo()

        XCTAssertEqual(model.drawing.images, [image])
    }

    func testNewAndSelectedDrawingsResetUndoHistory() throws {
        let store = DrawingLibraryStore(rootDirectory: uniqueStoreURL())
        let model = SketchWindowModel(store: store)
        let savedDrawing = Drawing(
            id: DrawingID(rawValue: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!),
            updatedAt: Date(timeIntervalSince1970: 40),
            strokes: [
                DrawingStroke(
                    points: [DrawingPoint(x: 1, y: 2), DrawingPoint(x: 3, y: 4)],
                    color: .paletteRed,
                    width: .small,
                    isDashed: false
                )
            ]
        )
        try store.save(drawing: savedDrawing, canvasSize: CanvasSize(width: 320, height: 240))

        _ = finishStroke(in: model, xOffset: 0)
        XCTAssertTrue(model.canUndo)

        model.newDrawing()

        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.canRedo)

        _ = finishStroke(in: model, xOffset: 20)
        model.selectDrawing(id: savedDrawing.id)

        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.canRedo)
        XCTAssertEqual(model.drawing, savedDrawing)
    }

    func testUndoToEmptyUnsavedDrawingCancelsPendingAutosave() throws {
        let store = DrawingLibraryStore(rootDirectory: uniqueStoreURL())
        let model = SketchWindowModel(store: store)

        _ = finishStroke(in: model, xOffset: 0)
        model.undo()
        model.flushAutosave()

        XCTAssertTrue(try store.loadIndex().isEmpty)
    }

    func testUndoToEmptyPreviouslySavedDrawingAutosavesEmptyState() throws {
        let store = DrawingLibraryStore(rootDirectory: uniqueStoreURL())
        let model = SketchWindowModel(store: store)

        _ = finishStroke(in: model, xOffset: 0)
        model.flushAutosave()
        let drawingID = model.drawing.id

        model.undo()
        model.flushAutosave()

        let loaded = try store.loadDrawing(id: drawingID)
        XCTAssertTrue(loaded.strokes.isEmpty)
        XCTAssertTrue(loaded.images.isEmpty)
    }

    @discardableResult
    private func finishStroke(in model: SketchWindowModel, xOffset: Double) -> DrawingStroke {
        model.beginStroke(at: DrawingPoint(x: xOffset, y: 0))
        model.appendStrokePoint(DrawingPoint(x: xOffset + 10, y: 10))
        model.finishStroke()
        return model.drawing.strokes.last!
    }

    private func uniqueStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
