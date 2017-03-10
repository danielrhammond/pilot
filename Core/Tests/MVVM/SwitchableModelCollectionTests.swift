@testable import Pilot
import XCTest

class SwitchableModelCollectionTests: XCTestCase {

    func testForwardsState() {
        let stub = BaseModelCollection()
        let subject = SwitchableModelCollection(modelCollection: stub)
        assertModelCollectionState(expected: stub.state, actual: subject.state)
        stub.onNext(.loading(nil))
        assertModelCollectionState(expected: stub.state, actual: subject.state)
    }

    func testSendsEventWhenSwitched() {
        let simple = BaseModelCollection()
        simple.onNext(.loading(nil))
        let subject = SwitchableModelCollection(modelCollection: simple)
        let exp = expectation(description: "observer event")
        let observer = subject.observe { (event) in
            if case .didChangeState(let state) = event {
                if case .loaded(let sections) = state {
                    XCTAssertEqual(sections.count, 1)
                    XCTAssert(sections.first?.isEmpty == true, "Should be empty collection")
                    exp.fulfill()
                }
            }
        }
        let empty = EmptyModelCollection()
        subject.switchTo(empty)
        waitForExpectations(timeout: 1, handler: nil)
        assertModelCollectionState(expected: empty.state, actual: subject.state)
        _ = observer
    }

    func testUnsubscribesWhenSwitched() {
        let old = BaseModelCollection()
        let subject = SwitchableModelCollection(modelCollection: old)
        let new = BaseModelCollection()
        new.onNext(.loaded([]))
        subject.switchTo(new)
        old.onNext(.loading(nil))
        assertModelCollectionState(expected: new.state, actual: subject.state)
    }
}
