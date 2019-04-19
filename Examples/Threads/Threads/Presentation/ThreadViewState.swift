import Foundation
import Pilot
import PilotUI
import RxSwift

public struct ThreadViewState: ViewState {
    public var entries: LoadableResult<[Comment], Error>
}

public struct ThreadViewModel {

    public enum ViewModelAction {
        case postReply(String)
        case deleteComment(String)
    }

    public init(state: ThreadViewState, actionHandler: @escaping (ViewModelAction) -> Void) {
        self.init(state: state, actionHandler: actionHandler, replyBody: "")
    }

    private init(state: ThreadViewState, actionHandler: @escaping (ViewModelAction) -> Void, replyBody: String) {
        self.state = state
        self.actionHandler = actionHandler
        self.replyFieldBody = BehaviorSubject(value: replyBody)
    }

    public func applyingState(
        _ state: ThreadViewState
    ) -> ThreadViewModel {
        return ThreadViewModel(
            state: state,
            actionHandler: actionHandler,
            replyBody: try! replyFieldBody.value())
    }

    // MARK:

    public var entries: [ThreadCellModel] {
        let comments: [Comment]
        switch state.entries {
        case .loaded(let result): comments = result
        case .loading(let result): comments = result ?? []
        case .error: comments = []
        }
        return comments.map(ThreadCellModel.comment)
    }

    public var showLoadingIndicator: Bool {
        switch state.entries {
        case .loaded, .error: return false
        case .loading(let results): return results == nil
        }
    }

    // Behaves as RxCocoa.Driver
    public var replyButtonEnabled: Observable<Bool> {
        return replyFieldBody
            .asObservable()
            .map { !$0.isEmpty }
            .observeOn(MainScheduler.instance)
    }

    public func updateReplyFieldBody(_ body: String) {
        replyFieldBody.onNext(body)
    }

    public func sendReply() {
        actionHandler(.postReply(try! replyFieldBody.value()))
        replyFieldBody.onNext("")
    }

    // MARK:

    private var replyFieldBody = BehaviorSubject(value: "")
    private let state: ThreadViewState
    private var actionHandler: (ViewModelAction) -> Void
}
