import Foundation
import Pilot
import PilotUI

public final class DirectoryViewController: CollectionViewController {

    init(url: URL, context: Context) {
        self.flowLayout = NSCollectionViewFlowLayout()
        super.init(
            model: DirectoryModelCollection(url: url),
            modelBinder: DefaultViewModelBindingProvider(),
            viewBinder: StaticViewBindingProvider(type: FileView.self),
            layout: flowLayout,
            context: context)
    }

    // MARK: NSViewController

    public override func viewDidLayout() {
        super.viewDidLayout()
        flowLayout.itemSize = CGSize(width: view.bounds.width, height: 44)
    }

    // MARK: Private

    private let flowLayout: NSCollectionViewFlowLayout
}
