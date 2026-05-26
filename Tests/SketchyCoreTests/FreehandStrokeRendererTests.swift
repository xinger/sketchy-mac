import XCTest
@testable import SketchyCore

final class FreehandStrokeRendererTests: XCTestCase {
    func testOutlinePathClosesFilledShape() {
        let stroke = DrawingStroke(
            points: [
                DrawingPoint(x: 0, y: 0),
                DrawingPoint(x: 20, y: 0),
                DrawingPoint(x: 40, y: 0)
            ],
            color: .paletteRed,
            width: .large,
            isDashed: false
        )

        let path = FreehandStrokeRenderer.outlinePath(for: stroke)

        XCTAssertTrue(path.hasPrefix("M "))
        XCTAssertTrue(path.hasSuffix("Z"))
        XCTAssertTrue(path.contains("Q"))
    }

    func testLiveOutlineRetainsNewestPointInfluence() {
        let stroke = DrawingStroke(
            points: [
                DrawingPoint(x: 0, y: 0),
                DrawingPoint(x: 15, y: 0),
                DrawingPoint(x: 30, y: 0),
                DrawingPoint(x: 100, y: 0)
            ],
            color: .paletteBlue,
            width: .medium,
            isDashed: false
        )

        let outline = FreehandStrokeRenderer.outlinePoints(for: stroke)

        XCTAssertTrue(outline.contains { abs($0.x - 100) < 0.0001 })
    }

    func testOutlineUsesRoundedCapPastNewestPoint() {
        let stroke = DrawingStroke(
            points: [
                DrawingPoint(x: 0, y: 0),
                DrawingPoint(x: 30, y: 0),
                DrawingPoint(x: 60, y: 0)
            ],
            color: .paletteBlue,
            width: .large,
            isDashed: false
        )

        let outline = FreehandStrokeRenderer.outlinePoints(for: stroke)

        XCTAssertTrue(outline.contains { $0.x > 60 })
        XCTAssertFalse(outline.contains { abs($0.x - 60) < 0.0001 && abs($0.y) < 0.0001 })
    }

    func testOutlineStartsOnLeftSideAndEndsWithStartCap() {
        let stroke = DrawingStroke(
            points: [
                DrawingPoint(x: 60, y: 0),
                DrawingPoint(x: 30, y: 0),
                DrawingPoint(x: 0, y: 0)
            ],
            color: .paletteBlue,
            width: .large,
            isDashed: false
        )

        let outline = FreehandStrokeRenderer.outlinePoints(for: stroke)

        XCTAssertLessThan(outline[0].y, 0)
        XCTAssertTrue(outline.suffix(5).contains { $0.x > 60 })
    }
}
