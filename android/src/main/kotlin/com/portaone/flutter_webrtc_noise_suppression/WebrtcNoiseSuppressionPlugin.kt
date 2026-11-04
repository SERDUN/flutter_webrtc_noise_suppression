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
    private var filesDir: java.io.File? = null
    private var controller: AudioProcessingController? = null
    private var processor: SuppressorFrameProcessor? = null

    @Suppress("DEPRECATION")
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        engine = binding.flutterEngine
        filesDir = binding.applicationContext.getExternalFilesDir(null)
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
            "attach" -> {
                val model = model(call.argument<String>("engine"))
                if (model == null) {
                    result.error("unknown_engine", "unknown engine ${call.argument<String>("engine")}", null)
                } else {
                    result.success(attach(model, call.argument<Int>("dumpInputSeconds") ?: 0))
                }
            }
            "detach" -> result.success(detach())
            "measure" -> {
                val model = model(call.argument<String>("engine"))
                if (model == null) {
                    result.error("unknown_engine", "unknown engine ${call.argument<String>("engine")}", null)
                } else {
                    // 3 s of audio is a few hundred ms of work on a slow phone: off the main thread.
                    Thread {
                        val measured = measure(model)
                        android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(measured) }
                    }.start()
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Returns true when a suppressor of [model] is in the slot after the call. One of another model
     * is taken out first: the slot holds one suppressor at a time.
     */
    private fun attach(
        model: RnnoiseSuppressor.Model,
        dumpInputSeconds: Int = 0,
    ): Boolean {
        if (processor?.model == model && dumpInputSeconds == 0) return true
        if (processor != null) detach()

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
                RnnoiseSuppressor(model)
            } catch (e: Throwable) {
                // An OutOfMemoryError of the state or a missing native library leaves the call
                // with the platform processing only, which is what it had before.
                Log.w(TAG, "not attached: suppressor not created", e)
                return false
            }

        // Diagnostics: the frames that reach the slot, before the suppressor, kept in memory for
        // the given seconds and written on detach. The buffer is allocated here, not per frame.
        val dump = if (dumpInputSeconds > 0) ShortArray(dumpInputSeconds * 48_000) else null
        val created = SuppressorFrameProcessor(suppressor, model, dump)
        found.capturePostProcessing.addProcessor(created)
        controller = found
        processor = created
        Log.i(TAG, "attached ${suppressor.engine()}")
        return true
    }

    /**
     * Runs 3 s of white noise through a fresh suppressor of [model], frame by frame as the slot
     * would: the time per frame on this phone and the attenuation once the model has settled (the
     * first second is skipped). A check of the engine on a device, not of call quality.
     */
    private fun measure(model: RnnoiseSuppressor.Model): Map<String, Any> {
        val suppressor = RnnoiseSuppressor(model)
        try {
            suppressor.initialize(RnnoiseSuppressor.sampleRate())
            val n = RnnoiseSuppressor.frameSize()
            val frame = ByteBuffer.allocateDirect(n * 4).order(java.nio.ByteOrder.nativeOrder())
            val floats = frame.asFloatBuffer()
            // The generator of the C test and of iOS, so the three report on the same noise.
            var seed = 12345

            val times = LongArray(300)
            var inRms = 0.0
            var outRms = 0.0
            for (f in 0 until 300) {
                var before = 0.0
                for (i in 0 until n) {
                    seed = seed * 1103515245 + 12345
                    val v = 3000f * (((seed ushr 8) and 0xffff) / 32768f - 1f)
                    floats.put(i, v)
                    before += v * v
                }
                val start = System.nanoTime()
                suppressor.process(frame, n)
                times[f] = System.nanoTime() - start
                if (f >= 100) {
                    var after = 0.0
                    for (i in 0 until n) after += floats.get(i).toDouble() * floats.get(i)
                    inRms += Math.sqrt(before / n)
                    outRms += Math.sqrt(after / n)
                }
            }
            times.sort()
            return mapOf(
                "engine" to suppressor.engine(),
                "meanUs" to times.average() / 1000.0,
                "p99Us" to times[(times.size * 99) / 100] / 1000.0,
                "attenuationDb" to 20 * Math.log10(inRms / outRms),
            )
        } finally {
            suppressor.release()
        }
    }

    /** Returns true when a suppressor was in the slot and has been removed. */
    private fun detach(): Boolean {
        val attached = processor ?: return false
        // The adapter calls processors under the lock that removeProcessor takes, so once it
        // returns no frame is in flight and the native state can be freed.
        controller?.capturePostProcessing?.removeProcessor(attached)
        attached.release()
        attached.writeDump(filesDir)?.let { Log.i(TAG, "slot input written to $it") }
        processor = null
        controller = null
        Log.i(TAG, "detached: ${attached.summary()}")
        return true
    }

    private companion object {
        const val TAG = "WebrtcNoiseSuppression"
        const val CHANNEL = "com.portaone.flutter_webrtc_noise_suppression"

        /** The engine names of the Dart API; a missing one is RNNoise v0.1.1. */
        fun model(engine: String?): RnnoiseSuppressor.Model? =
            when (engine) {
                null, "rnnoise" -> RnnoiseSuppressor.Model.V0_1
                else -> null
            }
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
    val model: RnnoiseSuppressor.Model,
    private val dump: ShortArray? = null,
) : AudioProcessingAdapter.ExternalAudioFrameProcessing {
    private var dumped = 0
    private var dumpRate = 0

    private var initialized = false
    private var processed = 0L
    private var unchanged = 0L
    private var lastResult: NoiseSuppressor.Result? = null
    private val announced = StringBuilder()

    // Time per frame in the call, without allocating on the audio thread: 200 us buckets up to
    // 20 ms, the last one for everything longer.
    private val buckets = IntArray(BUCKETS + 1)
    private var totalNs = 0L
    private var maxNs = 0L

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
        if (dump != null && dumped + numFrames <= dump.size) {
            if (dumpRate == 0) dumpRate = numFrames * 100
            // The buffer wraps native memory: read it in native order (Java's default is big endian).
            // A view object per frame: diagnostics only, never in a normal call.
            val floats = buffer.duplicate().order(java.nio.ByteOrder.nativeOrder()).asFloatBuffer()
            for (i in 0 until numFrames) {
                dump[dumped + i] = floats.get(i).coerceIn(-32768f, 32767f).toInt().toShort()
            }
            dumped += numFrames
        }
        val start = System.nanoTime()
        val result = suppressor.process(buffer, numFrames)
        val spent = System.nanoTime() - start
        totalNs += spent
        if (spent > maxNs) maxNs = spent
        buckets[minOf((spent / BUCKET_NS).toInt(), BUCKETS)]++
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
    fun summary(): String {
        val frames = processed + unchanged
        val meanUs = if (frames == 0L) 0 else totalNs / frames / 1000
        return "${suppressor.engine()} processed=$processed unchanged=$unchanged" +
            " mean_us=$meanUs p99_us=${percentileUs(0.99)} max_us=${maxNs / 1000}" +
            " over_10ms=${overBudget()} $announced"
    }

    /** The upper edge of the bucket the [q] quantile falls in; the last bucket reads as its floor. */
    private fun percentileUs(q: Double): Long {
        val frames = buckets.sum()
        if (frames == 0) return 0
        var seen = 0
        for (i in buckets.indices) {
            seen += buckets[i]
            if (seen >= q * frames) return (if (i == BUCKETS) i else i + 1) * BUCKET_NS / 1000
        }
        return BUCKETS * BUCKET_NS / 1000
    }

    /** Frames that took longer than the 10 ms they hold. */
    private fun overBudget(): Int {
        var over = 0
        for (i in (10_000_000 / BUCKET_NS).toInt()..BUCKETS) over += buckets[i]
        return over
    }

    private companion object {
        const val BUCKET_NS = 200_000L
        const val BUCKETS = 100
    }

    private fun note(event: String) {
        if (announced.length < 400) announced.append('[').append(event).append(']')
    }

    fun release() = suppressor.release()

    /** The dumped slot input as a 16-bit mono WAV in [dir]; null when nothing was dumped. */
    fun writeDump(dir: java.io.File?): java.io.File? {
        if (dump == null || dumped == 0 || dir == null) return null
        val file = java.io.File(dir, "slot-input-${System.currentTimeMillis()}.wav")
        val data = dumped * 2
        val out = ByteBuffer.allocate(44 + data).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        out.put("RIFF".toByteArray()).putInt(36 + data).put("WAVE".toByteArray())
        out.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(1)
        out.putInt(dumpRate).putInt(dumpRate * 2).putShort(2).putShort(16)
        out.put("data".toByteArray()).putInt(data)
        for (i in 0 until dumped) out.putShort(dump[i])
        file.writeBytes(out.array())
        return file
    }
}
