import XCTest
@testable import SketchyCore

final class DrawingImagePlacementTests: XCTestCase {
    func testCenteredImageFrameFitsLargeImageIntoVisibleWorldArea() {
        let frame = DrawingImagePlacement.centeredFrame(
            imageSize: CanvasSize(width: 1000, height: 500),
            viewport: ViewportTransform(),
            canvasSize: CanvasSize(width: 500, height: 300)
        )

        XCTAssertEqual(frame.x, 100, accuracy: 0.001)
        XCTAssertEqual(frame.y, 75, accuracy: 0.001)
        XCTAssertEqual(frame.width, 300, accuracy: 0.001)
        XCTAssertEqual(frame.height, 150, accuracy: 0.001)
    }

    func testCenteredImageFrameKeepsSmallImageAtNaturalSize() {
        let frame = DrawingImagePlacement.centeredFrame(
            imageSize: CanvasSize(width: 100, height: 50),
            viewport: ViewportTransform(scale: 2, offsetX: 20, offsetY: 10),
            canvasSize: CanvasSize(width: 500, height: 300)
        )

        XCTAssertEqual(frame.x, 65, accuracy: 0.001)
        XCTAssertEqual(frame.y, 45, accuracy: 0.001)
        XCTAssertEqual(frame.width, 100, accuracy: 0.001)
        XCTAssertEqual(frame.height, 50, accuracy: 0.001)
    }
}
