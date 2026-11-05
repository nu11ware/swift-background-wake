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
