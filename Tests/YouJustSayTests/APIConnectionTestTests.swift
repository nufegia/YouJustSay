import XCTest
import AVFoundation
@testable import YouJustSay

final class APIConnectionTestTests: XCTestCase {
    @MainActor func testSuccessRequiresOperationToComplete() async throws {
        let test = APIConnectionTest()
        test.start { }
        XCTAssertTrue(test.running)
        XCTAssertNil(test.result)
        try await waitForCompletion(test)
        XCTAssertEqual(test.result, .success)
    }

    @MainActor func testProviderAndNetworkFailuresAreNotSuccess() async throws {
        let test = APIConnectionTest()
        test.start { throw AppFailure.provider("Doubao", "HTTP 401") }
        try await waitForCompletion(test)
        XCTAssertEqual(test.result, .providerFailure("Doubao", "HTTP 401"))
        test.start { throw URLError(.timedOut) }
        try await waitForCompletion(test)
        XCTAssertEqual(test.result, .failure("network"))
    }

    @MainActor func testChangingConfigurationDiscardsOldResult() async throws {
        let test = APIConnectionTest()
        test.start { }
        try await waitForCompletion(test)
        test.reset()
        XCTAssertNil(test.result)
        test.start { try? await Task.sleep(for: .milliseconds(20)) }
        await Task.yield()
        test.reset()
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertNil(test.result)
        XCTAssertFalse(test.running)
    }

    func testBundledSpeechSampleContainsActualAudio() throws {
        let audio = try ProviderClient.testAudio()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try audio.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.sampleRate, 16000)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertGreaterThan(file.length, 16000)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        XCTAssertTrue((0..<Int(buffer.frameLength)).contains { abs(channel[$0]) > 0.01 })
    }

    @MainActor private func waitForCompletion(_ test: APIConnectionTest) async throws {
        for _ in 0..<100 where test.running { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(test.running)
    }
}
