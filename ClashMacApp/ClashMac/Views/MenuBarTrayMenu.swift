import AppKit
import SwiftUI

/// Clash Verge 风格状态栏托盘菜单
struct MenuBarTrayMenu: View {
    @Bindable var store: AppStore

    var body: some View {
        Text(store.trayStatusLine)
            .disabled(true)

        Divider()

        Button("仪表板") {
            MainWindowController.open()
        }

        Button("进入轻量模式") {
            store.enterLightweightMode()
        }

        Menu("出站模式 (\(store.mode.label))") {
            ForEach(RunMode.allCases) { mode in
                Button {
                    Task { await store.setMode(mode) }
                } label: {
                    if store.mode == mode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Text(mode.label)
                    }
                }
            }
        }

        Menu("订阅") {
            ForEach(store.profiles) { profile in
                Button {
                    Task { await store.activateProfile(profile) }
                } label: {
                    if profile.id == store.activeProfile?.id {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
            }
            if store.profiles.isEmpty {
                Text("暂无配置").disabled(true)
            }
        }

        Divider()

        Toggle("系统代理", isOn: Binding(
            get: { store.systemProxyToggleValue },
            set: { v in Task { await store.setSystemProxyEnabled(v) } }
        ))
        .disabled(!store.coreState.isRunning || store.isPowerTransitioning)

        Toggle("TUN 模式", isOn: Binding(
            get: { store.tunModeToggleValue },
            set: { v in Task { await store.setTunEnabled(v) } }
        ))
        .disabled(!store.coreState.isRunning || store.isPowerTransitioning)

        Divider()

        Button("复制代理环境变量") {
            store.copyProxyEnvironment()
        }
        .disabled(!store.coreState.isRunning)

        Divider()

        Button("退出") {
            AppQuit.request()
        }
        .keyboardShortcut("q")
    }
}
