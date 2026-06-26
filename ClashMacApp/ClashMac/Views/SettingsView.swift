import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader

            Form {
                Section {
                    Button {
                        importProfile()
                    } label: {
                        Label("导入本地 YAML", systemImage: "doc.badge.plus")
                    }

                    Text("配置文件保存在 Application Support/ClashMac/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("配置")
                }

                Section {
                    Toggle("系统代理", isOn: $store.systemProxyEnabled)
                        .onChange(of: store.systemProxyEnabled) { _, v in
                            Task { await store.setSystemProxyEnabled(v) }
                        }
                    Toggle("系统代理守护", isOn: $store.proxyGuardEnabled)
                        .onChange(of: store.proxyGuardEnabled) { _, v in
                            store.setProxyGuardEnabled(v)
                        }
                    Text("守护每 5 秒检查一次，若被其他应用修改则自动恢复。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("系统代理")
                }

                Section {
                    LabeledContent("Helper") {
                        Text(store.helperStatus)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("内核") {
                        Text(store.version)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("运行时")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 360)
    }

    private var settingsHeader: some View {
        HStack {
            Text("设置")
                .font(.headline)
            Spacer()
            Button("完成") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        if let yaml = UTType(filenameExtension: "yaml"),
           let yml = UTType(filenameExtension: "yml") {
            panel.allowedContentTypes = [yaml, yml]
        }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "选择 Mihomo / Clash 配置文件"

        if panel.runModal() == .OK, let url = panel.url {
            try? FileManager.default.createDirectory(
                at: RuntimeConfigBuilder.appSupportDirectory(),
                withIntermediateDirectories: true
            )
            let dest = RuntimeConfigBuilder.profileConfigURL()
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
        }
    }
}

#Preview {
    SettingsView(store: AppStore())
}
