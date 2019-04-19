import Foundation
import RxSwift

/// Specialization of a `ModelCollection` that provides support for sections — typically used when mapping to
/// table and collection views, which support sections.
public typealias SectionedModelCollection = Observable<[ModelCollectionState]>

extension ObservableType where E == ModelCollectionState {

    /// If the target type is already a `SectionedModelCollection`, this method does nothing except downcast. Otherwise,
    /// returns a `SectionedModelCollection` with the target `ModelCollection` as the only section.
    public func asSectioned() -> SectionedModelCollection {
        return map { [$0] }
    }
}

public struct ModelCollectionStateFlattenError: Error {
    public var errors: [Error]
}

extension Sequence where Iterator.Element == ModelCollectionState {

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

extension Sequence where Iterator.Element == [Model] {
    /// Convenience method for returning a `[ModelCollectionState]` from a two-dimentional `Model` array.
    public func asSectionedState(loading: Bool = false) -> [ModelCollectionState] {
        return self.map { loading ? .loading($0) : .loaded($0) }
    }
}

/*
extension Collection where Iterator.Element == Model {

    /// Returns sections of `Model` items.
    public var sections: [[Model]] {
        return sectionedState.map { $0.models }
    }

    /// Returns a typed cast of the model value at the given index path, or nil if the model is not of that type or
    /// the index path is out of bounds.
    public func atIndexPath<T>(_ indexPath: IndexPath) -> T? {
        if case sectionedState.indices = indexPath.modelSection {
            let section = sectionedState[indexPath.modelSection]
            if case section.models.indices = indexPath.modelItem {
                if let typed = section.models[indexPath.modelItem] as? T {
                    return typed
                }
            }
        }
        return nil
    }

    /// Returns a typed cast of the model value at the given index path, or nil if the model is not of that type or
    /// the index path is out of bounds.
    public func atModelPath<T>(_ modelPath: ModelPath) -> T? {
        if case sectionedState.indices = modelPath.sectionIndex {
            let section = sectionedState[modelPath.sectionIndex]
            if case section.models.indices = modelPath.itemIndex {
                if let typed = section.models[modelPath.itemIndex] as? T {
                    return typed
                }
            }
        }
        return nil
    }

    /// Returns the index path for the given model id, if present.
    /// - Complexity: O(n)
    public func indexPath(forModelId modelId: ModelId) -> IndexPath? {
        return indexPathOf() { $0.modelId == modelId }
    }

    /// Returns the index path for first item matching the provided closure
    /// - Complexity: O(n)
    public func indexPathOf(matching: (Model) -> Bool) -> IndexPath? {
        for (sectionIdx, section) in self.sectionedState.enumerated() {
            if let itemIdx = section.models.index(where: matching) {
                return IndexPath(forModelItem: itemIdx, inSection: sectionIdx)
            }
        }
        return nil
    }
}
*/

/// Helper struct for flattening `SectionedModelCollection` state.
private struct ModelCollectionStateReduction {
    var notLoadedCount = 0
    var loadingCount = 0
    var loadedCount = 0
    var loadingMoreCount = 0
    var errorArray: [Error] = []
}
