import AppKit
import SwiftUI

@MainActor
final class MenuBarManager {
    static let shared = MenuBarManager()
    private(set) static var applicationIsReady = false

    private var statusItem: NSStatusItem?
    private weak var store: AppStore?
    private var observationTask: Task<Void, Never>?
    private let menuDelegate = TrayMenuDelegate()

    static func markApplicationReady() {
        applicationIsReady = true
    }

    func attach(to store: AppStore) {
        self.store = store
        menuDelegate.onMenuWillOpen = { [weak self] in
            guard let self, let store = self.store else { return }
            store.prepareTrayMenuPresentation()
            self.rebuildMenu()
            Task { @MainActor in
                await store.refreshTrayMenuData()
                self.rebuildMenu()
            }
        }
        menuDelegate.onMenuDidClose = { [weak self] in
            self?.rebuildMenu()
        }
        installStatusItemIfNeeded()
        refresh()
        startObserving()
    }

    func refresh() {
        refreshIconAndTooltip()
        rebuildMenu()
    }

    func refreshIconAndTooltip() {
        guard let store else { return }
        installStatusItemIfNeeded()
        guard let button = statusItem?.button else { return }
        button.image = iconImage(for: store)
        button.toolTip = trayToolTip(for: store)
    }

    private func rebuildMenu() {
        guard let store else { return }
        let menu = NSHostingMenu(rootView: MenuBarTrayMenu(store: store))
        menu.delegate = menuDelegate
        statusItem?.menu = menu
    }

    private func trayToolTip(for store: AppStore) -> String {
        var parts = ["Clash Mac", store.coreState.statusTitle, store.mode.label]
        if store.coreState.isRunning {
            if store.tunModeToggleValue {
                parts.append("TUN")
            } else if store.systemProxyToggleValue {
                parts.append("系统代理")
            } else if store.systemProxyEnabled {
                parts.append("系统代理待生效")
            }
        }
        return parts.joined(separator: " · ")
    }

    private func iconImage(for store: AppStore) -> NSImage? {
        if let custom = MenuBarIconStore.loadImage(from: store.customMenuBarIconPath) {
            return custom
        }
        return MenuBarIconStore.defaultTrayTemplateIcon()
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        guard Self.applicationIsReady else { return }
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }

    private func startObserving() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            self?.observeStoreChanges()
        }
    }

    private func observeStoreChanges() {
        guard !Task.isCancelled, let store else { return }
        // 仅追踪影响「图标 + 工具提示」的状态。菜单内容（节点/连接数/分组等）在 menuWillOpen 时
        // 按需 rebuild，无需在后台对每次连接/分组刷新都重建 NSHostingMenu（此前是主要 CPU 热点）。
        withObservationTracking {
            _ = store.coreState
            _ = store.mode
            _ = store.systemProxyEnabled
            _ = store.tunEnabled
            _ = store.isSystemProxyActive
            _ = store.isTunRuntimeActive
            _ = store.tunModeToggleValue
            _ = store.systemProxyToggleValue
            _ = store.menuBarIconRevision
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refreshIconAndTooltip()
                self?.observeStoreChanges()
            }
        }
    }
}

@MainActor
private final class TrayMenuDelegate: NSObject, NSMenuDelegate {
    var onMenuWillOpen: (() -> Void)?
    var onMenuDidClose: (() -> Void)?

    func menuWillOpen(_ menu: NSMenu) {
        onMenuWillOpen?()
    }

    func menuDidClose(_ menu: NSMenu) {
        onMenuDidClose?()
    }
}
