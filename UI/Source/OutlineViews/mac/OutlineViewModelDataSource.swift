import AppKit
import Pilot

public final class OutlineViewModelDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    public init(
        model: ModelCollection,
        modelBinder: ViewModelBindingProvider,
        viewBinder: ViewBindingProvider,
        context: Context
    ) {
        self.model = model
        super.init()
        self.collectionObserver = model.observe { [weak self] in
            self?.handleCollectionEvent($0)
        }
    }

    public weak var outlineView: NSOutlineView?

    // MARK: NSOutlineViewDataSource

    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let url = item as? NSURL ?? NSURL(fileURLWithPath: NSHomeDirectory())
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path!, isDirectory: &isDir)
        guard isDir.boolValue else { return 0 }
        let result = try! FileManager.default.contentsOfDirectory(atPath: url.path!).count
        Swift.print("item \(String(describing: item)) numChildren: \(result)")
        return result
    }

    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let url = item as? NSURL ?? NSURL(fileURLWithPath: NSHomeDirectory())
        let path = try! FileManager.default.contentsOfDirectory(atPath: url.path!).sorted()[index]
        return url.appendingPathComponent(path)!
    }

    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        let url = item as? NSURL ?? NSURL(fileURLWithPath: NSHomeDirectory())
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path!, isDirectory: &isDir)
        return isDir.boolValue
    }

    // MARK: NSOutlineViewDelegate

    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard tableColumn?.identifier.rawValue == "fv" else { return nil }
        let result: NSTextField
        if let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("fileView"), owner: self) as? NSTextField {
            Swift.print("\(Unmanaged.passUnretained(view).toOpaque()) reusing")
            result = view
        } else {
            result = NSTextField(frame: .zero)
            result.drawsBackground = false
            result.isBezeled = false
            result.isBordered = false
            result.isEditable = false
            result.font = NSFont.systemFont(ofSize: 12)
            Swift.print("\(Unmanaged.passUnretained(result).toOpaque()) creating")
            result.identifier = NSUserInterfaceItemIdentifier("fileView")
        }
        let url = item as? NSURL ?? NSURL(fileURLWithPath: NSHomeDirectory())
        result.stringValue = (url as URL).path
        return result
    }

    // MARK: Private
    private var collectionObserver: Observer?
    private var diffEngine = DiffEngine()
    private let model: ModelCollection

    private func handleCollectionEvent(_ event: CollectionEvent) {
        outlineView?.reloadData()
    }
}
