import Foundation
import Pilot

public final class MediaSearchModelCollection: ModelCollection, ProxyingCollectionEventObservable {

    init() {
        state = .loaded([])
    }

    // MARK: Public

    public enum MediaSearchError: Error {
        case service(Error)
        case unknown
    }

    public func updateQuery(_ query: String) {
        guard query != previousQuery else { return }
        state = .loading(state.sections)
        previousQuery = query
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) { [weak self] in
            guard query == self?.previousQuery else { return }
            self?.service.search(term: query, limit: 100, explicit: true) { [weak self] (media, error) in
                DispatchQueue.main.async {
                    guard let strongSelf = self, strongSelf.previousQuery == query else { return }
                    if let media = media {
                        strongSelf.state = .loaded([media])
                    } else {
                        let error: MediaSearchError = error.flatMap({ .service($0) }) ?? .unknown
                        strongSelf.state = .error(error)
                    }
                }
            }
        }
    }

    // MARK: ModelCollection

    public let collectionId: ModelCollectionId = "MediaSearchModelCollection"

    public private(set) final var state = ModelCollectionState.notLoaded {
        didSet {
            precondition(Thread.isMainThread)
            observers.notify(.didChangeState(state))
        }
    }

    // MARK: CollectionEventObservable

    public final var proxiedObservable: GenericObservable<CollectionEvent> { return observers }
    private final let observers = ObserverList<CollectionEvent>()

    // MARK: Private

    private let service = SearchService()
    private var previousQuery: String?
}
