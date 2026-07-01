import AppKit
import SwiftUI

@main
struct ClashMacApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @State private var store = AppStore()

    var body: some Scene {
        Window("Clash Mac", id: "dashboard") {
            DashboardView(store: store)
                .registerDashboardOpenWindow()
        }
        .defaultSize(width: 1024, height: 680)
        .defaultLaunchBehavior(.suppressed)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("打开主窗口") {
                    MainWindowController.open()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            CommandGroup(replacing: .appTermination) {
                Button("退出 Clash Mac") {
                    AppQuit.request()
                }
                .keyboardShortcut("q")
            }
        }
    }
}
