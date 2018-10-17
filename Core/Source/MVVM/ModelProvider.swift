// MARK: IndexedModelProvider

/// Core provider protocol to generate `Model` instances from index paths.
public protocol IndexedModelProvider {
    /// Returns a `Model` for the given `IndexPath` and context.
    func model(for indexPath: IndexPath, context: Context) -> Model?
}

/// An `IndexedModelProvider` implementation that delegates to a closure to provide the
/// appropriate model for the supplied `IndexPath` and `Context`. This is used within pilot
/// for supplementary views within a collection view, but could be repurposed.
public struct BlockModelProvider: IndexedModelProvider {
    public init(binder: @escaping (IndexPath, Context) -> Model?) {
        self.binder = binder
    }

    public func model(for indexPath: IndexPath, context: Context) -> Model? {
        return binder(indexPath, context)
    }

    private let binder: (IndexPath, Context) -> Model?
}
