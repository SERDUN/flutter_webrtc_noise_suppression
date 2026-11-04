import Foundation
// An app that writes an engine needs NSPNoiseSuppressor: importing this module gives it.
@_exported import NoiseSuppression

/// The engines `attach` and `measure` can name, each by the name the Dart side sends.
///
/// RNNoise v0.1.1 is registered as `NoiseSuppressorRegistry.rnnoise`. An app or another plugin adds
/// its own engine from its own code, before the first call names it (in `AppDelegate`, or in its
/// plugin's `register(with:)`):
///
///     NoiseSuppressorRegistry.register("my-engine") { MyEngine() }
///
/// and Dart names it with `WebrtcNoiseSuppressionEngine('my-engine')`. Nothing in this plugin
/// changes for it: the engine is an `NSPNoiseSuppressor`, and one that works at another rate or
/// frame length says so through `engineSampleRate` and `engineFrameSize`. The registry is
/// process-wide and safe to use from any thread; a factory runs off the main thread and may take its
/// time (loading a model). A factory that returns nil could not create its engine.
public final class NoiseSuppressorRegistry {
  public typealias Factory = () -> NSPNoiseSuppressor?

  /// The name of RNNoise v0.1.1, the default engine.
  public static let rnnoise = "rnnoise"

  private static let lock = NSLock()
  private static var factories: [String: Factory] = [rnnoise: { NSPRnnoiseSuppressor(model: .v0_1) }]

  private init() {}

  /// Adds the engine `name`, or replaces the one of that name.
  public static func register(_ name: String, factory: @escaping Factory) {
    lock.lock()
    defer { lock.unlock() }
    factories[name] = factory
  }

  /// Removes the engine `name`; a suppressor already in the slot stays until it is detached.
  public static func unregister(_ name: String) {
    lock.lock()
    defer { lock.unlock() }
    factories.removeValue(forKey: name)
  }

  /// The names registered, sorted.
  public static var names: [String] {
    lock.lock()
    defer { lock.unlock() }
    return factories.keys.sorted()
  }

  static func factory(_ name: String) -> Factory? {
    lock.lock()
    defer { lock.unlock() }
    return factories[name]
  }
}
