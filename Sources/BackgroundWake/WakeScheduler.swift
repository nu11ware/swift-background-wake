/// Registers launch handlers for background tasks.
///
/// Use ``system`` in an app. Create your own with ``init(registerLaunchHandler:)`` to drive a wake in tests.
public struct WakeScheduler: Sendable {
  private let registerLaunchHandler:
    @Sendable (_ identifier: String, _ launchHandler: @escaping @Sendable (WakeTask) -> Void) -> Bool

  /// Creates a scheduler from the call that registers a launch handler.
  ///
  /// - Parameter registerLaunchHandler: Registers `launchHandler` for `identifier` and returns whether the scheduler
  ///   accepted it. The scheduler may call `launchHandler` on any queue, once for each wake. The closure is
  ///   `@Sendable`, so no actor isolates it or a block formed inside it.
  public init(
    registerLaunchHandler: @escaping @Sendable (
      _ identifier: String, _ launchHandler: @escaping @Sendable (WakeTask) -> Void
    ) -> Bool
  ) {
    self.registerLaunchHandler = registerLaunchHandler
  }

  /// Registers a wake for the task with `identifier`.
  ///
  /// Each time the system launches the task, the wake keeps an expiration handler, then starts a `Task` that awaits
  /// `scheduleNext`, then `run`, and then reports completion: success if the system has not taken the time back,
  /// failure if it has. When the system takes the time back, the wake cancels that `Task`; `run` is not called if it
  /// has not started, and completion is reported when it returns. Completion is reported once for each launch.
  ///
  /// Return from `run` promptly once it is cancelled. `BGTask.h` warns that a task not reported complete before its
  /// time expires may get the app killed.
  ///
  /// With ``system``, register each identifier once, before the app finishes launching, as `BGTaskScheduler.h`
  /// requires of every task but a `BGContinuedProcessingTask`. The wake calls both closures from a `Task` that no
  /// actor isolates; `await` a main-actor function from them to do work there.
  ///
  /// - Parameters:
  ///   - identifier: The task's identifier. With ``system``, it must be listed under
  ///     `BGTaskSchedulerPermittedIdentifiers` in the app's `Info.plist`.
  ///   - scheduleNext: Submits the request for the next wake. It runs before `run` starts, and is cancelled too
  ///     if the system takes the time back while it runs.
  ///   - run: The work. It is cancelled when the system takes the time back.
  /// - Returns: Whether the scheduler accepted the identifier. ``system`` returns `false` for an identifier missing
  ///   from `BGTaskSchedulerPermittedIdentifiers`.
  @discardableResult
  public func register(
    _ identifier: String,
    scheduleNext: @escaping @Sendable () async -> Void,
    run: @escaping @Sendable () async -> Void
  ) -> Bool {
    registerLaunchHandler(identifier) { task in
      let (expirationHandlerKept, keepExpirationHandler) = AsyncStream<Never>.makeStream()
      let work = Task {
        for await _ in expirationHandlerKept {}
        await scheduleNext()
        if !Task.isCancelled { await run() }
        task.finish(!Task.isCancelled)
      }
      task.onExpiration { work.cancel() }
      keepExpirationHandler.finish()
    }
  }
}
