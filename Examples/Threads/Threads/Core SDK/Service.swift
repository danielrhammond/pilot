import Foundation
import RxSwift

public protocol CommentService {
    func fetchThread(id: String) -> Single<ServerThread>
    func postComment(parentId: String, body: String, authorUsername: String, authorAvatarURL: URL) -> Single<ServerComment>
    func deleteComment(id: String) -> Single<Void>
}

private var databaseURL: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    .first?
    .appendingPathComponent("database")

public final class LocalOnlyService: CommentService {

    init() {
        let decoder = PropertyListDecoder()
        if
            let database = databaseURL,
            let data = try? Data(contentsOf: database),
            let thread = try? decoder.decode([ServerComment].self, from: data)
        {
            self.database = thread
        } else {
            self.database = [ServerComment]()
        }
    }

    public func fetchThread(id: String) -> Single<ServerThread> {
        return Single.create { (resolve) in
            let disposable = BooleanDisposable()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
                guard !disposable.isDisposed else { return }
                let thread = ServerThread(id: id, comments: self.database.filter({ $0.parentCommentId == id }))
                resolve(.success(thread))
            })
            return disposable
        }
    }

    public func postComment(parentId: String, body: String, authorUsername: String, authorAvatarURL: URL) -> Single<ServerComment> {
        return Single.create { (resolve) in
            let disposable = BooleanDisposable()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
                guard !disposable.isDisposed else { return }
                let newComment = ServerComment(
                    id: UUID().uuidString,
                    parentCommentId: parentId,
                    body: body,
                    authorUsername: authorUsername,
                    authorAvatarURL: authorAvatarURL)
                var thread = self.database
                thread.append(newComment)
                self.database = thread
                resolve(.success(newComment))
            })
            return disposable
        }
    }

    public func deleteComment(id: String) -> Single<Void> {
        return Single.create { (resolve) in
            let disposable = BooleanDisposable()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: {
                guard !disposable.isDisposed else { return }
                var thread = self.database
                thread = thread.filter({ $0.id != id })
                self.database = thread
                resolve(.success(()))
            })
            return disposable
        }
    }

    private var database: [ServerComment] {
        didSet {
            if let databaseURL = databaseURL, let data = try? PropertyListEncoder().encode(database) {
                _ = try? data.write(to: databaseURL)
            }
        }
    }
}
