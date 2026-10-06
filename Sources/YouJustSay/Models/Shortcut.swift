import Foundation
import CoreGraphics

struct Shortcut: Codable, Equatable {
    var keyCode: Int64?
    var modifiers: UInt64
    var keyName: String
    static let fn = Shortcut(keyCode: nil, modifiers: CGEventFlags.maskSecondaryFn.rawValue, keyName: "")
    static let allowedFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn]
    var display: String {
        let flags = CGEventFlags(rawValue: modifiers)
        var parts: [String] = []
        for (flag, name): (CGEventFlags, String) in [(.maskControl, "⌃"), (.maskAlternate, "⌥"), (.maskShift, "⇧"), (.maskCommand, "⌘"), (.maskSecondaryFn, "Fn")] {
            if flags.contains(flag) { parts.append(name) }
        }
        if keyCode != nil { parts.append(keyName) }
        return parts.joined(separator: " + ")
    }
    func matches(flags: CGEventFlags) -> Bool { flags.intersection(Self.allowedFlags).rawValue == modifiers }
    var isReserved: Bool { keyCode == 1 && modifiers == CGEventFlags([.maskControl, .maskAlternate, .maskCommand]).rawValue }
}
