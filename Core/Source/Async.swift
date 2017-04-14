import Foundation

/// Issue a precondition failure if we are not currently running on the specified queue, at least as far as we can
/// distinguish via its label.
public func preconditionOnQueue(_ queue: DispatchQueue) {
    if #available(iOS 10, OSX 10.12, *) {
        dispatchPrecondition(condition: .onQueue(queue))
    }
}

/// Convenience type wrapping common asynchronous dispatch queue operations. Single operations are supported:
/// ```swift
/// Async.onBackground {
///     // Do work...
/// }
/// ```
///
/// And dependent-chaining is supported:
/// ```swift
/// Async.onBackground {
///     // Do 'work 1'.
/// }.onMain {
///     // This will happen after 'work 1' on the main thread.
/// }
/// ```
public struct Async {

    // MARK: Static Convenience Methods

    @discardableResult
    public static func onMain(_ block: @escaping ()->()) -> Async {
        return dispatch(queue: .main, block: block)
    }

    @discardableResult
    public static func onUserInteractive(_ block: @escaping ()->()) -> Async {
        return dispatch(queue: .global(qos: .userInteractive), block: block)
    }

    @discardableResult
    public static func onUserInitiated(_ block: @escaping ()->()) -> Async {
        return dispatch(queue: .global(qos: .userInitiated), block: block)
    }

    @discardableResult
    public static func onUtility(_ block: @escaping ()->()) -> Async {
        return dispatch(queue: .global(qos: .utility), block: block)
    }

    @discardableResult
    public static func onBackground(_ block: @escaping ()->()) -> Async {
        return dispatch(queue: .global(qos: .background), block: block)
    }

    @discardableResult
    public static func on(_ customQueue: DispatchQueue, block: @escaping ()->()) -> Async {
        return dispatch(queue: customQueue, block: block)
    }

    @discardableResult
    public static func on(_ queue: DispatchQueue, waitingFor group: DispatchGroup, block: @escaping ()->()) -> Async {
        return dispatchWaitingFor(dispatchGroup: group, dispatchQueue: queue, block)
    }

    // MARK: Chained Convenience Methods

    @discardableResult
    public func onMain(_ block: @escaping ()->()) -> Async {
        return dispatchDependentBlock(block, queue: .main)
    }

    @discardableResult
    public func onUserInteractive(_ block: @escaping ()->()) -> Async {
        return dispatchDependentBlock(block, queue: .global(qos: .userInteractive))
    }

    @discardableResult
    public func onUserInitiated(_ block: @escaping ()->()) -> Async {
        return dispatchDependentBlock(block, queue: .global(qos: .userInitiated))
    }

    @discardableResult
    public func onUtility(_ block: @escaping ()->()) -> Async {
        return dispatchDependentBlock(block, queue: .global(qos: .utility))
    }

    @discardableResult
    public func onBackground(_ block: @escaping ()->()) -> Async {
        return dispatchDependentBlock(block, queue: .global(qos: .background))
    }

    @discardableResult
    public func on(_ customQueue: DispatchQueue, block: @escaping ()->()) -> Async {
        return dispatchDependentBlock(block, queue: customQueue)
    }

    // MARK: Private

    private let workItem: DispatchWorkItem

    private init(_ block: @escaping ()->()) {
        self.workItem = DispatchWorkItem(block: block)
    }

    private init(_ workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    private static func dispatch(queue: DispatchQueue, block: @escaping ()->()) -> Async {
        let item = DispatchWorkItem(qos: .default, flags: .inheritQoS, block: block)
        queue.async(execute: item)
        return Async(item)
    }

    private func dispatchDependentBlock(_ dependentBlock: @escaping ()->(), queue: DispatchQueue) -> Async {
        let notifyItem = DispatchWorkItem(qos: .default, flags: .inheritQoS, block: dependentBlock)
        workItem.notify(queue: queue, execute: notifyItem)
        return Async(notifyItem)
    }

    private static func dispatchWaitingFor(
        dispatchGroup: DispatchGroup,
        dispatchQueue: DispatchQueue,
        _ dependentBlock: @escaping ()->()
    ) -> Async {
        let notifyItem = DispatchWorkItem(qos: .default, flags: .inheritQoS, block: dependentBlock)
        dispatchGroup.notify(queue: dispatchQueue, work: notifyItem)
        return Async(notifyItem)
    }
}

/// Async helper functions.
public extension Async {

