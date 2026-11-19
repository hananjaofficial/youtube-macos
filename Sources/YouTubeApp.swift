import SwiftUI
import AppKit

@main
struct HanstePlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 540, idealWidth: 680, minHeight: 560, idealHeight: 740)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentMinSize)
        .defaultSize(width: 680, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neuer Tab") { TabStore.shared.openNewTab() }
                    .keyboardShortcut("t")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
