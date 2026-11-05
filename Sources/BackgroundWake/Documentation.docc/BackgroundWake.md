# ``BackgroundWake``

Cancelable, testable, and safe background tasks for Swift.

## Overview

A wake is the work an app does each time the system launches one of its background tasks. Register
it with ``WakeScheduler/system`` before the app finishes launching:

```swift
WakeScheduler.system.register(
  Refresh.identifier,
  scheduleNext: { await Refresh.schedule() },
  run: { await Refresh.run() }
)
```

Each wake keeps the expiration handler, then runs `scheduleNext` and `run` in a `Task`. The
system's expiration cancels that `Task`, and completion is reported once. The block handed to
`BGTaskScheduler` is formed in a closure no actor isolates, so it does not trap when the system
calls it on a background queue under Swift 6.

``WakeScheduler/system`` exists on iOS, iPadOS, Mac Catalyst, tvOS and visionOS. The rest of the
library builds on macOS, watchOS and Linux, for tests.

## Topics

### Essentials

- <doc:Isolation>
- <doc:Testing>

### Registering a wake

- ``WakeScheduler``
- ``WakeScheduler/system``
- ``WakeScheduler/register(_:scheduleNext:run:)``

### Testing a wake

- ``WakeScheduler/init(registerLaunchHandler:)``
- ``WakeTask``
