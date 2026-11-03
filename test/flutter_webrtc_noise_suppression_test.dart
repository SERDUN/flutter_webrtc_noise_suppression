import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_webrtc_noise_suppression/flutter_webrtc_noise_suppression.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WebrtcNoiseSuppressionBridge.channelName);
  late List<String> calls;
  Object? answer;

  setUp(() {
    calls = [];
    answer = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return answer;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('attach and detach reach the native side by name', () async {
    const bridge = WebrtcNoiseSuppressionBridge();

    expect(await bridge.attach(), isTrue);
    expect(await bridge.detach(), isTrue);
    expect(calls, ['attach', 'detach']);
  });

  test('a native side that answers nothing counts as not attached', () async {
    answer = null;
    const bridge = WebrtcNoiseSuppressionBridge();

    expect(await bridge.attach(), isFalse);
  });
}
