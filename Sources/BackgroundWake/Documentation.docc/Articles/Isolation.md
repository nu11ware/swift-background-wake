# Isolation

Why a launch handler written in an app delegate traps under Swift 6, and why the block
``WakeScheduler/system`` hands `BGTaskScheduler` does not.

## Overview

`BGTaskScheduler.h` declares the launch handler of
`register(forTaskWithIdentifier:using:launchHandler:)` as a plain block, with no isolation
annotation. The usual place to register is the app delegate:

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

`UIApplicationDelegate` is isolated to the main actor, so the app delegate is too, and under
Swift 6 so is the closure written inside it. Swift checks that isolation each time the closure is
called. With `nil` for the queue, the system calls the launch handler on a default background
queue, per `BGTaskScheduler.h`. The check fails there, and the process stops with `SIGTRAP`.

The code compiles without a warning. The trap comes at the first wake, in the background.

## The block system hands the scheduler

``WakeScheduler/system`` calls the same method, but the block it passes is formed inside a
`@Sendable` closure in this library. A `@Sendable` closure is not isolated to any actor, so the
block formed inside it carries no main-actor check, whatever the isolation of the code that calls
``WakeScheduler/register(_:scheduleNext:run:)``. The work then runs in a `Task` that no actor
isolates; `await` a main-actor function from `scheduleNext` or `run` to do work there.

## What shows it

`BGTaskScheduler` exists only on iOS, iPadOS, Mac Catalyst, tvOS and visionOS, and its launch
handler is called only by the system, so the package's tests do not call it. On macOS, two exit
tests use an Objective-C stand-in with the declaration of `BGTaskScheduler`'s registration method,
and call its launch handler from a global queue:

- A launch handler formed on the main actor, as in the app delegate above, stops the test process
  with `SIGTRAP`.
- A wake registered on the main actor, through the wiring ``WakeScheduler/system`` uses with the
  stand-in in place of `BGTaskScheduler`, returns.

CI compiles ``WakeScheduler/system`` and the app delegate above for iOS, but does not run them.
