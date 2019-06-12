import Foundation

public struct SyncedComment: Hashable {
    var id: String
    var parentCommentId: String

    var body: String

    var authorUsername: String
    var authorAvatarURL: URL
}

extension SyncedComment {
    static func fromServerComment(_ comment: ServerComment) -> SyncedComment {
        return SyncedComment(
            id: comment.id,
            parentCommentId: comment.parentCommentId,
            body: comment.body,
            authorUsername: comment.authorUsername,
            authorAvatarURL: comment.authorAvatarURL)
    }
}

public struct OptimisticComment: Hashable {
    enum State {
        case syncing
        case failed(Error)
    }

    var id: String
    var parentCommentId: String
    var body: String
    var authorUsername: String
    var authorAvatarURL: URL
}

public enum Comment: Hashable {
    case synced(SyncedComment)
    case optimistic(OptimisticComment)

    var id: String {
        switch self {
        case .synced(let comment): return comment.id
        case .optimistic(let comment): return comment.id
        }
    }

    var parentCommentId: String? {
        switch self {
        case .synced(let comment): return comment.parentCommentId
        case .optimistic(let comment): return comment.parentCommentId
        }
    }

    var body: String {
        switch self {
        case .synced(let comment): return comment.body
        case .optimistic(let comment): return comment.body
        }
    }
}
