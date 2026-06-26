import AppKit
import SwiftUI

/// Clash Verge 风格状态栏托盘菜单（图4）
struct MenuBarTrayMenu: View {
    @Bindable var store: AppStore

    var body: some View {
        Button("仪表板") {
            MainWindowController.open()
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

        Menu("代理") {
            ForEach(store.groups.prefix(8)) { group in
                Menu(group.name) {
                    ForEach(group.nodes.prefix(20)) { node in
                        Button {
                            Task { await store.selectNode(group: group, node: node) }
                        } label: {
                            if node.isSelected {
                                Label(node.name, systemImage: "checkmark")
                            } else {
                                Text(node.name)
                            }
                        }
                    }
                }
            }
            if store.groups.isEmpty {
                Text("暂无代理组").disabled(true)
            }
        }

        Divider()

        Toggle("系统代理", isOn: Binding(
            get: { store.systemProxyEnabled },
            set: { v in Task { await store.setSystemProxyEnabled(v) } }
        ))

        Toggle("TUN 模式", isOn: Binding(
            get: { store.tunEnabled },
            set: { v in Task { await store.setTunEnabled(v) } }
        ))

        Divider()

        Menu("打开目录") {
            Button("配置目录") {
                NSWorkspace.shared.open(RuntimeConfigBuilder.appSupportDirectory())
            }
            Button("Profile 目录") {
                NSWorkspace.shared.open(ProfileStore.profilesDirectory())
            }
            Button("内核目录") {
                NSWorkspace.shared.open(RuntimeConfigBuilder.workDirectory())
            }
        }

        Menu("更多") {
            Button("设置") {
                MainWindowController.open()
                store.selectedSection = .settings
            }
            Button("检查更新") {
                Task { await store.updateCore() }
            }
            Button("导出诊断信息") {
                let url = store.exportDiagnostic()
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }

        Divider()

        Button("退出") {
            AppQuit.request()
        }
        .keyboardShortcut("q")
    }
}
