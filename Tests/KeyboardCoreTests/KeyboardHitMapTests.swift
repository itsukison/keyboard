import XCTest
@testable import KeyboardCore

final class KeyboardHitMapTests: XCTestCase {
    private func makeMap() -> KeyboardHitMap<String> {
        KeyboardHitMap(
            bounds: KeyboardHitRect(x: 0, y: 0, width: 320, height: 220),
            rows: [
                KeyboardHitMap.Row(
                    rect: KeyboardHitRect(x: 0, y: 0, width: 320, height: 44),
                    keys: [
                        .init(key: "q", rect: KeyboardHitRect(x: 0, y: 0, width: 28, height: 44)),
                        .init(key: "w", rect: KeyboardHitRect(x: 35, y: 0, width: 28, height: 44)),
                        .init(key: "e", rect: KeyboardHitRect(x: 70, y: 0, width: 28, height: 44)),
                    ]
                ),
                KeyboardHitMap.Row(
                    rect: KeyboardHitRect(x: 0, y: 55, width: 320, height: 44),
                    keys: [
                        .init(key: "a", rect: KeyboardHitRect(x: 19, y: 55, width: 28, height: 44)),
                        .init(key: "s", rect: KeyboardHitRect(x: 54, y: 55, width: 28, height: 44)),
                    ]
                ),
                KeyboardHitMap.Row(
                    rect: KeyboardHitRect(x: 0, y: 110, width: 320, height: 44),
                    keys: [
                        .init(key: "shift", rect: KeyboardHitRect(x: 0, y: 110, width: 44, height: 44)),
                        .init(key: "z", rect: KeyboardHitRect(x: 51, y: 110, width: 28, height: 44)),
                        .init(key: "delete", rect: KeyboardHitRect(x: 276, y: 110, width: 44, height: 44)),
                    ]
                ),
                KeyboardHitMap.Row(
                    rect: KeyboardHitRect(x: 0, y: 165, width: 320, height: 44),
                    keys: [
                        .init(key: "globe", rect: KeyboardHitRect(x: 45, y: 165, width: 32, height: 44)),
                        .init(key: "space", rect: KeyboardHitRect(x: 84, y: 165, width: 150, height: 44)),
                        .init(key: "return", rect: KeyboardHitRect(x: 241, y: 165, width: 70, height: 44)),
                    ]
                ),
            ]
        )
    }

    func testExactKeyCenterResolvesAsDirectHit() {
        let result = makeMap().resolve(.init(x: 14, y: 22))

        XCTAssertEqual(result?.key, "q")
        XCTAssertEqual(result?.isDirectHit, true)
        XCTAssertEqual(result?.rowDistance, 0)
        XCTAssertEqual(result?.edgeDistance, 0)
    }

    func testHorizontalGapResolvesToNearestKey() {
        let result = makeMap().resolve(.init(x: 32, y: 22))

        XCTAssertEqual(result?.key, "w")
        XCTAssertEqual(result?.isDirectHit, false)
        XCTAssertEqual(result?.rowDistance, 0)
        XCTAssertEqual(result?.edgeDistance, 3)
    }

    func testInterRowGapResolvesToNearestRowAndKey() {
        let result = makeMap().resolve(.init(x: 68, y: 50))

        XCTAssertEqual(result?.key, "s")
        XCTAssertEqual(result?.isDirectHit, false)
        XCTAssertEqual(result?.rowDistance, 5)
    }

    func testLeftEdgeGapResolvesToFirstKeyInNearestRow() {
        let result = makeMap().resolve(.init(x: 2, y: 77))

        XCTAssertEqual(result?.key, "a")
        XCTAssertEqual(result?.isDirectHit, false)
    }

    func testRightEdgeGapResolvesToLastKeyInNearestRow() {
        let result = makeMap().resolve(.init(x: 319, y: 132))

        XCTAssertEqual(result?.key, "delete")
        XCTAssertEqual(result?.isDirectHit, true)
    }

    func testModifierAdjacentGapCanResolveToModifier() {
        let result = makeMap().resolve(.init(x: 47, y: 132))

        XCTAssertEqual(result?.key, "z")
        XCTAssertEqual(result?.isDirectHit, false)
    }

    func testBottomRowSpaceReturnBoundaryResolvesByCenter() {
        let result = makeMap().resolve(.init(x: 237, y: 187))

        XCTAssertEqual(result?.key, "return")
        XCTAssertEqual(result?.isDirectHit, false)
    }

    func testOutsideBoundsIsRejected() {
        XCTAssertNil(makeMap().resolve(.init(x: 10, y: -1)))
        XCTAssertNil(makeMap().resolve(.init(x: 321, y: 20)))
    }
}
