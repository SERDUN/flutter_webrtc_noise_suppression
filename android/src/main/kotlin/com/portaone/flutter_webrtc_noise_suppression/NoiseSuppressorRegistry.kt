package com.portaone.flutter_webrtc_noise_suppression

import java.util.concurrent.ConcurrentHashMap

/**
 * The engines `attach` and `measure` can name, each by the name the Dart side sends.
 *
 * Internal to the plugin: an app picks one of the engines the plugin ships
 * (`WebrtcNoiseSuppressionEngine.rnnoise`), it does not bring its own. A new engine comes as a
 * pull request: its [NoiseSuppressor], one line in the `init` block below, its name in Dart (see
 * the README, "Adding an engine"). The plugin, the chain and the [FormatAdapter] do not change for
 * it. Safe to use from any thread; a factory runs off the main thread and may take its time
 * (loading a model).
 */
internal object NoiseSuppressorRegistry {
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
    fun register(
        name: String,
        factory: Factory,
    ) {
        factories[name] = factory
    }

    /** Removes the engine [name]; a suppressor already in the slot stays until it is detached. */
    fun unregister(name: String) {
        factories.remove(name)
    }

    /** The names registered, sorted. */
    fun names(): List<String> = factories.keys.sorted()

    fun factory(name: String): Factory? = factories[name]
}
