import Foundation
import RxSwift

public protocol ThreadRepository {
    func comments(_ threadId: String) -> Observable<LoadableResult<[Comment], Error>>
    func postComment(_ parentId: String, body: String, authorUsername: String, authorAvatar: URL)
    func deleteComment(id: String)
}
