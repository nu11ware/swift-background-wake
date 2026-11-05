#if os(iOS)
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
#endif
