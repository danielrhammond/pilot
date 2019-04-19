import Foundation
import RxSwift

public final class ThreadRepositoryImpl: ThreadRepository {

    public init(client: CommentService) {
        self.client = client
    }

    public func comments(_ threadId: String) -> Observable<LoadableResult<[Comment], Error>> {
        return Observable.create { (sub) in
            // todo move to helper function, handle multiple requests + loading more state

            let networkDisposable = self.client
                .fetchThread(id: threadId)
                .map { (thread) -> LoadableResult<[SyncedComment], Error> in
                    .loaded(thread.comments.map(SyncedComment.fromServerComment(_:)))
                }
                .asObservable()
                .catchError({ return Observable<LoadableResult<[SyncedComment], Error>>.just(.error($0)) })
                .concat(Observable.never())
                .subscribe(self.syncedComments.asObserver())

            // todo handle optimistic local, then combine

            let combinedDisposable = Observable<LoadableResult<[Comment], Error>>
                .combineLatest(self.syncedComments, self.optimisticDeletedCommentIdsSubject) { (serverResult, deleted) in
                    let f: ([SyncedComment]) -> [Comment] = {
                        $0.filter({ !deleted.contains($0.id) }).map({ .synced($0) })
                    }
                    switch serverResult {
                    case .loaded(let comments):
                        return .loaded(f(comments))
                    case .loading(let comments):
                        return .loading(comments.flatMap(f))
                    case .error(let e): return .error(e)
                    }
                }
                .subscribe(sub)

            return CompositeDisposable(networkDisposable, combinedDisposable)
        }
    }

    public func postComment(_ parentId: String, body: String, authorUsername: String, authorAvatar: URL) {
        _ = client
            .postComment(parentId: parentId, body: body, authorUsername: authorUsername, authorAvatarURL: authorAvatar)
            .subscribe({ result in
                switch result {
                case .error:
                    break // todo when optimistic is supported flag as failed
                case .success(let comment):
                    // toddo handle other cases
                    if case .some(.loaded(var existingComments)) = try? self.syncedComments.value() {
                        existingComments.append(SyncedComment.fromServerComment(comment))
                        self.syncedComments.onNext(.loaded(existingComments))
                    }
                }
            })
    }

    public func deleteComment(id: String) {
        optimisticDeletedCommentIds.insert(id)
        _ = client.deleteComment(id: id)
            .subscribe(onSuccess: {
                // toddo handle other cases
                if case .some(.loaded(var existingComments)) = try? self.syncedComments.value() {
                    existingComments = existingComments.filter({ $0.id != id })
                    self.syncedComments.onNext(.loaded(existingComments))
                }
                self.optimisticDeletedCommentIds.remove(id)
            }, onError: { _ in
                print("ERROR deleting comment \(id)")
                self.optimisticDeletedCommentIds.remove(id)
            })
    }

    private var optimisticDeletedCommentIds = Set<String>() {
        didSet {
            optimisticDeletedCommentIdsSubject.onNext(optimisticDeletedCommentIds)
        }
    }
    private let optimisticDeletedCommentIdsSubject = BehaviorSubject<Set<String>>(value: [])
    private let disposeBag = DisposeBag()
    private let syncedComments = BehaviorSubject<LoadableResult<[SyncedComment], Error>>(value: .loading(nil))
    private let client: CommentService
}
