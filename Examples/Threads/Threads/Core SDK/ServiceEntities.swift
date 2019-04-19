import Foundation

public struct ServerThread: Codable {
    var id: String
    var comments: [ServerComment]
}

public struct ServerComment: Codable {
    var id: String
    var parentCommentId: String

    var body: String

    var authorUsername: String
    var authorAvatarURL: URL
}
