import Foundation

public enum LoadableResult<T, E> {
    case loaded(T)
    case loading(T?)
    case error(E)
}

extension LoadableResult {
    public var value: T? {
        switch self {
        case .loaded(let result): return result
        case .loading(let result): return result
        case .error: return nil
        }
    }
}
