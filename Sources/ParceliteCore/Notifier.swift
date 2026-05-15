import Foundation

public protocol NotificationPosting: Sendable {
    func post(title: String, body: String)
}

public struct OsaScriptNotifier: NotificationPosting {
    public init() {}

    public func post(title: String, body: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = [
            "-e",
            "display notification \"\(escape(body))\" with title \"\(AppConstants.appName)\" subtitle \"\(escape(title))\" sound name \"Glass\""
        ]
        try? task.run()
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
