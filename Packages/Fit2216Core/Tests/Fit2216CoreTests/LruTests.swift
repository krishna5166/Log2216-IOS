import XCTest
@testable import Fit2216Core

final class LruTests: XCTestCase {
    func testNewKeyGoesLastAndTheOldestIsEvictedPastTheLimit() {
        let r = Lru.touch(["a", "b", "c"], key: "d", limit: 3)
        XCTAssertEqual(r.order, ["b", "c", "d"])
        XCTAssertEqual(r.evicted, ["a"])
    }

    func testTouchingAnExistingKeyMovesItWithoutEvicting() {
        let r = Lru.touch(["a", "b", "c"], key: "a", limit: 3)
        XCTAssertEqual(r.order, ["b", "c", "a"])
        XCTAssertTrue(r.evicted.isEmpty)
    }

    func testShrinkingTheLimitEvictsSeveralOldestFirst() {
        let r = Lru.touch(["a", "b", "c", "d"], key: "e", limit: 2)
        XCTAssertEqual(r.order, ["d", "e"])
        XCTAssertEqual(r.evicted, ["a", "b", "c"])
        XCTAssertEqual(Lru.touch([], key: "x", limit: 0).order, ["x"]) // a limit below one still keeps the newest
    }
}
