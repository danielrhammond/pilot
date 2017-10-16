import Foundation
import Pilot

public extension NSEvent {

    /// Returns a semantic `EventKeyCode` value (or .Unknown) for the target event.
    public var eventKeyCode: EventKeyCode {
        return EventKeyCode(rawValue: keyCode) ?? .unknown
    }

    public var eventKeyModifierFlags: EventKeyModifierFlags {
        var result = EventKeyModifierFlags(rawValue: 0)
        if modifierFlags.contains(.capsLock) {
            result.formUnion(.capsLock)
        }
        if modifierFlags.contains(.command) {
            result.formUnion(.command)
        }
        if modifierFlags.contains(.control) {
            result.formUnion(.control)
        }
        if modifierFlags.contains(.function) {
            result.formUnion(.function)
        }
        if modifierFlags.contains(.option) {
            result.formUnion(.option)
        }
        if modifierFlags.contains(.shift) {
            result.formUnion(.shift)
        }
        return result
    }
}
