# Testing

Drive a wake in a test with a scheduler and a task of your own.

## Overview

The system launches a background task only on a device, at a time it chooses. To test a wake,
create a ``WakeScheduler`` with ``WakeScheduler/init(registerLaunchHandler:)``, keep the launch
handler it receives, and call it with a ``WakeTask`` that records what the wake does:

```swift
import BackgroundWake
import Testing

@Test func aWakeReportsSuccessWhenItsWorkReturns() async {
  let (launchHandlers, registered) = AsyncStream<@Sendable (WakeTask) -> Void>.makeStream()
  let scheduler = WakeScheduler { identifier, launchHandler in
    registered.yield(launchHandler)
    return true
  }
  scheduler.register("com.example.refresh", scheduleNext: {}, run: {})

  let (finishes, finished) = AsyncStream<Bool>.makeStream()
  let task = WakeTask(
    onExpiration: { handler in },
    finish: { success in finished.yield(success) }
  )
  for await launchHandler in launchHandlers.prefix(1) {
    launchHandler(task)
  }

  #expect(await finishes.first { _ in true } == true)
}
```

Write the app's registration against a ``WakeScheduler`` it is given. The app passes
``WakeScheduler/system``, and the test passes its own. To test the system taking the time back,
keep the handler `onExpiration` receives and call it while `run` is suspended.

## What the package's tests show

`swift test` runs on macOS and Linux. The tests call the launch handler and the expiration
handler from global queues, through a stand-in scheduler and task, and show that:

- the expiration handler is kept before the work starts, even when the work ends at once;
- `scheduleNext` returns before `run` starts, and completion is reported after `run` returns;
- the expiration cancels `run`, and completion is reported as failure;
- `run` is not called when the expiration comes first;
- completion is reported once, however often the expiration arrives and however late;
- `register` returns the scheduler's answer.

On macOS, two exit tests show the trap described in <doc:Isolation>, and that a wake registered on
the main actor does not trap.

CI compiles ``WakeScheduler/system`` for iOS, Mac Catalyst, tvOS and visionOS, and the rest of
the library for watchOS, but does not run ``WakeScheduler/system``. `BGTaskScheduler.h` requires
launch handlers to be registered before the app finishes launching, `BGContinuedProcessingTask`
registrations excepted; the tests do not exercise that rule.
