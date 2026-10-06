import XCTest
@testable import YouJustSay

final class AudioWaveformTests: XCTestCase {
    func testSilenceAndLoudnessHaveUsefulRange() {
        XCTAssertEqual(AudioWaveform.normalized(decibels: -80), 0)
        XCTAssertEqual(AudioWaveform.normalized(decibels: -.infinity), 0)
        XCTAssertLessThan(AudioWaveform.normalized(decibels: -40), 0.2)
        XCTAssertGreaterThan(AudioWaveform.normalized(decibels: -16), 0.7)
        XCTAssertEqual(AudioWaveform.normalized(decibels: 0), 1)
    }
    func testHistoryCarriesMeasuredPeaksThenReturnsToSilence() {
        var waveform = AudioWaveform()
        waveform.append(0.8)
        waveform.append(0.2)
        XCTAssertEqual(Array(waveform.samples.suffix(2)), [0.8, 0.2])
        for _ in 0..<19 { waveform.append(0) }
        XCTAssertEqual(waveform.samples, Array(repeating: 0, count: 19))
        waveform.append(.nan)
        XCTAssertEqual(waveform.samples.last, 0)
    }
}
