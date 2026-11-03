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
}
