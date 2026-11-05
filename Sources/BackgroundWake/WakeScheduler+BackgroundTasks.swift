#if os(iOS) || os(tvOS) || os(visionOS)
  import BackgroundTasks

  extension WakeScheduler {
    /// The shared `BGTaskScheduler`.
    ///
    /// The block it hands `register(forTaskWithIdentifier:using:launchHandler:)` is formed in this package, in a
    /// closure no actor isolates, whatever the isolation of the code that calls ``register(_:scheduleNext:run:)``. It
    /// passes `nil` for the queue, so the system calls the block on a background queue of its own.
    public static var system: WakeScheduler {
      backgroundTasks(of: BGTask.self) { identifier, launchHandler in
        BGTaskScheduler.shared.register(
          forTaskWithIdentifier: identifier,
          using: nil,
          launchHandler: launchHandler
        )
      }
    }
  }

  extension BGTask: SystemTask {}
#endif

/// The two members of `BGTask` a wake uses.
package protocol SystemTask: AnyObject, SendableMetatype {
  var expirationHandler: (() -> Void)? { get set }
  func setTaskCompleted(success: Bool)
}

extension WakeScheduler {
  /// The wiring of ``system``, for any scheduler whose tasks have the members of `BGTask` a wake uses.
  ///
  /// The launch handler handed to `register` is formed here, in a closure no actor isolates.
  package static func backgroundTasks<Task: SystemTask>(
    of _: Task.Type,
    register: @escaping @Sendable (
      _ identifier: String, _ launchHandler: @escaping (Task) -> Void
    ) -> Bool
  ) -> WakeScheduler {
    WakeScheduler { identifier, launchHandler in
      register(identifier) { task in
        let task = CarriedTask(task: task)
        launchHandler(
          WakeTask(
            onExpiration: { handler in task.task.expirationHandler = handler },
            finish: { success in task.task.setTaskCompleted(success: success) }
          )
        )
      }
    }
  }
}

/// A task carried across queues. `BGTask.h` names no queue for the two members, and a wake uses each once: the
/// expiration handler is kept from the launch handler, and completion is reported when the work ends.
private struct CarriedTask<Task: SystemTask>: @unchecked Sendable {
  let task: Task
}
