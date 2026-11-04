package com.portaone.flutter_webrtc_noise_suppression

import java.util.concurrent.ConcurrentHashMap

/**
 * The engines `attach` and `measure` can name, each by the name the Dart side sends.
 *
 * RNNoise v0.1.1 is registered as [RNNOISE]. An app or another plugin adds its own engine from its
 * own code, before the first call names it (in `MainActivity.configureFlutterEngine`, or in its
 * plugin's `onAttachedToEngine`):
 *
 * ```
 * NoiseSuppressorRegistry.register("my-engine") { MyEngine() }
 * ```
 *
 * and Dart names it with `WebrtcNoiseSuppressionEngine('my-engine')`. Nothing in this plugin
 * changes for it: the engine is a [NoiseSuppressor], and one that works at another rate or frame
 * length says so through [NoiseSuppressor.engineSampleRateHz] and
 * [NoiseSuppressor.engineFrameSize]. The registry is process-wide and safe to use from any thread;
 * a factory runs off the main thread and may take its time (loading a model).
 */
object NoiseSuppressorRegistry {
    /** Creates a fresh engine; throws (or runs out of memory) when it cannot. */
    fun interface Factory {
        fun create(): NoiseSuppressor
    }

    /** The name of RNNoise v0.1.1, the default engine. */
    const val RNNOISE = "rnnoise"

    private val factories = ConcurrentHashMap<String, Factory>()

    init {
        register(RNNOISE) { RnnoiseSuppressor() }
    }

    /** Adds the engine [name], or replaces the one of that name. */
    @JvmStatic
    fun register(
        name: String,
        factory: Factory,
    ) {
        factories[name] = factory
    }

    /** Removes the engine [name]; a suppressor already in the slot stays until it is detached. */
    @JvmStatic
    fun unregister(name: String) {
        factories.remove(name)
    }

    /** The names registered, sorted. */
    @JvmStatic
    fun names(): List<String> = factories.keys.sorted()

    internal fun factory(name: String): Factory? = factories[name]
}
