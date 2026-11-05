# ``BackgroundWake``

Registers background task launch handlers that are safe to call off the main thread under Swift 6.

## Overview

Each wake keeps the expiration handler, then runs its work as a cancellable `Task`. The system's expiration cancels it, and completion is reported once. Register with ``WakeScheduler/system`` before the app finishes launching:

```swift
WakeScheduler.system.register(
  "com.example.refresh",
  scheduleNext: { await Refresh.schedule() },
  run: { await Library.shared.refresh() }
)
```

``WakeScheduler/system`` forms the block it hands `BGTaskScheduler` in a closure no actor isolates, so the Swift 6 isolation check of a main-actor closure does not fail when the system calls the block on a background queue. It exists on iOS, iPadOS, Mac Catalyst, tvOS and visionOS. The package's README covers requirements, installation, the full example and what the tests show.

## Topics

### Registering a wake

- ``WakeScheduler``
- ``WakeScheduler/system``
- ``WakeScheduler/register(_:scheduleNext:run:)``

### Testing a wake

- ``WakeScheduler/init(registerLaunchHandler:)``
- ``WakeTask``
