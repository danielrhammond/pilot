import Pilot

public final class DirectoryModelCollection: NestedModelCollection, ProxyingCollectionEventObservable {
    public init(url: URL) {
        self.collectionId = "DMC-\(url.path)"
        self.fileURLs = try! FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants])
        self.state = .loaded(fileURLs.map { File(url: $0) })
    }

    // MARK: CollectionEventObservable

    public var proxiedObservable: GenericObservable<CollectionEvent> { return observers }
    private let observers = ObserverList<CollectionEvent>()

    // MARK: ModelCollection

    public let collectionId: ModelCollectionId
    public var state: ModelCollectionState {
        didSet { observers.notify(.didChangeState(state)) }
    }

    // MARK: NestedModelCollection

    public func isModelExpandable(_ model: Model) -> Bool {
        let file: File = model.typedModel()
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: file.url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

    public func childModelCollection(_ model: Model) -> NestedModelCollection {
        guard isModelExpandable(model) else {
            return EmptyModelCollection().asNested()
        }
        let file: File = model.typedModel()
        return DirectoryModelCollection(url: file.url)
    }

    // MARK: Private

    private var fileURLs: [URL] {
        didSet {
            state = .loaded(fileURLs.map({ File(url: $0) }))
        }
    }
}
