import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc_noise_suppression/flutter_webrtc_noise_suppression.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the suppressor goes into the capture slot and comes out again', (
    tester,
  ) async {
    const bridge = WebrtcNoiseSuppressionBridge();
    // flutter_webrtc builds its factory, and the slot with it, on its first use.
    final pc = await createPeerConnection({'iceServers': []});

    expect(await bridge.attach(), isTrue);
    expect(
      await bridge.attach(),
      isTrue,
      reason: 'a second attach keeps the one in the slot',
    );
    expect(await bridge.detach(), isTrue);
    expect(await bridge.detach(), isFalse, reason: 'nothing left to take out');

    await pc.close();
  });

  testWidgets('every engine runs on this device within the frame budget', (
    tester,
  ) async {
    const bridge = WebrtcNoiseSuppressionBridge();
    for (final engine in WebrtcNoiseSuppressionEngine.values) {
      final m = await bridge.measure(engine: engine);
      // The line a device run is read for: the time per frame on this phone.
      debugPrint('measure: $m');
      expect(m.attenuationDb, greaterThan(10), reason: '$m');
      expect(
        m.p99Us,
        lessThan(10000),
        reason: 'a 10 ms frame must take less than 10 ms: $m',
      );
    }
  });
}
