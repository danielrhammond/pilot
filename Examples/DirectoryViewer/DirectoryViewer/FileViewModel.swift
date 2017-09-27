import Pilot

public struct FileViewModel: ViewModel {

    public init(model: Model, context: Context) {
        self.file = model.typedModel()
        self.context = context
    }

    public var filename: String {
        return file.url.lastPathComponent
    }

    // MARK: ViewModel
    
    public let context: Context
    private let file: File
}

extension File: ViewModelConvertible {
    public func viewModelWithContext(_ context: Context) -> ViewModel {
        return FileViewModel(model: self, context: context)
    }
}
