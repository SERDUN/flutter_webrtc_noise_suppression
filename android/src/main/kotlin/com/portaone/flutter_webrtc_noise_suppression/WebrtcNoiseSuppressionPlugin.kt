package com.portaone.flutter_webrtc_noise_suppression

import android.util.Log
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.audio.AudioProcessingAdapter
import com.cloudwebrtc.webrtc.audio.AudioProcessingController
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

/**
 * Puts a [NoiseSuppressor] into flutter_webrtc's capture post-processing slot of one engine.
 *
 * The two plugins know nothing about each other: flutter_webrtc offers the slot through
 * [AudioProcessingAdapter.ExternalAudioFrameProcessing], noise_suppression offers
 * [NoiseSuppressor]. This plugin is the only place that joins them, so neither depends on the
 * other and the suppressor can be replaced without touching flutter_webrtc.
 *
 * Flutter registers the plugin on every engine that registers plugins, and each engine has its
 * own flutter_webrtc: the instance is bound to the engine it was attached to and reaches that
 * engine's flutter_webrtc, never [FlutterWebRTCPlugin.sharedSingleton], which names whichever
 * engine was created last (a background push engine has a factory that is never initialized).
 * The slot belongs to that engine's peer connection factory, so one attached processor covers
 * every call of the engine.
 *
 * Every method call runs on the main thread.
 */
class WebrtcNoiseSuppressionPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var engine: FlutterEngine? = null
    private var controller: AudioProcessingController? = null
    private var processor: SuppressorFrameProcessor? = null

    @Suppress("DEPRECATION")
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        engine = binding.flutterEngine
        channel =
            MethodChannel(binding.binaryMessenger, CHANNEL).also {
                it.setMethodCallHandler(this)
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detach()
        channel?.setMethodCallHandler(null)
        channel = null
        engine = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "attach" -> result.success(attach())
            "detach" -> result.success(detach())
            else -> result.notImplemented()
        }
    }

    /** Returns true when a suppressor is in the slot after the call. */
    private fun attach(): Boolean {
        if (processor != null) return true

        // Looked up at call time: the plugins of an engine are registered in no fixed order.
        val webrtc = engine?.plugins?.get(FlutterWebRTCPlugin::class.java) as? FlutterWebRTCPlugin
        // The controller exists once flutter_webrtc has built its peer connection factory, which
        // happens before the first microphone track is opened.
        val found = webrtc?.audioProcessingController
        if (found == null) {
            Log.w(TAG, "not attached: flutter_webrtc audio processing is not initialized")
            return false
        }

        val suppressor =
            try {
                RnnoiseSuppressor()
            } catch (e: Throwable) {
                // An OutOfMemoryError of the state or a missing native library leaves the call
                // with the platform processing only, which is what it had before.
                Log.w(TAG, "not attached: suppressor not created", e)
                return false
            }

        val created = SuppressorFrameProcessor(suppressor)
        found.capturePostProcessing.addProcessor(created)
        controller = found
        processor = created
        Log.i(TAG, "attached ${suppressor.engine()}")
        return true
    }

    /** Returns true when a suppressor was in the slot and has been removed. */
    private fun detach(): Boolean {
        val attached = processor ?: return false
        // The adapter calls processors under the lock that removeProcessor takes, so once it
        // returns no frame is in flight and the native state can be freed.
        controller?.capturePostProcessing?.removeProcessor(attached)
        attached.release()
        processor = null
        controller = null
        Log.i(TAG, "detached: ${attached.summary()}")
        return true
    }

    private companion object {
        const val TAG = "WebrtcNoiseSuppression"
        const val CHANNEL = "com.portaone.flutter_webrtc_noise_suppression"
    }
}

/**
 * Adapts flutter_webrtc's frames to [NoiseSuppressor].
 *
 * libwebrtc calls it on the capture thread with 10 ms of channel 0 of the full-band buffer, after
 * its own echo cancellation, noise suppression and gain control and right before the encoder.
 * The adapter serializes all three callbacks under one lock.
 */
private class SuppressorFrameProcessor(
    private val suppressor: NoiseSuppressor,
) : AudioProcessingAdapter.ExternalAudioFrameProcessing {
    private var initialized = false
    private var processed = 0L
    private var unchanged = 0L
    private var lastResult: NoiseSuppressor.Result? = null
    private val announced = StringBuilder()

    override fun initialize(
        sampleRateHz: Int,
        numChannels: Int,
    ) {
        note("initialize($sampleRateHz, $numChannels)")
        suppressor.initialize(sampleRateHz)
        initialized = true
    }

    override fun reset(newRate: Int) {
        note("reset($newRate)")
        suppressor.initialize(newRate)
        initialized = true
    }

    override fun process(
        numBands: Int,
        numFrames: Int,
        buffer: ByteBuffer,
    ) {
        // A processor added while the microphone is already running is never told the rate:
        // the adapter announces it only when the stream starts. A frame is 10 ms, so its length
        // gives the rate. The first initialize allocates nothing.
        if (!initialized) {
            suppressor.initialize(numFrames * 100)
            initialized = true
        }
        // A frame the engine cannot take comes back unchanged, so the call keeps the audio it
        // would have had without the suppressor.
        val result = suppressor.process(buffer, numFrames)
        if (result == NoiseSuppressor.Result.PROCESSED) processed++ else unchanged++
        if (result != lastResult) {
            lastResult = result
            note("$result at frame ${processed + unchanged} ($numFrames samples, $numBands bands)")
        }
    }

    /**
     * The call's one log line: how many frames were denoised and how many left unchanged (a rate
     * or length the engine does not take), and what the slot announced. Read after the processor
     * left the slot, so no frame is counted at the same time.
     */
    fun summary(): String = "processed=$processed unchanged=$unchanged $announced"

    private fun note(event: String) {
        if (announced.length < 400) announced.append('[').append(event).append(']')
    }

    fun release() = suppressor.release()
}
