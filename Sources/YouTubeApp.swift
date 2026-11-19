import SwiftUI
import AppKit

@main
struct HanstePlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, idealWidth: 480, minHeight: 560, idealHeight: 740)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neuer Tab") { TabStore.shared.newTab(url: Service.youtube.home) }
                    .keyboardShortcut("t")
                Button("Tab schließen") { TabStore.shared.closeSelected() }
                    .keyboardShortcut("w")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
