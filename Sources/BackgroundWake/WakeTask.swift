/// The task the system hands a launch handler, reduced to the two calls a wake makes on it.
///
/// ``WakeScheduler/system`` makes one from each `BGTask`. Make your own to drive a wake in tests.
public struct WakeTask: Sendable {
  let onExpiration: @Sendable (_ handler: @escaping @Sendable () -> Void) -> Void
  let finish: @Sendable (_ success: Bool) -> Void

  /// Creates a task from its two calls.
  ///
  /// - Parameters:
  ///   - onExpiration: Keeps `handler`, to be called when the system takes the time back. A wake calls this once,
  ///     from the launch handler, before the work starts. The system may call `handler` on any queue.
  ///   - finish: Reports that the work is over. A wake calls this exactly once, from any queue.
  public init(
    onExpiration: @escaping @Sendable (_ handler: @escaping @Sendable () -> Void) -> Void,
    finish: @escaping @Sendable (_ success: Bool) -> Void
  ) {
    self.onExpiration = onExpiration
    self.finish = finish
  }
}
