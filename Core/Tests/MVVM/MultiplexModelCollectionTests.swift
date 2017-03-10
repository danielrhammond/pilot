import XCTest
@testable import Pilot

private struct StubError: Error {}

class MultiplexModelCollectionTests: XCTestCase {

    func testPassthroughLoadedModels() {
        let first = StaticModel(modelId: "0.0", data: "")
        let second = StaticModel(modelId: "1.0", data: "")
        let subject = MultiplexModelCollection([
            StaticModelCollection([[first]]),
            StaticModelCollection([[second]]),
            ])
        let expected: ModelCollectionState = .loaded([[first], [second]])
        assertModelCollectionState(expected: expected, actual: subject.state)
    }

    func testPropegatesLoadingState() {
        let firstSubCollection = BaseModelCollection()
        let secondSubCollection = BaseModelCollection()
        let subject = MultiplexModelCollection([firstSubCollection, secondSubCollection])
        assertModelCollectionState(expected: .notLoaded, actual: subject.state)
        firstSubCollection.onNext(.loading(nil))
        assertModelCollectionState(expected: .loading(nil), actual: subject.state)
    }

    func testPropegatesErrorState() {
        let firstSubCollection = BaseModelCollection()
        let secondSubCollection = BaseModelCollection()
        let subject = MultiplexModelCollection([firstSubCollection, secondSubCollection])
        firstSubCollection.onNext(.loaded([]))
        secondSubCollection.onNext(.error(StubError()))
        assertModelCollectionState(expected: .error(StubError()), actual: subject.state)
    }

    func testInsertsEmptySectionsForNotLoadedSections() {
        let firstSubCollection = BaseModelCollection()
        let secondSubCollection = BaseModelCollection()
        let thirdSubCollection = BaseModelCollection()
        let subject = MultiplexModelCollection([firstSubCollection, secondSubCollection, thirdSubCollection])
        firstSubCollection.onNext(.loaded([[StaticModel(modelId: "0", data: "")]]))
        secondSubCollection.onNext(.loading(nil))
        thirdSubCollection.onNext(.loaded([[StaticModel(modelId: "1", data: "")]]))
        let expected: ModelCollectionState = .loading([
            [StaticModel(modelId: "0", data: "")],
            [],
            [StaticModel(modelId: "1", data: "")]
            ])
        assertModelCollectionState(expected: expected, actual: subject.state)
    }

    func testPropegatesLoadedState() {
        let firstSubCollection = BaseModelCollection()
        let secondSubCollection = BaseModelCollection()
        let subject = MultiplexModelCollection([firstSubCollection, secondSubCollection])
        firstSubCollection.onNext(.loaded([[StaticModel(modelId: "0", data: "")]]))
        secondSubCollection.onNext(.loaded([[StaticModel(modelId: "1", data: "")]]))
        let expected: ModelCollectionState = .loaded([
            [StaticModel(modelId: "0", data: "")],
            [StaticModel(modelId: "1", data: "")]
            ])
        assertModelCollectionState(expected: expected, actual: subject.state)
    }
}
