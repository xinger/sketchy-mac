import XCTest
@testable import SketchyCore

final class ViewportTransformTests: XCTestCase {
    func testScreenWorldRoundTripUsesOffsetAndScale() {
        let transform = ViewportTransform(scale: 2, offsetX: 30, offsetY: -10)
        let screen = DrawingPoint(x: 130, y: 50)

        let world = transform.worldPoint(fromScreenPoint: screen)
        let roundTrip = transform.screenPoint(fromWorldPoint: world)

        XCTAssertEqual(world.x, 50, accuracy: 0.0001)
        XCTAssertEqual(world.y, 30, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.x, screen.x, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.y, screen.y, accuracy: 0.0001)
    }

    func testZoomAtScreenPointKeepsWorldPointUnderCursor() {
        let transform = ViewportTransform(scale: 1, offsetX: 20, offsetY: 30)
        let cursor = DrawingPoint(x: 220, y: 130)
        let before = transform.worldPoint(fromScreenPoint: cursor)

        let zoomed = transform.zoomed(by: 2, aroundScreenPoint: cursor)
        let after = zoomed.worldPoint(fromScreenPoint: cursor)

        XCTAssertEqual(zoomed.scale, 2, accuracy: 0.0001)
        XCTAssertEqual(after.x, before.x, accuracy: 0.0001)
        XCTAssertEqual(after.y, before.y, accuracy: 0.0001)
    }
}
