import Foundation

struct AudioWaveform {
    private(set) var samples = Array(repeating: 0.0, count: 19)
    mutating func append(_ level: Double) {
        samples.removeFirst()
        samples.append(level.isFinite ? min(1, max(0, level)) : 0)
    }
    static func normalized(decibels: Double) -> Double {
        guard decibels.isFinite else { return 0 }
        return pow(min(1, max(0, (decibels + 50) / 42)), 1.4)
    }
}
