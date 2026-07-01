import AppKit
import SwiftUI

@MainActor
enum MainWindowController {
    private static var openWindowAction: OpenWindowAction?
    private static var fallbackWindow: NSWindow?

    static func register(openWindow: OpenWindowAction) {
        openWindowAction = openWindow
    }

    static func open(section: DashboardSection? = nil) {
        guard let store = AppLifecycleDelegate.store else { return }
        if let section {
            store.selectedSection = section
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if focusExistingDashboard() { return }

        if let openWindowAction {
            openWindowAction(id: "dashboard")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                centerDashboardWindows()
                if !focusExistingDashboard() {
                    presentFallbackWindow(store: store)
                }
            }
            return
        }

        presentFallbackWindow(store: store)
    }

    /// 关闭仪表板窗口并释放界面资源（轻量模式用）：关闭 SwiftUI Window 场景窗口与回退窗口，
    /// 让 SwiftUI 释放视图树，仅保留内核与菜单栏。
    static func closeDashboard() {
        for window in NSApp.windows where isDashboardWindow(window) {
            window.close()
        }
        fallbackWindow?.close()
        fallbackWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }

    static func dashboardDidClose() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard !hasVisibleDashboard() else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @discardableResult
    private static func focusExistingDashboard() -> Bool {
        for window in NSApp.windows where isDashboardWindow(window) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return true
        }
        if let fallbackWindow {
            fallbackWindow.makeKeyAndOrderFront(nil)
            fallbackWindow.orderFrontRegardless()
            return true
        }
        return false
    }

    private static func hasVisibleDashboard() -> Bool {
        NSApp.windows.contains { isDashboardWindow($0) && $0.isVisible }
            || (fallbackWindow?.isVisible == true)
    }

    private static func isDashboardWindow(_ window: NSWindow) -> Bool {
        if window.title == "Clash Mac" { return true }
        if window.identifier?.rawValue.contains("dashboard") == true { return true }
        return window.identifier?.rawValue == "com.clashmac.dashboard"
    }

    private static func centerDashboardWindows() {
        for window in NSApp.windows where isDashboardWindow(window) {
            window.center()
        }
    }

    private static func presentFallbackWindow(store: AppStore) {
        if let fallbackWindow {
            fallbackWindow.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: DashboardView(store: store))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1024, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = "Clash Mac"
        window.identifier = NSUserInterfaceItemIdentifier("com.clashmac.dashboard")
        window.minSize = NSSize(width: 960, height: 640)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = FallbackWindowDelegate.shared
        fallbackWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class FallbackWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = FallbackWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        MainWindowController.dashboardDidClose()
    }
}

private struct DashboardOpenWindowRegistrar: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                MainWindowController.register(openWindow: openWindow)
            }
    }
}

extension View {
    func registerDashboardOpenWindow() -> some View {
        background(DashboardOpenWindowRegistrar())
    }
}
