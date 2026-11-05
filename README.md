# Background Wake

[![CI](https://github.com/nu11ware/swift-background-wake/actions/workflows/ci.yml/badge.svg)](https://github.com/nu11ware/swift-background-wake/actions/workflows/ci.yml)

Cancelable, testable, and safe background tasks for Swift.

## Motivation

The usual place to register a `BGTaskScheduler` launch handler is the app delegate:

```swift
import BackgroundTasks
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.example.refresh",
      using: nil
    ) { task in
      task.setTaskCompleted(success: true)
    }
    return true
  }
}
```

Under Swift 6 this compiles without a warning, and traps with `SIGTRAP` the first time the system
calls the launch handler. The app delegate is isolated to the main actor, so the closure is too,
and Swift checks that isolation each time the closure is called. With `nil` for the queue, the
system calls the launch handler on a default background queue, per `BGTaskScheduler.h`, and the
check fails there.

`WakeScheduler.system` forms the block it hands `BGTaskScheduler` in a closure no actor isolates,
whatever the isolation of the code that registers:

```diff
-    BGTaskScheduler.shared.register(
-      forTaskWithIdentifier: "com.example.refresh",
-      using: nil
-    ) { task in
-      task.setTaskCompleted(success: true)
-    }
+    WakeScheduler.system.register(
+      Refresh.identifier,
+      scheduleNext: { await Refresh.schedule() },
+      run: { await Refresh.run() }
+    )
```

`Refresh` is defined under Usage.

On macOS, the package's exit tests show both: a launch handler formed on the main actor traps when
an Objective-C stand-in with `BGTaskScheduler`'s declaration calls it from a global queue, and a
wake registered on the main actor through the same wiring as `system` returns.

Each wake runs its work in a Swift `Task`. The system's expiration cancels that `Task`, and
completion is reported to the system once.

## Usage

List each identifier under `BGTaskSchedulerPermittedIdentifiers` in the app's `Info.plist`, and add
`fetch` (for app refresh tasks) or `processing` (for processing tasks) to `UIBackgroundModes`.
Register before the app finishes launching:

```swift
import BackgroundWake
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    WakeScheduler.system.register(
      Refresh.identifier,
      scheduleNext: { await Refresh.schedule() },
      run: { await Refresh.run() }
    )
    return true
  }
}
```

```swift
import BackgroundTasks
import Foundation

enum Refresh {
  static let identifier = "com.example.refresh"

  static func schedule() async {
    let request = BGAppRefreshTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
    try? BGTaskScheduler.shared.submit(request)
  }

  static func run() async {
    let feed = URL(string: "https://example.com/feed.json")!
    _ = try? await URLSession.shared.data(from: feed)
  }
}
```

Each wake keeps the expiration handler, awaits `scheduleNext`, then `run`, then reports completion:
success unless the system took the time back. When it does, `run` is cancelled, or skipped if it has
not started; return from it promptly once cancelled. `register` returns `false` when the identifier
is missing from `BGTaskSchedulerPermittedIdentifiers`, per `BGTaskScheduler.h`.

In tests, create a `WakeScheduler` with `init(registerLaunchHandler:)` and call the launch handler
it receives with a `WakeTask` of your own.

The library does not submit task requests, choose when the next wake comes, or replace SwiftUI's
`backgroundTask(_:action:)` modifier.

## Installation

Add the package to the dependencies in `Package.swift`:

```swift
.package(url: "https://github.com/nu11ware/swift-background-wake", from: "0.1.0"),
```

Then add the product to a target:

```swift
.product(name: "BackgroundWake", package: "swift-background-wake"),
```

In an Xcode project, choose File > Add Package Dependencies, enter
`https://github.com/nu11ware/swift-background-wake`, and add the `BackgroundWake` library to the app
target.

The library needs Swift 6.2 or later and has no runtime dependencies. `WakeScheduler.system` exists
on iOS 15, iPadOS 15, Mac Catalyst 15, tvOS 15 and visionOS 1, as `BGTaskScheduler` does. The rest
of the library builds on macOS 12, watchOS 9 and Linux, for tests.

## Contributing

Issues are open. Pull requests are by invitation: one is opened after it has been asked for on an
issue.

## Credits and thanks

Most of what we know about advanced Swift we learned from [Point-Free](https://www.pointfree.co),
from their episodes and their open-source libraries. Thank you.

This package's tests use their
[swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras) for
`LockIsolated`, `UncheckedSendable` and `withMainSerialExecutor`.

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
