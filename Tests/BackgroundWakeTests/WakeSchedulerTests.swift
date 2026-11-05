import BackgroundWake
import ConcurrencyExtras
import Testing

@Suite(.serialized)
struct WakeSchedulerTests {
  @Test func aWakeKeepsTheExpirationHandlerThenSchedulesTheNextThenRunsThenReportsSuccess() async {
    let system = StandInSystem()
    system.scheduler.register(
      "com.example.refresh",
      scheduleNext: {
        system.log("scheduleNext began")
        await Task.yield()
        system.log("scheduleNext returned")
      },
      run: {
        system.log("run began")
        await Task.yield()
        system.log("run returned")
      }
    )

    await system.launch()

    #expect(await system.firstFinish() == true)
    #expect(
      system.events.value == [
        "expiration handler kept",
        "scheduleNext began",
        "scheduleNext returned",
        "run began",
        "run returned",
        "finished(true)",
      ]
    )
  }

  @Test func theExpirationHandlerIsKeptBeforeQuickWorkReportsCompletion() async {
    let system = StandInSystem(keepsExpirationHandlerSlowly: true)
    system.scheduler.register("com.example.refresh", scheduleNext: {}, run: {})

    await system.launch()

    #expect(await system.firstFinish() == true)
    #expect(system.events.value == ["expiration handler kept", "finished(true)"])
  }

  @Test(arguments: [true, false])
  func registeringReportsWhetherTheSchedulerAcceptedTheIdentifier(accepts: Bool) {
    let system = StandInSystem(accepts: accepts)

    let registered = system.scheduler.register("com.example.refresh", scheduleNext: {}, run: {})

    #expect(registered == accepts)
    #expect(system.identifiers.value == ["com.example.refresh"])
  }

  @Test func theSystemTakingTheTimeBackCancelsTheWorkAndReportsFailureWhenItEnds() async {
    let system = StandInSystem()
    let (started, start) = AsyncStream<Void>.makeStream()
    system.scheduler.register(
      "com.example.refresh",
      scheduleNext: {},
      run: {
        system.log("run began")
        start.finish()
        await sleepUntilCancelled()
        system.log("run returned, cancelled: \(Task.isCancelled)")
      }
    )

    await system.launch()
    for await _ in started {}
    await system.expire()

    #expect(await system.firstFinish() == false)
    #expect(
      system.events.value == [
        "expiration handler kept",
        "run began",
        "run returned, cancelled: true",
        "finished(false)",
      ]
    )
  }

  @MainActor
  @Test func completionIsReportedOnceHoweverOftenTheTimeIsTakenBack() async {
    await withMainSerialExecutor {
      let system = StandInSystem()
      let (started, start) = AsyncStream<Void>.makeStream()
      system.scheduler.register(
        "com.example.refresh",
        scheduleNext: {},
        run: {
          start.finish()
          await sleepUntilCancelled()
          system.log("run returned")
        }
      )

      await system.launch()
      for await _ in started {}
      async let first: Void = system.expire()
      async let second: Void = system.expire()
      async let third: Void = system.expire()
      _ = await (first, second, third)
      #expect(await system.firstFinish() == false)
      await Task.megaYield()
      await system.expire()
      await Task.megaYield()

      #expect(
        system.events.value == ["expiration handler kept", "run returned", "finished(false)"])
    }
  }

  @MainActor
  @Test func theSystemTakingTheTimeBackAfterTheWorkEndsChangesNothing() async {
    await withMainSerialExecutor {
      let system = StandInSystem()
      system.scheduler.register("com.example.refresh", scheduleNext: {}, run: {})

      await system.launch()
      #expect(await system.firstFinish() == true)
      await system.expire()
      await Task.megaYield()

      #expect(system.events.value == ["expiration handler kept", "finished(true)"])
    }
  }

  @Test func theSystemTakingTheTimeBackBeforeTheWorkStartsSkipsTheWork() async {
    let system = StandInSystem()
    let (started, start) = AsyncStream<Void>.makeStream()
    let (expired, expire) = AsyncStream<Void>.makeStream()
    system.scheduler.register(
      "com.example.refresh",
      scheduleNext: {
        system.log("scheduleNext began")
        start.finish()
        for await _ in expired {}
        system.log("scheduleNext returned")
      },
      run: { system.log("run began") }
    )

    await system.launch()
    for await _ in started {}
    await system.expire()
    expire.finish()

    #expect(await system.firstFinish() == false)
    #expect(
      system.events.value == [
        "expiration handler kept",
        "scheduleNext began",
        "scheduleNext returned",
        "finished(false)",
      ]
    )
  }
}
