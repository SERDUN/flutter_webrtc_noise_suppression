import Flutter
import UIKit
import XCTest

@testable import flutter_webrtc_noise_suppression

/// The plugin through its method channel handler, without Dart: attach puts the suppressor into
/// flutter_webrtc's process-wide slot, detach takes it out, an unknown method is not implemented.
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
}
