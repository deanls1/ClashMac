import AppKit

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    static weak var store: AppStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if NSApp.applicationIconImage == nil, let logo = NSImage(named: "AppLogo") {
            NSApp.applicationIconImage = logo
        }
        configureMainMenu()
        MenuBarManager.markApplicationReady()
        if let store = Self.store {
            MenuBarManager.shared.attach(to: store)
        }
    }

    // 关闭主窗口仅隐藏界面，应用继续驻留菜单栏；仅「退出」菜单/快捷键才真正终止。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        HotkeyService.shared.removeMonitor()
        guard let store = Self.store else { return .terminateNow }

        Task { @MainActor in
            await store.prepareForQuit()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyService.shared.removeMonitor()
    }

    private func configureMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "打开主窗口",
            action: #selector(openMainWindow(_:)),
            keyEquivalent: "o"
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "退出 Clash Mac",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func openMainWindow(_ sender: Any?) {
        MainWindowController.open()
    }

    @objc private func quitApp(_ sender: Any?) {
        AppQuit.request()
    }
}

enum AppQuit {
    @MainActor
    static func request() {
        NSApp.terminate(nil)
    }
}
