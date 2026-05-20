import SwiftUI
import AppKit
import UserNotifications
import ParceliteCore

@main
struct ParceliteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(delegate.store)
        } label: {
            Image(systemName: delegate.store.anyInTransit ? "box.truck.fill" : "box.truck")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TrackingStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if Bundle.main.bundlePath.hasSuffix(".app") {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    NSLog("Parcelite: Notification authorization failed: %@", error.localizedDescription)
                }
            }
        } else {
            NSLog("Parcelite: Running unbundled. Native notifications are disabled.")
        }

        setupBackgroundScheduler(store: store)
    }

    private func setupBackgroundScheduler(store: TrackingStore) {
        let scheduler = NSBackgroundActivityScheduler(identifier: "com.oliwer.parcelite.backgroundRefresh")
        scheduler.repeats = true
        scheduler.interval = 3600 // Hourly refresh
        scheduler.tolerance = 900  // 15-minute tolerance

        scheduler.schedule { completion in
            Task { @MainActor in
                await store.refreshAll()
                completion(.finished)
            }
        }
    }
}
