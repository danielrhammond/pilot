import Foundation
import RxSwift

public final class ThreadInteractorImpl: ThreadInteractor {

    public init(threadId: String, repository: ThreadRepository, currentUser: User, navigationHandler: @escaping (ThreadNavigationAction) -> Void) {
        self.threadId = threadId
        self.repository = repository
        self.currentUser = currentUser
        self.threadNavigationHandler = navigationHandler
    }

    var thread: Observable<LoadableResult<[Comment], Error>> {
        return repository.comments(threadId)
    }

    func deleteComment(id: String) {
        repository.deleteComment(id: id)
    }

    func postComment(parentId: String?, body: String) {
        repository.postComment(
            parentId ?? threadId,
            body: body,
            authorUsername: currentUser.username,
            authorAvatar: currentUser.avatarURL)
    }

    func navigate(_ navigation: ThreadNavigationAction) {
        threadNavigationHandler(navigation)
    }

    private let threadNavigationHandler: (ThreadNavigationAction) -> Void
    private let threadId: String
    private let repository: ThreadRepository
    private let currentUser: User
}
