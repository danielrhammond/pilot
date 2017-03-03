import XCTest
import Pilot
@testable import PilotUI

class CollectionViewModelDataSourceTests: XCTestCase {

    typealias SubjectState = (CollectionViewModelDataSource.Event, ModelCollectionState)

    func testWillUpdateItemsCalledBeforeStateApplied() {
        let model1 = Widget()
        let stubEvents: [SimpleModelCollection.Event] = [
            .loaded([[model1]])
        ]
        let results = dataSourceEvents(for: stubEvents, expected: 2)
        let willUpdateState = results.first!
        if case .willUpdateItems = willUpdateState.0 {}
        else { XCTFail("Expected first event to be a willUpdateItems") }
        let sections = willUpdateState.1.sections
        XCTAssert(sections.isEmpty, "Sections should be empty before update applied")
    }

    // TODO:(danielh) This is a little hacky, consider refactoring CVMDS to not require collection view for testing,
    // which should allow the cases above to remain the same while removing/simplifying this function.
    private func dataSourceEvents(
        for events: [SimpleModelCollection.Event],
        expected: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) -> [SubjectState] {
        let collectionView: PlatformCollectionView
        #if os(macOS)
            let window = NSWindow()
            let scrollView = NSScrollView()
            let clipView = NSClipView()
            scrollView.addSubview(clipView)
            collectionView = NSCollectionView()
            clipView.documentView = collectionView
            window.contentView!.addSubview(scrollView)
        #elseif os(iOS)
            let window = UIWindow()
            collectionView = UICollectionView(
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                collectionViewLayout: UICollectionViewFlowLayout())
            window.addSubview(collectionView)
        #endif

        let stub = SimpleModelCollection()
        let subject = CollectionViewModelDataSource(
            model: stub,
            modelBinder: DefaultViewModelBindingProvider(),
            viewBinder: StaticViewBindingProvider(type: WidgetView.self),
            context: Context(),
            reuseIdProvider: DefaultCollectionViewCellReuseIdProvider())
        subject.collectionView = collectionView

        let observerExpectation = expectation(description: "wait for collection view model data source events")
        var observedEvents = [SubjectState]()
        var remaining = expected
        let observer = subject.addObserver { (event) in
            observedEvents.append((event, subject.currentCollection.state))
            remaining -= 1
            if remaining == 0 {
                observerExpectation.fulfill()
            } else if remaining < 0 {
                XCTFail(
                    "Unexpected event expected \(expected) \(expected-remaining) remaining, event: \(event)",
                    file: file,
                    line: line)
            }
        }
        _ = observer
        subject.fakeSyncedCollectionViewState()
        for event in events {
            stub.onNext(event)
            subject.fakeSyncedCollectionViewState()
        }
        waitForExpectations(timeout: 1, handler: nil)
        return observedEvents
    }
}

private extension CollectionViewModelDataSource {
    func fakeSyncedCollectionViewState() {
        // This is the heuristic which CollectionViewModelDataSource uses to determine collection view synced state.
        _ = subject.numberOfSections(in: collectionView)
    }
}

private struct Widget: Model {
    init() {
        self.modelId = Token.makeUnique().stringValue
    }
    let modelId: ModelId
    let modelVersion: ModelVersion = ModelVersion.makeUnique()
}

private struct WidgetViewModel: ViewModel {
    init(model: Model, context: Context) {
        self.context = context
        self.model = model
    }

    let context: Context
    let model: Model
}

private final class WidgetView: View {

    var viewModel: ViewModel?

    func bindToViewModel(_ viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func unbindFromViewModel() {
        self.viewModel = nil
    }
}
