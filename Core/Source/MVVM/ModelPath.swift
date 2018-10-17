/// IndexPath is too expensive (given it contains an NSArray) for what really is just two indices, so we pass these simple ModelPath pairs
/// around.  `sectionIndex` is the index of the section and `itemIndex` is the index of the model in the corresponding section.
public struct ModelPath: Equatable, Hashable {
    public init(sectionIndex: Int, itemIndex: Int) {
        self.sectionIndex = sectionIndex
        self.itemIndex = itemIndex
    }

    public init(_ sectionIndex: Int, _ itemIndex: Int) {
        self.init(sectionIndex: sectionIndex, itemIndex: itemIndex)
    }

    public var sectionIndex: Int
    public var itemIndex: Int

    // MARK: Hashable

    public var hashValue: Int {
        return sectionIndex.hashValue ^ itemIndex.hashValue
    }
}

public func ==(lhs: ModelPath, rhs: ModelPath) -> Bool {
    return lhs.sectionIndex == rhs.sectionIndex && lhs.itemIndex == rhs.itemIndex
}

public func <(lhs: ModelPath, rhs: ModelPath) -> Bool {
    if lhs.sectionIndex < rhs.sectionIndex {
        return true
    } else if lhs.sectionIndex > rhs.sectionIndex {
        return false
    } else {
        return lhs.itemIndex < rhs.itemIndex
    }
}

public extension ModelPath {
    public var indexPath: IndexPath {
        return IndexPath(indexes: [sectionIndex, itemIndex])
    }
}

public extension IndexPath {
    public var modelPath: ModelPath {
        return ModelPath(sectionIndex: self[0], itemIndex: self[1])
    }
}

/// Named tuples don't automatically implement Equatable so do it manually.
public struct MovedModel: Equatable {
    public var from: ModelPath
    public var to: ModelPath

    public init(from: ModelPath, to: ModelPath) {
        self.from = from
        self.to = to
    }
}

public func ==(lhs: MovedModel, rhs: MovedModel) -> Bool {
    return lhs.from == rhs.from && lhs.to == rhs.to
}

// Pilot does not depend on UIKit, so redefine similar section/item accessors and initializers here.
public extension IndexPath {
    public var modelSection: Int {
        return self[0]
    }
    public var modelItem: Int {
        return self[1]
    }
    public init(forModelItem modelItem: Int, inSection modelSection: Int) {
        self.init(indexes: [modelSection, modelItem])
    }
}
