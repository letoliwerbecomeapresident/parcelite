import SwiftUI
import AppKit
import ParceliteCore

@main
struct ParceliteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        MainActor.assumeIsolated {
            let store = TrackingStore()

            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            w.title = AppConstants.appName
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("ParceliteMainWindow")
            w.contentView = NSHostingView(
                rootView: ContentView().environmentObject(store)
            )
            if w.frameAutosaveName.isEmpty || w.frame.origin == .zero {
                w.center()
            }
            w.makeKeyAndOrderFront(nil)
            self.window = w
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
