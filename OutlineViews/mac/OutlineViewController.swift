import Pilot
import AppKit

open class OutlineViewController: ModelCollectionViewController {

    public init(
        model: ModelCollection,
        modelBinder: ViewModelBindingProvider,
        viewBinder: ViewBindingProvider,
        context: Context
    ) {
        let context = context.newScope()
        self.dataSource = OutlineViewModelDataSource(
            model: model,
            modelBinder: modelBinder,
            viewBinder: viewBinder,
            context: context)
        super.init(model: model, context: context)
    }

    // MARK: Public

    public let outlineView = NSOutlineView()
    public let dataSource: OutlineViewModelDataSource

    // MARK: ModelCollectionViewContoller

    override func makeDocumentView() -> NSView {
        outlineView.wantsLayer = true
        outlineView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        outlineView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        return outlineView
    }

    // MARK: NSViewController

    private let expandyColumn = NSTableColumn(identifier: "ex")
    open override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.addTableColumn(expandyColumn)
        outlineView.outlineTableColumn = expandyColumn
        let column = NSTableColumn(identifier: "fv")
        outlineView.addTableColumn(column)
        outlineView.delegate = dataSource
        outlineView.dataSource = dataSource
        scrollView.scrollerStyle = .overlay
    }
}

public final class OutlineViewModelDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    public init(
        model: ModelCollection,
        modelBinder: ViewModelBindingProvider,
        viewBinder: ViewBindingProvider,
        context: Context
    ) {
        super.init()
    }

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
        guard tableColumn?.identifier == "fv" else { return nil }
        let result: NSTextField
        if let view = outlineView.make(withIdentifier: "fileView", owner: self) as? NSTextField {
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
            result.identifier = "fileView"
        }
        let url = item as? NSURL ?? NSURL(fileURLWithPath: NSHomeDirectory())
        result.stringValue = (url as URL).path
        return result
    }
}
