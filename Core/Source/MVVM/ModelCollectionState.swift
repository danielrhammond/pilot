/// Possible states for a `ModelCollection`. These states are typically used only for reference-type implementations
/// of `ModelCollection` since value-type implementations will typically always be `Loaded`.
public enum ModelCollectionState {
    /// The model collection is instantiated but has not yet attempted to load data.
    case notLoaded

    /// The model collection is loading content, models will be nil if loading for the first time.
    case loading([Model]?)

    /// The model collection has successfully loaded data.
    case loaded([Model])

    /// The model collection encountered an error loading data.
    case error(Error)

    /// Unpacks and returns any associated model models.
    public var models: [Model] {
        switch self {
        case .notLoaded, .error:
            return []
        case .loading(let models):
            return models ?? []
        case .loaded(let models):
            return models
        }
    }

    /// Returns whether or not the underlying enum case is different than the target. Ignores associated model
    /// objects.
    public func isDifferentCase(than other: ModelCollectionState) -> Bool {
        switch (self, other) {
        case (.notLoaded, .notLoaded),
             (.loading(_), .loading(_)),
             (.loaded(_), .loaded(_)),
             (.error(_), .error(_)):
            return false
        default:
            return true
        }
    }
}

// MARK: Common helper methods.

extension ModelCollectionState {
    public var isNotLoaded: Bool {
        if case .notLoaded = self { return true }
        return false
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    public var isEmpty: Bool {
        switch self {
        case .notLoaded, .error:
            return true
        case .loading(let models):
            guard let models = models else { return true }
            return models.isEmpty
        case .loaded(let models):
            return models.isEmpty
        }
    }
}

extension ModelCollectionState: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .notLoaded:
            return ".notLoaded"
        case .error(let e):
            return ".error(\(String(reflecting: e)))"
        case .loading(let models):
            return ".loading(\(describe(models: models)))"
        case .loaded(let models):
            return ".loaded(\(describe(models: models)))"
        }
    }

    private func describe(models: [Model]?) -> String {
        guard let models = models else { return "nil" }
        return "[\(models.count) Models]"
    }
}

// MARK: Sections

public struct ModelCollectionStateFlattenError: Error {
    public var errors: [Error]
}

public extension Sequence where Iterator.Element == ModelCollectionState {

    /// Common implementation to transform `[ModelCollectionState] -> ModelCollectionState`. Typically used by
    /// `SectionedModelCollection` implementations when they need to return a single representative
    /// `ModelCollectionState`.
    public func flattenedState() -> ModelCollectionState {
        var count = 0
        var consolidatedModels: [Model] = []
        var reducedStates = ModelCollectionStateReduction()
        for substate in self {
            count += 1
            consolidatedModels += substate.models

            switch substate {
            case .notLoaded:
                reducedStates.notLoadedCount += 1
            case .loaded:
                reducedStates.loadedCount += 1
            case .error(let error):
                reducedStates.errorArray.append(error)
            case .loading(let models):
                if models == nil {
                    reducedStates.loadingCount += 1
                } else {
                    reducedStates.loadingMoreCount += 1
                }
            }
        }

        if !reducedStates.errorArray.isEmpty {
            let error = ModelCollectionStateFlattenError(errors: reducedStates.errorArray)
            return .error(error)
        } else if reducedStates.notLoadedCount == count {
            return .notLoaded
        } else if reducedStates.loadedCount == count {
            return .loaded(consolidatedModels)
        } else if reducedStates.loadingCount + reducedStates.notLoadedCount == count {
            return .loading(nil)
        } else {
            return .loading(consolidatedModels)
        }
    }
}

public extension Sequence where Iterator.Element == [Model] {
    /// Convenience method for returning a `[ModelCollectionState]` from a two-dimentional `Model` array.
    public func asSectionedState(loading: Bool = false) -> [ModelCollectionState] {
        return self.map { loading ? .loading($0) : .loaded($0) }
    }
}

/// Helper struct for flattening `SectionedModelCollection` state.
private struct ModelCollectionStateReduction {
    var notLoadedCount = 0
    var loadingCount = 0
    var loadedCount = 0
    var loadingMoreCount = 0
    var errorArray: [Error] = []
}
