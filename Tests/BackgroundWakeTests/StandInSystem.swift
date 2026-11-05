import BackgroundWake
import ConcurrencyExtras
import Dispatch

final class StandInSystem: Sendable {
  let events = LockIsolated<[String]>([])
  let identifiers = LockIsolated<[String]>([])
  private let accepts: Bool
  private let keepsExpirationHandlerSlowly: Bool
  private let launchHandler = LockIsolated<(@Sendable (WakeTask) -> Void)?>(nil)
  private let expirationHandler = LockIsolated<(@Sendable () -> Void)?>(nil)
  private let finishes: AsyncStream<Bool>
  private let finishContinuation: AsyncStream<Bool>.Continuation

  init(accepts: Bool = true, keepsExpirationHandlerSlowly: Bool = false) {
    self.accepts = accepts
    self.keepsExpirationHandlerSlowly = keepsExpirationHandlerSlowly
    (finishes, finishContinuation) = AsyncStream.makeStream()
  }

  var scheduler: WakeScheduler {
    WakeScheduler { [identifiers, launchHandler, accepts] identifier, handler in
      identifiers.withValue { $0.append(identifier) }
      launchHandler.setValue(handler)
      return accepts
    }
  }

  func log(_ event: String) {
    events.withValue { $0.append(event) }
  }

  func launch() async {
    let task = WakeTask(
      onExpiration: { [events, expirationHandler, keepsExpirationHandlerSlowly] handler in
        if keepsExpirationHandlerSlowly {
          _ = DispatchSemaphore(value: 0).wait(timeout: .now() + .milliseconds(50))
        }
        expirationHandler.setValue(handler)
        events.withValue { $0.append("expiration handler kept") }
      },
      finish: { [events, finishContinuation] success in
        events.withValue { $0.append("finished(\(success))") }
        finishContinuation.yield(success)
      }
    )
    guard let handler = launchHandler.value else { return }
    await offTheMainQueue { handler(task) }
  }

  func expire() async {
    guard let handler = expirationHandler.value else { return }
    await offTheMainQueue(handler)
  }

  func firstFinish() async -> Bool? {
    for await success in finishes { return success }
    return nil
  }

  private func offTheMainQueue(_ body: @escaping @Sendable () -> Void) async {
    await withCheckedContinuation { continuation in
      DispatchQueue.global().async {
        body()
        continuation.resume()
      }
    }
  }
}

func sleepUntilCancelled() async {
  try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
}
