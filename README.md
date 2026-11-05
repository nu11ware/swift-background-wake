# swift-background-wake

Registers background task launch handlers that are safe to call off the main thread under Swift 6. Each wake runs its work as a cancellable `Task`. The system's expiration cancels it, and completion is reported once.

It does not submit task requests, choose when the next wake comes, or replace SwiftUI's `backgroundTask(_:action:)` modifier.

## Requirements

- Swift 6.2 or later.
- iOS 15, iPadOS 15, Mac Catalyst 15, tvOS 15 or visionOS 1. `WakeScheduler.system` exists on these platforms only, as `BGTaskScheduler` does.
- macOS 12, watchOS 9 and Linux build the rest of the library, for tests.

The library has no runtime dependencies. Its tests use [swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras).

## Installation

Add the package to `Package.swift`:

```swift
.package(url: "https://github.com/nu11ware/swift-background-wake", from: "0.1.0"),
```

Then add the product to a target:

```swift
.product(name: "BackgroundWake", package: "swift-background-wake"),
```

## Usage

List each identifier under `BGTaskSchedulerPermittedIdentifiers` in the app's `Info.plist`, and add `fetch` (for app refresh tasks) or `processing` (for processing tasks) to `UIBackgroundModes`. Register before the app finishes launching:

```swift
import BackgroundTasks
import BackgroundWake
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    WakeScheduler.system.register(
      "com.example.refresh",
      scheduleNext: { await Refresh.schedule() },
      run: { await Library.shared.refresh() }
    )
    return true
  }
}

nonisolated enum Refresh {
  static func schedule() async {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
    if #available(iOS 27, *) {
      try? await BGTaskScheduler.shared.submitTaskRequest(request)
    } else {
      try? BGTaskScheduler.shared.submit(request)
    }
  }
}
```

`BGTaskScheduler.h` says not to call `submitTaskRequest(_:)` from the main thread, so `Refresh` is not isolated to the main actor.

Each wake keeps the expiration handler, awaits `scheduleNext`, then `run`, then reports completion: success unless the system took the time back. When it does, `run` is cancelled, or skipped if it has not started; return from it promptly once cancelled. `register` returns `false` when the identifier is missing from `BGTaskSchedulerPermittedIdentifiers`.

In tests, create a `WakeScheduler` with `init(registerLaunchHandler:)` and call the launch handler it receives with a `WakeTask` of your own.

## Isolation

`BGTaskScheduler.h` declares the launch handler of `register(forTaskWithIdentifier:using:launchHandler:)` as a plain block, with no isolation annotation. Under Swift 6, a closure written for that parameter in a main-actor context, such as an app delegate, is isolated to the main actor, and Swift checks that isolation each time the closure is called. With `nil` for the queue, the system calls the launch handler on a background queue, where that check fails. In the tests, on macOS, the failed check stops the process with `SIGTRAP`. `WakeScheduler.system` forms that block inside a `@Sendable` closure, which no actor isolates, whatever the isolation of the code that calls `register`.

## Checks

`swift test` runs on macOS and Linux. The tests call the launch handler and the expiration handler from global queues, through a stand-in scheduler and task, and show that:

- the expiration handler is kept before the work starts, even when the work ends at once;
- `scheduleNext` returns before `run` starts, and completion is reported after `run` returns;
- the expiration cancels `run` and completion is reported as failure;
- `run` is not called when the expiration comes first;
- completion is reported once, however often the expiration arrives and however late;
- `register` returns the scheduler's answer.

On macOS, two exit tests use an Objective-C stand-in with the declaration of `BGTaskScheduler`'s registration method. A launch handler formed on the main actor traps when called off the main thread. A wake registered on the main actor, through the wiring `system` uses with the stand-in in place of `BGTaskScheduler`, returns.

CI compiles `WakeScheduler.system` for iOS, Mac Catalyst, tvOS and visionOS, and the rest of the library for watchOS, but does not run `system`. `BGTaskScheduler.h` requires launch handlers to be registered before the app finishes launching, `BGContinuedProcessingTask` registrations excepted.

## Contributing

Issues are open. Pull requests are by invitation: one is opened after it has been asked for on an issue.

## Credits and thanks

Most of what we know about advanced Swift we learned from [Point-Free](https://www.pointfree.co), from their episodes and their open-source libraries. Thank you.

This package's tests use their [swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras) for `LockIsolated`, `UncheckedSendable` and `withMainSerialExecutor`.

## Licence

MIT. See [LICENSE](LICENSE).
