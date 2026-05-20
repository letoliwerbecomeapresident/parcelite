import Foundation
import UserNotifications

public protocol NotificationPosting: Sendable {
    func post(title: String, body: String)
}

public struct LocalNotificationNotifier: NotificationPosting {
    public init() {}

    public func post(title: String, body: String) {
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            NSLog("Parcelite Notification (Unbundled): %@ - %@", title, body)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        // Trigger immediately (e.g. in 0.1 seconds)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("Parcelite: Failed to post notification: %@", error.localizedDescription)
            }
        }
    }
}
