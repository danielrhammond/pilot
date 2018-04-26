import AppKit
import Pilot

public final class OutlineViewModelDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    public init(
        model: NestedModelCollection,
        modelBinder: ViewModelBindingProvider,
        viewBinder: ViewBindingProvider,
        context: Context
    ) {
        self.root = LazyNestedModelCollectionTreeNode(modelCollection: model)
        self.modelBinder = modelBinder
        self.viewBinder = viewBinder
        self.context = context
        super.init()
        self.collectionObserver = root.observe { [weak self] in
            self?.handleTreeEvent($0)
        }
    }

    public weak var outlineView: NSOutlineView?
    public let context: Context

    // MARK: NSOutlineViewDataSource

    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return root.countOfChildNodes(downcast(item) ?? [])
    }

    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let indexPath = downcast(item) {
            return indexPath.appending(index) as NSIndexPath
        } else {
            return NSIndexPath(index: index)
        }
    }

    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let indexPath = downcast(item) {
            return root.isExpandable(indexPath)
        }
        return false
    }

    // MARK: NSOutlineViewDelegate

    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let indexPath = downcast(item) else { return nil }
        guard tableColumn?.identifier.rawValue == "fv" else { return nil }
        let model = root.modelAtIndexPath(indexPath)
        let viewModel = modelBinder.viewModel(for: model, context: context)

        var reuse: View?
        let type = viewBinder.viewTypeForViewModel(viewModel, context: context)
        if let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(String(reflecting: type)), owner: self) as? View {
            Swift.print("reusing")
            reuse = view
        } else {
            Swift.print("creating")
        }

        let result = viewBinder.view(for: viewModel, context: context, reusing: reuse, layout: nil) as? NSView
        result?.identifier = NSUserInterfaceItemIdentifier(String(reflecting: type))
        return result
    }

    // MARK: Private

    private var sink = [String: NestedModelCollectionPathItem]()
    private let modelBinder: ViewModelBindingProvider
    private let viewBinder: ViewBindingProvider
    private var collectionObserver: Observer?
    private var diffEngine = DiffEngine()
    private let root: LazyNestedModelCollectionTreeNode

    private func handleTreeEvent(_ event: LazyNestedModelCollectionTreeNode.Event) {
        switch event {
        case .updated(let indexPaths):
            for index in indexPaths {
                outlineView?.reloadItem(index as NSIndexPath, reloadChildren: true)
            }
        }
    }

    private func downcast(_ item: Any?) -> IndexPath? {
        if let item = item as? NSIndexPath {
            return item as IndexPath
        }
        if item != nil {
            Log.fatal(message: "Unexpected item returned from NSOutlineView \(String(reflecting: item))")
        }
        return nil
    }
}

private final class NestedModelCollectionPathItem: NSObject {

    static func ==(lhs: NestedModelCollectionPathItem, rhs: NestedModelCollectionPathItem) -> Bool {
        guard lhs.hashValue == rhs.hashValue else { return false }
        guard lhs.path.count == rhs.path.count else { return false }
        for (lhs, rhs) in zip(lhs.path, rhs.path) {
            if lhs != rhs { return false }
        }
        return true
    }

    init(_ path: [ModelId]) {
        self.path = path
        var hash = 0
        for item in path {
            hash ^= item.hashValue
        }
        _hashValue = hash
    }
    let path: [ModelId]
    override var hashValue: Int { return _hashValue }
    private var _hashValue: Int
}
