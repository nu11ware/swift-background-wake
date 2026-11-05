#if os(iOS)
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
#endif
