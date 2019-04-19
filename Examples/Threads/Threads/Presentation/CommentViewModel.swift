import Foundation
import PilotUI
import RxSwift

public struct CommentViewModel: SelectableViewModel {

    public enum Action {
        case delete(String)
        case select(String)
    }

    public init(_ comment: Comment, actionHandler: @escaping (Action) -> Void) {
        self.comment = comment
        self.actionHandler = actionHandler
    }

    public var isReply: Bool { return comment.parentCommentId != nil }
    public var body: String { return comment.body }
    public var actionHandler: (Action) -> Void

    public func handleDeleteButtonTap() {
        actionHandler(.delete(comment.id))
    }

    public func handleSelection() {
        actionHandler(.select(comment.id))
    }

    private let comment: Comment
}
