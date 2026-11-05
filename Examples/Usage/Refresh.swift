#if os(iOS)
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
#endif
