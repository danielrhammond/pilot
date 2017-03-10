/// Simple class that provides ModelCollection conformance to a series of events, easiest way to quickly wrap something
/// that will emit models into a ModelCollection.
public class SimpleModelCollection: ModelCollection, ProxyingCollectionEventObservable {

    internal init(collectionId: ModelCollectionId = "simplemodelcollection-" + Token.makeUnique().stringValue) {
        self.collectionId = collectionId
    }

    /// Event type the SimpleModelCollection consumes
    ///
    /// SimpleModelCollection will begin as a notLoaded ModelCollection, the other event cases match 1:1 with
    /// state values.
    internal enum Event {
        case loading([[Model]]?)
        case error(Error)
        case loaded([[Model]])
    }

    /// Called to notify the model collection of an event.
    internal final func onNext(_ event: Event) {
        switch event {
        case .loading(let models): state = .loading(models)
        case .error(let e): state = .error(e)
        case .loaded(let models): state = .loaded(models)
        }
    }

    // MARK: ModelCollection

    public let collectionId: ModelCollectionId

    public private(set) final var state = ModelCollectionState.notLoaded {
        didSet {
            precondition(Thread.isMainThread)
            observers.notify(.didChangeState(state))
        }
    }

    // MARK: CollectionEventObservable

    public final var proxiedObservable: GenericObservable<CollectionEvent> { return observers }
    private final let observers = ObserverList<CollectionEvent>()
}
