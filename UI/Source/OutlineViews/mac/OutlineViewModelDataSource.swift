import AppKit
import Pilot

/// Data source for `OutlineViewController`. This `NSOutlineViewDelegate` conformance is so that the view controller
/// fowards appropriate delegate methods to this data source (allowing for VC subclasses to also see them).
public final class OutlineViewModelDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    public init(
        model: NestedModelCollection,
        columns: [OutlineColumnConfig],
        context: Context
    ) {
        self.treeController = NestedModelCollectionTreeController(modelCollection: model)
        (self.modelBinders, self.viewBinders) = OutlineViewModelDataSource.extractBinders(columns)
        self.context = context

        guard let outlineColumn = columns.first(where: { $0.isOutlineColumn }) else {
            fatalError("Outline views require a primary outline column.")
        }
        outlineModelBinder = outlineColumn.modelBinder

        super.init()
        self.collectionObserver = treeController.observe { [weak self] in
            self?.handleTreeControllerEvent($0)
        }
    }

    public weak var outlineView: NSOutlineView?
    public let context: Context

    public func model(forItem item: Any) -> Model? {
        guard let indexPath = downcast(item) else { return nil }
        return treeController.modelAtPath(indexPath)
    }

    // MARK: NSOutlineViewDataSource

    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        Swift.print("numberOfChildrenOfItem: \(downcast(item) ?? [])")
        return treeController.countOfChildNodes(downcast(item) ?? [])
    }

    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let childId = treeController.modelId(path: downcast(item) ?? [], child: index)
        return ((downcast(item) ?? []) + [childId]).joined(separator: "_-_") as NSString
    }

    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let indexPath = downcast(item) {
            return treeController.isExpandable(indexPath)
        }
        return false
    }

    // MARK: NSOutlineViewDelegate

    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let path = downcast(item) else { return nil }
        guard let identifier = tableColumn?.identifier else {
            Log.error(message: "Group rows not supported by OutlineViewModelDataSource")
            return nil
        }
        guard let viewBinder = viewBinders[identifier], let modelBinder = modelBinders[identifier] else {
            Log.error(message: "Missing binders for column \(identifier)")
            return nil
        }

        let model = treeController.modelAtPath(path)
        let viewModel = modelBinder.viewModel(for: model, context: context)

        var reuse: View?
        let type = viewBinder.viewTypeForViewModel(viewModel, context: context)
        let reuseId = NSUserInterfaceItemIdentifier(String(reflecting: type))
        if let view = outlineView.makeView(withIdentifier: reuseId, owner: self) as? View {
            reuse = view
        }

        let result = viewBinder.view(for: viewModel, context: context, reusing: reuse, layout: nil) as? NSView
        result?.identifier = reuseId
        return result
    }

    // MARK: Internal

    internal func outlineView(_ outlineView: NSOutlineView, menuForEvent event: NSEvent) -> NSMenu? {
        guard
            let location = outlineView.superview?.convert(event.locationInWindow, from: nil),
            let hitItem = outlineView.hitTest(location) as? View,
            let hitViewModel = hitItem.viewModel
        else {
            return nil
        }

        let actions = hitViewModel.secondaryActions(for: .secondaryClick)
        guard !actions.isEmpty else { return nil }
        return NSMenu.fromSecondaryActions(actions, action: #selector(didSelectContextMenuItem(_:)), target: self)
    }

    internal func paths(from rows: IndexSet) -> Set<NestedModelCollectionTreeController.EncodedPath> {
        guard let outlineView = outlineView else { return [] }
        var pathSet: Set<NestedModelCollectionTreeController.EncodedPath> = []
        for row in rows {
            if let path = downcast(outlineView.item(atRow: row)) {
                pathSet.insert(path.joined(separator: "_-_"))
            }
        }
        return pathSet
    }

    internal func selectionViewModel(
        for paths: Set<NestedModelCollectionTreeController.EncodedPath>
    ) -> SelectionViewModel? {
        let models = paths.map { treeController.modelAtPath($0.components(separatedBy: "_-_")) }
        return outlineModelBinder.selectionViewModel(for: models, context: context)
    }

    // MARK: Private

    private var collectionObserver: Observer?
    private var diffEngine = DiffEngine()
    private let treeController: NestedModelCollectionTreeController
    private let viewBinders: [NSUserInterfaceItemIdentifier: ViewBindingProvider]
    private let modelBinders: [NSUserInterfaceItemIdentifier: ViewModelBindingProvider]

    // The model binder from the `outlineTableColumn` column — used for binding in situations
    // that aren't tied to a specific column (e.g. selection state binding).
    private let outlineModelBinder: ViewModelBindingProvider

    /// Responsible for taking a tree controller event and turnin it into NSOutlineView updates.
    private func handleTreeControllerEvent(_ event: NestedModelCollectionTreeController.Event) {
        guard let outlineView = outlineView else { return }

        // Group the updates based on index path of their parent, and filter out ones that are not visible.

        Swift.print("OV event remvoed: \(event.removed.count) added: \(event.added.count) updated: \(event.updated.count)")
        Swift.print("OV.event.updated \(event.updated.map({ $0 as IndexPath }))")


        let removedByItem = Dictionary(grouping: event.removed, by: { $0.dropLast() as IndexPath })
        let addedByItem = Dictionary(grouping: event.added, by: { $0.dropLast() as IndexPath })
        let updatedItems = event.updated.map { $0 as IndexPath }

        Swift.print("OV update remvoed: \(removedByItem.count) added: \(addedByItem.count) updated: \(updatedItems.count)")

        guard !removedByItem.isEmpty || !addedByItem.isEmpty || !updatedItems.isEmpty else {
            return
        }

        // TODO:(danielh) Configuaration options for animations.
        let options = NSTableView.AnimationOptions.effectFade

        outlineView.beginUpdates()

        for (indexPath, removed) in removedByItem {
            #if swift(>=4.1)
                let indexSet = IndexSet(removed.compactMap({ $0.last }))
            #else
                let indexSet = IndexSet(removed.flatMap({ $0.last }))
            #endif

            if indexPath.isEmpty {
                Swift.print("Removing \(indexSet) inRoot")
                outlineView.removeItems(at: indexSet, inParent: nil, withAnimation: options)
            } else {
                Swift.print("Removing \(indexSet) in \(indexPath)")
                let parent = treeController.path(indexPath).joined(separator: "_-_")
                outlineView.removeItems(at: indexSet, inParent: parent as NSString, withAnimation: options)
            }
        }
        
        for (indexPath, added) in addedByItem {
            #if swift(>=4.1)
                let indexSet = IndexSet(added.compactMap({ $0.last }))
            #else
                let indexSet = IndexSet(added.flatMap({ $0.last }))
            #endif
            if indexPath.isEmpty {
                Swift.print("Adding \(indexSet) inRoot")
                outlineView.insertItems(at: indexSet, inParent: nil, withAnimation: options)
            } else {
                Swift.print("Adding \(indexSet) in \(indexPath)")
                let parent = treeController.path(indexPath).joined(separator: "_-_")
                outlineView.insertItems(at: indexSet, inParent: parent as NSString, withAnimation: options)
            }
        }

        for updated in updatedItems {
            Swift.print("Reloading \(updated)")
            let item = treeController.path(updated).joined(separator: "_-_")
            outlineView.reloadItem(item as NSString)
        }

        outlineView.endUpdates()
    }

    @objc
    private func didSelectContextMenuItem(_ menuItem: NSMenuItem) {
        guard let action = menuItem.representedAction else {
            Log.warning(message: "No action attached to secondary action menu item: \(menuItem)")
            return
        }
        action.send(from: context)
    }

    private func downcast(_ item: Any?) -> NestedModelCollectionTreeController.Path? {
        if let item = item as? String {
            return item.components(separatedBy: "_-_")
        }
        if item != nil {
            Log.fatal(message: "Unexpected item returned from NSOutlineView \(String(reflecting: item))")
        }
        return nil
    }

    private typealias Identifier = NSUserInterfaceItemIdentifier
    private static func extractBinders(
        _ configs: [OutlineColumnConfig]
    ) -> ([Identifier: ViewModelBindingProvider], [Identifier: ViewBindingProvider]) {
        var modelBinders = [Identifier: ViewModelBindingProvider]()
        var viewBinders = [Identifier: ViewBindingProvider]()
        for config in configs {
            modelBinders[config.column.identifier] = config.modelBinder
            viewBinders[config.column.identifier] = config.viewBinder
        }
        return (modelBinders, viewBinders)
    }
}
