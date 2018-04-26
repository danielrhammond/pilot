import Foundation
import Pilot

/// TODO: explanation
/// NOTE: Considered == whenever the indexPath and ModelCollection's collection id are ==
internal final class LazyNestedModelCollectionTreeNode: ProxyingObservable {
    internal init(
        modelCollection: NestedModelCollection = EmptyModelCollection().asNested(),
        indexPath: IndexPath = IndexPath(),
        parent: LazyNestedModelCollectionTreeNode? = nil
    ) {
        self.indexPath = indexPath
        self.modelCollection = modelCollection
        if let parent = parent {
            self.observers = parent.observers
        } else {
            self.observers = ObserverList<Event>()
        }
        self.modelCollectionObserver = modelCollection.observe { [weak self] (event) in
            self?.handleCollectionEvent(event)
        }
    }

    internal func isExpandable(_ path: IndexPath) -> Bool {
        let model = modelAtIndexPath(path)
        let containingNode = findOrCreateNode(path.dropLast())
        return containingNode.modelCollection.isModelExpandable(model)
    }

    internal func countOfChildNodes(_ path: IndexPath) -> Int {
        return findOrCreateNode(path).modelCollection.models.count
    }

    internal func modelAtIndexPath(_ path: IndexPath) -> Model {
        guard !path.isEmpty else { Log.fatal(message: "Empty path passed to modelAtIndexPath()") }
        let containingNode = findOrCreateNode(path.dropLast())
        return containingNode.modelCollection.models[path.last!]
    }

    internal let indexPath: IndexPath
    internal weak var parent: LazyNestedModelCollectionTreeNode? = nil

    // MARK: Observable

    enum Event {
        case updated([IndexPath])
    }

    public final var proxiedObservable: GenericObservable<Event> { return observers }
    private final let observers: ObserverList<Event>

    // MARK: Private

    private var childrenCache = [ModelId: LazyNestedModelCollectionTreeNode]()
    private let modelCollection: NestedModelCollection
    private var modelCollectionObserver: Observer?

    private func handleCollectionEvent(_ event: CollectionEvent) {
        switch event {
        case .didChangeState(let state):
            _ = state
            observers.notify(.updated([indexPath]))
        }
    }

    private func findOrCreateNode(_ path: IndexPath) -> LazyNestedModelCollectionTreeNode {
        guard !path.isEmpty else { return self }
        let model = modelCollection.models[path[0]]
        if let cached = childrenCache[model.modelId] {
            return cached.findOrCreateNode(path.dropFirst())
        } else {
            let childModelCollection = modelCollection.childModelCollection(model)
            let childIndexPath = indexPath.appending(path[0])
            let node = LazyNestedModelCollectionTreeNode(
                modelCollection: childModelCollection,
                indexPath: childIndexPath,
                parent: self)
            childrenCache[model.modelId] = node
            return node.findOrCreateNode(path.dropFirst())
        }
    }
}

extension LazyNestedModelCollectionTreeNode: Equatable {
    static func ==(lhs: LazyNestedModelCollectionTreeNode, rhs: LazyNestedModelCollectionTreeNode) -> Bool {
        return lhs.indexPath == rhs.indexPath && lhs.modelCollection.collectionId == rhs.modelCollection.collectionId
    }
}
