import AppKit
import Pilot

public final class OutlineViewModelDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    public init(
        model: NestedModelCollection,
        modelBinder: ViewModelBindingProvider,
        viewBinder: ViewBindingProvider,
        context: Context
    ) {
        self.root = NestedModelCollectionTree(model, parent: nil)
        self.modelBinder = modelBinder
        self.viewBinder = viewBinder
        self.context = context
        super.init()
        self.collectionObserver = model.observe { [weak self] in
            self?.handleCollectionEvent($0)
        }
    }

    public weak var outlineView: NSOutlineView?
    public let context: Context

    // MARK: NSOutlineViewDataSource

    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? NestedModelCollectionPathItem {
            return root.findOrCreateModelCollectionAtPath(item.path).models.count
        } else if item == nil {
            return root.findOrCreateModelCollectionAtPath([]).models.count
        } else {
            Log.fatal(message: "Unexpected item type: \(String(describing: item))")
        }
        /*
        let url = item as? NSURL ?? NSURL(fileURLWithPath: NSHomeDirectory())
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path!, isDirectory: &isDir)
        guard isDir.boolValue else { return 0 }
        let result = try! FileManager.default.contentsOfDirectory(atPath: url.path!).count
        Swift.print("item \(String(describing: item)) numChildren: \(result)")
        return result
        */
    }

    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? NestedModelCollectionPathItem {
            let model = root.findOrCreateModelCollectionAtPath(item.path).models[index]
            return NestedModelCollectionPathItem(item.path + [model.modelId])
        } else if item == nil {
            let model = root.findOrCreateModelCollectionAtPath([]).models[index]
            return NestedModelCollectionPathItem([model.modelId])
        } else {
            Log.fatal(message: "Unexpected item type: \(String(describing: item))")
        }
        /*
        let url = item as? NSURL ?? NSURL(fileURLWithPath: NSHomeDirectory())
        let path = try! FileManager.default.contentsOfDirectory(atPath: url.path!).sorted()[index]
        return url.appendingPathComponent(path)!
        */
    }

    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? NestedModelCollectionPathItem {
            guard item.path.count >= 1 else {
                Log.fatal(message: "Empty path")
            }
            return root.isPathExpandable(item.path)
        }
        Log.fatal(message: "Unexpected item \(item)")
        /*
        let url = item as? NSURL ?? NSURL(fileURLWithPath: NSHomeDirectory())
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path!, isDirectory: &isDir)
        return isDir.boolValue
        */
    }

    // MARK: NSOutlineViewDelegate

    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? NestedModelCollectionPathItem else { return nil }
        guard tableColumn?.identifier.rawValue == "fv" else { return nil }
        let model = root.model(item.path)
        let viewModel = modelBinder.viewModel(for: model, context: context)

        var reuse: View?
        if let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("fileView"), owner: self) as? View {
            Swift.print("reusing")
            reuse = view
        } else {
            Swift.print("creating")
        }
//        else {
//            result = type.init()
//            result.drawsBackground = false
//            result.isBezeled = false
//            result.isBordered = false
//            result.isEditable = false
//            result.font = NSFont.systemFont(ofSize: 12)
//            Swift.print("\(Unmanaged.passUnretained(result).toOpaque()) creating")
//            result.identifier = NSUserInterfaceItemIdentifier("fileView")
//        }
        return viewBinder.view(for: viewModel, context: context, reusing: reuse, layout: nil) as? NSView
    }

    // MARK: Private

    private let modelBinder: ViewModelBindingProvider
    private let viewBinder: ViewBindingProvider
    private var collectionObserver: Observer?
    private var diffEngine = DiffEngine()
    private let root: NestedModelCollectionTree

    private func handleCollectionEvent(_ event: CollectionEvent) {
        outlineView?.reloadData()
    }
}

private final class NestedModelCollectionPathItem: NSObject {
    init(_ path: [ModelId]) { self.path = path }
    let path: [ModelId]
}

private final class NestedModelCollectionTree {
    fileprivate typealias Path = [ModelId]

    init(_ modelCollection: NestedModelCollection, parent: NestedModelCollectionTree?) {
        self.root = modelCollection
        self.parent = parent
    }

    func isPathExpandable(_ path: Path) -> Bool {
        guard let next = path.first else { Log.fatal(message: "Trying to query isExpandable with empty path") }
        if path.count == 1 {
            guard let model = root.models.first(where: { $0.modelId == next }) else {
                Log.fatal(message: "Missing model")
            }
            return root.isModelExpandable(model)
        } else {
            return findOrCreateNodeAtPath([next]).isPathExpandable(Array(path.dropFirst()))
        }
    }

    func findOrCreateModelCollectionAtPath(_ path: Path) -> NestedModelCollection {
        return findOrCreateNodeAtPath(path).root
    }

    func model(_ path: Path) -> Model {
        guard !path.isEmpty else { Log.fatal(message: "Can't return model for empty path") }
        return findOrCreateNodeAtPath(Array(path.dropLast())).root.models.first(where: { $0.modelId == path.last })!
    }

    private func findOrCreateNodeAtPath(_ path: Path) -> NestedModelCollectionTree {
        guard let next = path.first else { return self }
        let node: NestedModelCollectionTree
        if let result = children[next] {
            node = result
        } else if let model = root.models.first(where: { $0.modelId == next }) {
            let result = NestedModelCollectionTree(root.childModelCollection(model), parent: self)
            children[path[0]] = result
            node = result
        } else {
            Log.fatal(message: "requested nested model collection for non-existent model id")
        }
        return node.findOrCreateNodeAtPath(Array(path.dropFirst()))
    }

    private weak var parent: NestedModelCollectionTree? // todo not used rn, planning on using for propegating updates
    private let root: NestedModelCollection
    private var children = [ModelId: NestedModelCollectionTree]()
}
