import Foundation
struct RecoveryWindow {
    private(set) var deadline: Date?
    mutating func begin(at now: Date = Date()) { deadline = now.addingTimeInterval(5) }
    mutating func clear() { deadline = nil }
    func remaining(at now: Date = Date()) -> Int { max(0, Int(ceil(deadline?.timeIntervalSince(now) ?? 0))) }
    func canResume(at now: Date = Date()) -> Bool { remaining(at: now) > 0 }
}
