import Foundation
import RxSwift

public enum ThreadNavigationAction {
    case selectThread(id: String)
}

protocol ThreadInteractor {
    var thread: Observable<LoadableResult<[Comment], Error>> { get }
    func navigate(_: ThreadNavigationAction)
    func deleteComment(id: String)
    func postComment(parentId: String?, body: String)
}
