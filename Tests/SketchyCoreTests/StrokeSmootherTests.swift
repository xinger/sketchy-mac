import XCTest
@testable import SketchyCore

final class StrokeSmootherTests: XCTestCase {
    func testLivePathKeepsLastPointAsEndpoint() {
        let stroke = DrawingStroke(
            points: [
                DrawingPoint(x: 10, y: 10),
                DrawingPoint(x: 20, y: 20),
                DrawingPoint(x: 40, y: 18),
                DrawingPoint(x: 80, y: 30)
            ],
            color: .paletteRed,
            width: .medium,
            isDashed: false
        )

        let path = StrokeSmoother.livePath(for: stroke)

        XCTAssertTrue(path.hasSuffix("L 80.00 30.00"))
    }
}
