import AppKit
import SwiftUI

@main
struct ClashMacApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @State private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarTrayMenu(store: store)
        } label: {
            MenuBarIcon(
                isRunning: store.coreState.isRunning,
                style: store.menuBarIconStyle,
                customPath: store.customMenuBarIconPath
            )
        }
        .menuBarExtraStyle(.menu)

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

private struct MenuBarIcon: View {
    let isRunning: Bool
    let style: MenuBarIconStyle
    let customPath: String?

    var body: some View {
        Group {
            if let customPath, let image = menuBarImage(from: customPath) {
                Image(nsImage: image)
            } else {
                Image(systemName: style.symbol(running: isRunning))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isRunning ? Color.accentColor : Color.primary)
            }
        }
    }

    private func menuBarImage(from path: String) -> NSImage? {
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }
}
