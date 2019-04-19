import Foundation
import UIKit

public typealias CommentRow = Comment

public struct ReplySummaryRow {
    var commentId: String
    var replyCount: Int
}

public enum ThreadCellModel {
    case comment(CommentRow)
    case replySummary(ReplySummaryRow)
}

public enum ThreadCellView {
    case comment(CommentView)
    case replySummary(ReplySummaryView)
}

public enum ThreadCellViewModel {
    case comment(CommentViewModel)
    case replySummary(ReplySummaryViewModel)
}

// MARK:

extension ThreadCellView: HostableView {
    public var view: UIView {
        switch self {
        case .comment(let view): return view
        case .replySummary(let view): return view
        }
    }
}

extension ThreadCellViewModel: SelectableViewModel {
    public func handleSelection() {
        switch self {
        case .comment(let vm):
            vm.handleSelection()
        case .replySummary(let vm):
            _ = vm // todo
            break
        }
    }
}

extension ThreadCellViewModel {
    func createView() -> ThreadCellView {
        switch self {
        case .comment: return ThreadCellView.comment(CommentView())
        case .replySummary: return ThreadCellView.replySummary(ReplySummaryView())
        }
    }
}

