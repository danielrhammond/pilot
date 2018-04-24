import AppKit
import Pilot

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

    public final override func makeScrollView() -> NSScrollView {
        // TODO:(danielh) Investigate why NSOutlineView doesn't isn't compatible w/ NestableScrollView.
        return NSScrollView()
    }

    public final override func makeDocumentView() -> NSView {
        outlineView.wantsLayer = true
        outlineView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        outlineView.autoresizingMask = [.width, .height]
        return outlineView
    }

    // MARK: NSViewController

    private let expandyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ev"))
    private let filenameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fv"))
    open override func viewDidLoad() {
        super.viewDidLoad()
        expandyColumn.width = outlineView.indentationPerLevel
        expandyColumn.resizingMask = .autoresizingMask
        //outlineView.addTableColumn(expandyColumn)
        outlineView.addTableColumn(filenameColumn)
        outlineView.outlineTableColumn = filenameColumn
        outlineView.autoresizesOutlineColumn = true
        outlineView.delegate = dataSource
        outlineView.dataSource = dataSource
        scrollView.scrollerStyle = .overlay
    }
}
