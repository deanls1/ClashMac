import AppKit
import SwiftUI

/// Clash Verge 风格状态栏托盘菜单
struct MenuBarTrayMenu: View {
    @Bindable var store: AppStore

    private let maxTrayGroups = 16
    private let maxTrayNodesPerGroup = 12

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

        proxyMenu

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

        Button("复制代理环境变量") {
            store.copyProxyEnvironment()
        }
        .disabled(!store.coreState.isRunning)

        Button("关闭全部连接") {
            Task { await store.closeAllConnections() }
        }
        .disabled(!store.coreState.isRunning || store.connections.isEmpty)

        Divider()

        Menu("打开目录") {
            Button("配置目录") {
                NSWorkspace.shared.open(RuntimeConfigBuilder.appSupportDirectory())
            }
            Button("Profile 目录") {
                NSWorkspace.shared.open(ProfileStore.profilesDirectory())
            }
            Button("GeoData 目录") {
                NSWorkspace.shared.open(GeoDataUpdateService.geoDirectory())
            }
            Button("内核目录") {
                NSWorkspace.shared.open(CoreUpdateService.coreDirectory())
            }
        }

        Menu("更多") {
            Button("设置") {
                MainWindowController.open()
                store.selectedSection = .settings
            }
            Button("检查内核更新") {
                Task { await store.checkCoreUpdate() }
            }
            Button("下载/更新内核") {
                Task { await store.updateCore() }
            }
            Button("检查 GeoData") {
                Task { await store.checkGeoData() }
            }
            Button("下载 GeoData") {
                Task { await store.updateGeoData() }
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

    @ViewBuilder
    private var proxyMenu: some View {
        Menu("代理") {
            if store.groups.isEmpty {
                Text("暂无代理组").disabled(true)
            } else {
                ForEach(store.groups.prefix(maxTrayGroups)) { group in
                    Menu(group.name) {
                        ForEach(group.nodes.prefix(maxTrayNodesPerGroup)) { node in
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
                        if group.nodes.count > maxTrayNodesPerGroup {
                            Text("还有 \(group.nodes.count - maxTrayNodesPerGroup) 个节点…").disabled(true)
                        }
                    }
                }
                if store.groups.count > maxTrayGroups {
                    Divider()
                    Text("还有 \(store.groups.count - maxTrayGroups) 个策略组").disabled(true)
                }
                Divider()
                Button("在仪表板中打开…") {
                    MainWindowController.open()
                    store.selectedSection = .proxy
                }
            }
        }
    }
}
