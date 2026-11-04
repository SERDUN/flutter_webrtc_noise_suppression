package com.portaone.flutter_webrtc_noise_suppression

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** The adapter on the JVM, with engines that only copy or count: no native library, no phone. */
class FormatAdapterTest {
    /** Leaves its frames as they are, at the format it names; counts the frames it was given. */
    private class Identity(
        private val rate: Int,
        private val frame: Int,
        private val answer: NoiseSuppressor.Result = NoiseSuppressor.Result.PROCESSED,
    ) : NoiseSuppressor {
        var lengths = mutableSetOf<Int>()
        var initializedAt = 0

        override fun engine() = "identity $rate/$frame"

        override fun initialize(sampleRateHz: Int): Boolean {
            initializedAt = sampleRateHz
            return rate == 0 || sampleRateHz == rate
        }

        override fun process(
            frame: ByteBuffer,
            numSamples: Int,
        ): NoiseSuppressor.Result {
            lengths += numSamples
            return answer
        }

        override fun release() {}

        override fun engineSampleRateHz() = rate

        override fun engineFrameSize() = frame
    }

    private val slot = 48_000
    private val n = 480

    /** [seconds] of [signal] through [adapter] in 10 ms frames, as the slot hands them over. */
    private fun run(
        adapter: NoiseSuppressor,
        seconds: Int,
        signal: (Int) -> Float,
    ): Pair<FloatArray, List<NoiseSuppressor.Result>> {
        val frame = ByteBuffer.allocateDirect(n * 4).order(ByteOrder.nativeOrder())
        val out = FloatArray(seconds * slot)
        val results = mutableListOf<NoiseSuppressor.Result>()
        for (f in 0 until seconds * 100) {
            for (i in 0 until n) frame.putFloat(4 * i, signal(f * n + i))
            frame.position(0)
            results += adapter.process(frame, n)
            for (i in 0 until n) out[f * n + i] = frame.getFloat(4 * i)
        }
        return out to results
    }

    private fun sine(hz: Double) = { t: Int -> (10_000 * Math.sin(2 * Math.PI * hz * t / slot)).toFloat() }

    private fun rms(
        x: FloatArray,
        from: Int,
    ): Double {
        var s = 0.0
        for (i in from until x.size) s += x[i].toDouble() * x[i]
        return Math.sqrt(s / (x.size - from))
    }

    /** The largest normalized correlation of out against the input delayed by 0..maxLag samples. */
    private fun bestLag(
        out: FloatArray,
        signal: (Int) -> Float,
        maxLag: Int,
    ): Pair<Int, Double> {
        var best = 0 to -1.0
        val from = slot / 2
        for (lag in 0..maxLag) {
            var xy = 0.0
            var xx = 0.0
            var yy = 0.0
            for (i in from until out.size) {
                val x = signal(i - lag).toDouble()
                xy += x * out[i]
                xx += x * x
                yy += out[i].toDouble() * out[i]
            }
            val c = xy / Math.sqrt(xx * yy)
            if (c > best.second) best = lag to c
        }
        return best
    }

    @Test
    fun anEngineOfTheSlotFormatGetsTheFramesAsTheyAre() {
        val engine = Identity(0, 0)
        val adapter = FormatAdapter(engine)
        assertTrue(adapter.initialize(slot))
        assertEquals(0, adapter.latencySamples)
        val (out, _) = run(adapter, 1, sine(1000.0))
        for (i in out.indices) assertEquals(sine(1000.0)(i), out[i], 0f)
        assertEquals(setOf(n), engine.lengths)
        assertEquals(slot, engine.initializedAt)
    }

    @Test
    fun a16kHzEngineGetsItsOwnFramesAndTheVoiceBandComesBack() {
        val engine = Identity(16_000, 160)
        val adapter = FormatAdapter(engine)
        assertTrue(adapter.initialize(slot))
        assertEquals(16_000, engine.initializedAt)
        val (out, results) = run(adapter, 2, sine(1000.0))
        assertEquals(setOf(160), engine.lengths)
        assertTrue(results.all { it == NoiseSuppressor.Result.PROCESSED })
        val (lag, corr) = bestLag(out, sine(1000.0), adapter.latencySamples + 48)
        assertTrue("correlation $corr at lag $lag", corr > 0.9999)
        assertTrue("lag $lag within ${adapter.latencySamples}", lag <= adapter.latencySamples)
        val gainDb = 20 * Math.log10(rms(out, slot / 2) / (10_000 / Math.sqrt(2.0)))
        assertEquals("gain $gainDb dB", 0.0, gainDb, 0.2)
    }

    @Test
    fun aFrameLengthThatIsNot10msIsGathered() {
        val engine = Identity(16_000, 256)
        val adapter = FormatAdapter(engine)
        assertTrue(adapter.initialize(slot))
        val (out, _) = run(adapter, 2, sine(440.0))
        assertEquals(setOf(256), engine.lengths)
        val (_, corr) = bestLag(out, sine(440.0), adapter.latencySamples + 48)
        assertTrue("correlation $corr", corr > 0.9999)
    }

    @Test
    fun whatTheLowerRateCannotCarryIsFilteredOut() {
        val adapter = FormatAdapter(Identity(16_000, 160))
        assertTrue(adapter.initialize(slot))
        val (out, _) = run(adapter, 2, sine(12_000.0))
        val db = 20 * Math.log10(rms(out, slot / 2) / (10_000 / Math.sqrt(2.0)))
        assertTrue("12 kHz through a 16 kHz engine: $db dB", db < -40)
    }

    @Test
    fun aRateTheStreamDoesNotDivideLeavesFramesUnchanged() {
        val adapter = FormatAdapter(Identity(44_100, 441))
        assertFalse(adapter.initialize(slot))
        val (out, results) = run(adapter, 1, sine(1000.0))
        assertTrue(results.all { it == NoiseSuppressor.Result.UNSUPPORTED_RATE })
        for (i in out.indices) assertEquals(sine(1000.0)(i), out[i], 0f)
    }

    @Test
    fun anEngineThatRefusesAFrameIsReported() {
        val adapter = FormatAdapter(Identity(16_000, 160, NoiseSuppressor.Result.INVALID))
        assertTrue(adapter.initialize(slot))
        val (_, results) = run(adapter, 1, sine(1000.0))
        assertTrue(results.all { it == NoiseSuppressor.Result.INVALID })
    }

    @Test
    fun theRegistryNamesRnnoiseAndTakesAnotherEngine() {
        assertTrue(NoiseSuppressorRegistry.RNNOISE in NoiseSuppressorRegistry.names())
        NoiseSuppressorRegistry.register("test-identity") { Identity(16_000, 160) }
        try {
            assertTrue("test-identity" in NoiseSuppressorRegistry.names())
            assertEquals("identity 16000/160", NoiseSuppressorRegistry.factory("test-identity")!!.create().engine())
        } finally {
            NoiseSuppressorRegistry.unregister("test-identity")
        }
        assertFalse("test-identity" in NoiseSuppressorRegistry.names())
    }
}
