import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_webrtc_noise_suppression/flutter_webrtc_noise_suppression.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WebrtcNoiseSuppressionBridge.channelName);
  late List<MethodCall> calls;
  Object? answer;

  setUp(() {
    calls = [];
    answer = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
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
    expect(calls.map((c) => c.method), ['attach', 'detach']);
    expect(calls.first.arguments, {'engine': 'rnnoise'});
  });

  test('attach names the engine asked for', () async {
    const bridge = WebrtcNoiseSuppressionBridge();

    await bridge.attach(engine: WebrtcNoiseSuppressionEngine.rnnoise);
    expect(calls.single.arguments, {'engine': 'rnnoise'});
  });

  test('a native side that answers nothing counts as not attached', () async {
    answer = null;
    const bridge = WebrtcNoiseSuppressionBridge();

    expect(await bridge.attach(), isFalse);
  });
}
