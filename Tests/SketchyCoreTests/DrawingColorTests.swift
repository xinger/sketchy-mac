import XCTest
@testable import SketchyCore

final class DrawingColorTests: XCTestCase {
    func testPaletteUsesThemeSafeCoreColors() {
        XCTAssertEqual(
            DrawingColor.palette.map(\.hex),
            ["#F4F4F5", "#2563EB", "#EF4444", "#F59E0B", "#16A34A", "#8B5CF6"]
        )
    }
}
