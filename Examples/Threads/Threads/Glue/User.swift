import Foundation

public struct User {
    public var username: String
    public var avatarURL: URL

    public init(username: String) {
        self.username = username
        let avatarSlug = 200 + username.hashValue % 100
        self.avatarURL = URL(string: "https://placebear.com/\(avatarSlug)/\(avatarSlug)")!
    }
}
