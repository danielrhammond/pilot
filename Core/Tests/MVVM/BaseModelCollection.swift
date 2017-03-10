import XCTest
@testable import Pilot

class BaseModelCollectionTests: XCTestCase {

    func testShouldStartNotLoaded() {
        let simple = BaseModelCollection()
        XCTAssert(simple.state.isNotLoaded, "BaseModelCollection should be notLoaded before there are any events")
    }

    func testShouldPropegateLoading() {
        let simple = BaseModelCollection()
        simple.onNext(.loading(nil))
        XCTAssert(simple.state.isLoading, "BaseModelCollection should be loading after receiving loading event")
    }

    func testShouldPropegateModels() {
        let simple = BaseModelCollection()
        let test = TM(id: "stub", version: 1)
        simple.onNext(.loaded([[test]]))
        let first = simple.state.sections.first
        XCTAssertEqual(first?.first?.modelId, test.modelId)
        XCTAssertEqual(first?.count, 1)
    }

    func testShouldPropegateLoadingMore() {
        let simple = BaseModelCollection()
        let test = TM(id: "stub", version: 1)
        simple.onNext(.loading([[test]]))
        let first = simple.state.sections.first
        XCTAssert(simple.state.isLoading)
        XCTAssertEqual(first?.first?.modelId, test.modelId)
        XCTAssertEqual(first?.count, 1)
    }
}
