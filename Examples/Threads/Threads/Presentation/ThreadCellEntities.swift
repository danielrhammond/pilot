import Foundation
import UIKit
import Pilot
import PilotUI

public typealias CommentRow = Comment

public struct ReplySummaryRow: Hashable {
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

extension ThreadCellModel: Diffable {
    public var id: ModelId {
        switch self {
        case .comment(let comment): return comment.id
        case .replySummary(let summary): return summary.commentId + "-replySummary"
        }
    }

    public var version: Int {
        switch self {
        case .comment(let comment): return comment.hashValue
        case .replySummary(let summary): return summary.hashValue
        }
    }
}

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

