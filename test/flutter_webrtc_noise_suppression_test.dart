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
    expect(calls.first.arguments, {
      'engines': ['rnnoise'],
    });
  });

  test('attach sends a chain in its order', () async {
    const bridge = WebrtcNoiseSuppressionBridge();

    await bridge.attach(
      engines: const [WebrtcNoiseSuppressionEngine.rnnoise, WebrtcNoiseSuppressionEngine('my-engine')],
      dumpInputSeconds: 30,
    );
    expect(calls.single.arguments, {
      'engines': ['rnnoise', 'my-engine'],
      'dumpInputSeconds': 30,
    });
  });

  test('engines reads the names the native side registered', () async {
    answer = ['my-engine', 'rnnoise'];
    const bridge = WebrtcNoiseSuppressionBridge();

    expect(await bridge.engines(), [
      const WebrtcNoiseSuppressionEngine('my-engine'),
      WebrtcNoiseSuppressionEngine.rnnoise,
    ]);
    expect(calls.single.method, 'engines');
  });

  test('measure names the engine and reads the native answer', () async {
    answer = {'engine': 'rnnoise 0.1.1', 'meanUs': 331, 'p99Us': 465.5, 'attenuationDb': 15.1, 'latencyMs': 0};
    const bridge = WebrtcNoiseSuppressionBridge();

    final m = await bridge.measure(engine: WebrtcNoiseSuppressionEngine.rnnoise);
    expect(calls.single.method, 'measure');
    expect(calls.single.arguments, {'engine': 'rnnoise'});
    expect(m.engine, 'rnnoise 0.1.1');
    expect(m.meanUs, 331);
    expect(m.p99Us, 465.5);
    expect(m.attenuationDb, 15.1);
    expect(m.latencyMs, 0);
  });

  test('a native side that answers nothing counts as not attached', () async {
    answer = null;
    const bridge = WebrtcNoiseSuppressionBridge();

    expect(await bridge.attach(), isFalse);
  });
}