    /// Creates and returns a new debounced version of the passed `block` which will postpone its execution until after
    /// `wait` milliseconds have elapsed since the last time it was invoked. Useful for implementing behavior that
    /// should only happen after the input has stopped arriving. For example: rendering a preview of a Markdown comment,
    /// recalculating a layout after the window has stopped being resized, and so on.
    ///
    /// Example:
    ///
    /// ```
    /// userDidEnterText = debounce(wait: .milliseconds(100)) { renderPreview() }
    /// ```
    ///
    /// NOTE: This method must be called on the main thread.
    public static func debounce(wait interval: DispatchTimeInterval, block: @escaping () -> Void) -> () -> Void {
        precondition(Thread.isMainThread)

        var lastWorkItem: DispatchWorkItem?
        return {
            lastWorkItem?.cancel()
            let time: DispatchTime = DispatchTime.now()
            let nextWorkItem = DispatchWorkItem { lastWorkItem = nil; block() }
            DispatchQueue.main.asyncAfter(deadline: time, execute: nextWorkItem)
            lastWorkItem = nextWorkItem
        }
    }

    /// Creates and returns a new, throttled version of the passed `block`, that, when invoked repeatedly, will only
    /// call the original closure at most once per every `wait` milliseconds. Useful for rate-limiting events that
    /// occur faster than you can keep up with.
    ///
    /// Example:
    ///
    /// ```
    /// didRecieveLocationEvent = throttle(wait: .milliseconds(100)) { updateMapPosition() }
    /// ```
    ///
    /// NOTE: This method must be called on the main thread.
    public static func throttle(wait interval: DispatchTimeInterval, block: @escaping () -> Void) -> () -> Void {
        precondition(Thread.isMainThread)

        var resetThrottle: DispatchWorkItem?
        return {
            guard resetThrottle == nil else { return }
            DispatchQueue.main.async {
                let time: DispatchTime = DispatchTime.now() + interval
                let reset = DispatchWorkItem { resetThrottle = nil }
                resetThrottle = reset
                DispatchQueue.main.asyncAfter(deadline: time, execute: reset)
                block()
            }
        }
    }

    /// Creates a version of `block` that, when invoked repetedly with a collection, batches provided arguments.
    /// Batching is done using a reducer, and `block` will be called on the provided time interval (after it is called
    /// with some argument).
    /// - Note: The provided queue must be serial.
    public static func coalesce<T>(
        coalesceTime: DispatchTimeInterval,
        queue: DispatchQueue = .main,
        reducer: @escaping (T, T) -> T,
        block: @escaping (T) -> Void
    ) -> (T) -> Void {
        /// Contains the batched argument constructed so far.
        var batchedArgument: T?
        return { value in
            queue.async {
                let firstValueSinceFlush = (batchedArgument == nil)

                if let batchedArgumentUnwrapped = batchedArgument {
                    batchedArgument = reducer(batchedArgumentUnwrapped, value)
                } else {
                    batchedArgument = value
                }

                if firstValueSinceFlush {
                    let time: DispatchTime = DispatchTime.now() + coalesceTime

                    queue.asyncAfter(deadline: time, execute: DispatchWorkItem {
                        guard let unwrappedBatchedArgument: T = batchedArgument else {
                            preconditionFailure("Shouldn't have started a timer if there wasn't a set argument.")
                        }

                        block(unwrappedBatchedArgument)
                        batchedArgument = nil
                    })
                }
            }
        }
    }

    /// A wrapper around the coalesce function above. Handles the common case of coalescing a list of items.
    /// - Note: The provided queue must be serial.
    public static func coalesce<T>(
        coalesceTime: DispatchTimeInterval,
        queue: DispatchQueue = .main,
        block: @escaping ([T]) -> Void
    ) -> ([T]) -> Void {
        return coalesce(coalesceTime: coalesceTime, queue: queue, reducer: +, block: block)
    }

    /// A wrapper around the coalesce function above. Handles the common case of coalescing a set of items.
    /// - Note: The provided queue must be serial.
    public static func coalesce<T>(
        coalesceTime: DispatchTimeInterval,
        queue: DispatchQueue = .main,
        block: @escaping (Set<T>) -> Void
    ) -> (Set<T>) -> Void {
        let reducer = { (a: Set<T>, b: Set<T>) -> Set<T> in
            return a.union(b)
        }
        return coalesce(coalesceTime: coalesceTime, queue: queue, reducer: reducer, block: block)
    }
}
