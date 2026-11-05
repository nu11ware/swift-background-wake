#if os(macOS)
  import BackgroundWake
  import ConcurrencyExtras
  import Darwin
  import StandInBackgroundTasks
  import Testing

  struct IsolationTests {
    @Test func aLaunchHandlerFormedOnTheMainActorTrapsWhenCalledOffTheMainThread() async {
      await #expect(processExitsWith: .signal(SIGTRAP)) {
        await registerALaunchHandlerOnTheMainActorAndWake()
      }
    }

    @Test func aWakeRegisteredOnTheMainActorReturnsWhenCalledOffTheMainThread() async {
      await #expect(processExitsWith: .success) {
        await registerAWakeOnTheMainActorAndWake()
      }
    }
  }

  @MainActor
  private func registerALaunchHandlerOnTheMainActorAndWake() {
    let scheduler = StandInScheduler()
    scheduler.register(forTaskWithIdentifier: "com.example.refresh", using: nil) { task in
      task.setTaskCompleted(success: true)
    }
    scheduler.wakeOffTheMainThread()
  }

  @MainActor
  private func registerAWakeOnTheMainActorAndWake() {
    let standIn = UncheckedSendable(StandInScheduler())
    let scheduler = WakeScheduler.backgroundTasks(of: StandInTask.self) { identifier, launchHandler in
      standIn.value.register(forTaskWithIdentifier: identifier, using: nil, launchHandler: launchHandler)
    }
    scheduler.register("com.example.refresh", scheduleNext: {}, run: {})
    standIn.value.wakeOffTheMainThread()
  }

  extension StandInTask: SystemTask {}
#endif
