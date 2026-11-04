package com.portaone.flutter_webrtc_noise_suppression_example

import com.portaone.flutter_webrtc_noise_suppression.NoiseSuppressor
import com.portaone.flutter_webrtc_noise_suppression.NoiseSuppressorRegistry
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // An engine of the app's own, registered without touching the plugin: the device tests
        // put it into a chain and measure it through the format adapter.
        NoiseSuppressorRegistry.register(IDENTITY_16K) { Identity16k() }
    }

    /** Leaves 10 ms frames of 16 kHz as they are. */
    private class Identity16k : NoiseSuppressor {
        override fun engine() = "example identity 16 kHz"

        override fun initialize(sampleRateHz: Int) = sampleRateHz == 16_000

        override fun process(
            frame: ByteBuffer,
            numSamples: Int,
        ) = if (numSamples == 160) NoiseSuppressor.Result.PROCESSED else NoiseSuppressor.Result.UNSUPPORTED_FRAME

        override fun release() {}

        override fun engineSampleRateHz() = 16_000

        override fun engineFrameSize() = 160
    }

    private companion object {
        const val IDENTITY_16K = "example-identity-16k"
    }
}
