import AppKit
import Pilot
import PilotUI

public final class FileView: NSView, View {

    // MARK: View

    public init() {
        super.init(frame: .zero)
        loadSubviews()
    }

    public required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var viewModel: ViewModel? { return fileViewModel }

    public func bindToViewModel(_ viewModel: ViewModel) {
        let fileViewModel: FileViewModel = viewModel.typedViewModel()

        filenameLabel.stringValue = fileViewModel.filename

        self.fileViewModel = fileViewModel
    }

    public func unbindFromViewModel() {
        fileViewModel = nil
    }

    // MARK: Private

    private var fileViewModel: FileViewModel?
    private let filenameLabel = NSTextField()

    private func loadSubviews() {
        filenameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(filenameLabel)
        NSLayoutConstraint.activate([
            filenameLabel.topAnchor.constraint(equalTo: topAnchor),
            filenameLabel.leftAnchor.constraint(equalTo: leftAnchor),
            filenameLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            filenameLabel.rightAnchor.constraint(equalTo: rightAnchor),
            ])
    }
}
