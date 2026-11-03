import Flutter
import UIKit
import XCTest

import NoiseSuppression
@testable import flutter_webrtc_noise_suppression

/// The suppressor through its interface: 3 s of white noise come out quieter once the model has
/// settled (the first second is skipped, as in the C test). The add-on through its method channel
/// handler, without Dart: attach puts the suppressor into flutter_webrtc's process-wide slot, detach
/// takes it out, an unknown method is not implemented.
class RunnerTests: XCTestCase {

  private func call(_ plugin: WebrtcNoiseSuppressionPlugin, _ method: String) -> Any? {
    var answer: Any?
    let done = expectation(description: method)
    plugin.handle(FlutterMethodCall(methodName: method, arguments: nil)) { result in
      answer = result
      done.fulfill()
    }
    waitForExpectations(timeout: 2)
    return answer
  }

  func testAttachThenDetach() {
    let plugin = WebrtcNoiseSuppressionPlugin()
    XCTAssertEqual(call(plugin, "attach") as? Bool, true)
    XCTAssertEqual(call(plugin, "detach") as? Bool, true)
    XCTAssertEqual(call(plugin, "detach") as? Bool, false)
  }

  func testUnknownMethod() {
    let plugin = WebrtcNoiseSuppressionPlugin()
    XCTAssertTrue((call(plugin, "nope") as AnyObject) === FlutterMethodNotImplemented)
  }

  func testRnnoiseSuppressorDenoisesWhiteNoise() {
    guard let suppressor = NSPRnnoiseSuppressor() else {
      return XCTFail("no engine state")
    }
    let engine: NSPNoiseSuppressor = suppressor
    XCTAssertTrue(engine.initialize(withSampleRate: NSPRnnoiseSuppressor.sampleRate))
    let n = NSPRnnoiseSuppressor.frameSize
    var frame = [Float](repeating: 0, count: n)
    var seed: UInt32 = 12345
    var inRms = 0.0, outRms = 0.0
    for f in 0..<300 {
      for i in 0..<n {
        seed = seed &* 1103515245 &+ 12345
        frame[i] = 3000 * (Float((seed >> 8) & 0xffff) / 32768 - 1)
      }
      let before = sqrt(frame.reduce(0.0) { $0 + Double($1 * $1) } / Double(n))
      let result = frame.withUnsafeMutableBufferPointer {
        engine.processSamples($0.baseAddress!, count: n)
      }
      XCTAssertEqual(result, .processed)
      if f >= 100 {
        inRms += before
        outRms += sqrt(frame.reduce(0.0) { $0 + Double($1 * $1) } / Double(n))
      }
    }
    XCTAssertGreaterThan(20 * log10(inRms / outRms), 10)
    engine.releaseEngine()
  }
}
