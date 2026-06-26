import SwiftUI

struct DNSOverwriteSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var config = DNSConfig.vergeDefault
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DNS 覆写")
                    .font(.title2.weight(.bold))
                Spacer()
                Button("重置为默认值") {
                    config = .vergeDefault
                }
                .foregroundStyle(VergeColor.upload)
                Button(showAdvanced ? "可视化" : "YAML 预览") {
                    showAdvanced.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
            }
            .padding()

            Text("如果你不清楚这里的设置请不要修改，并保持 DNS 覆写开启")
                .font(.caption)
                .foregroundStyle(VergeColor.upload)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showAdvanced {
                        Text("以下为当前 DNS 配置的 YAML 预览（只读）。修改请使用可视化表单。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: .constant(config.yamlBlock(includePrivilegedListen: store.tunEnabled)))
                            .font(.caption.monospaced())
                            .frame(minHeight: 360)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(VergeColor.surface))
                            .disabled(true)
                    } else {
                        dnsToggle("启用 DNS", $config.enable)
                        dnsField("DNS 监听地址", $config.listen)
                        dnsPicker("增强模式", selection: $config.enhancedMode, options: ["fake-ip", "redir-host"])
                        dnsField("Fake IP 范围", $config.fakeIPRange)
                        dnsPicker("Fake IP 过滤模式", selection: $config.fakeIPFilterMode, options: ["blacklist", "whitelist"])
                        dnsToggle("IPv6", $config.ipv6, subtitle: "启用 IPv6 DNS 解析")
                        dnsToggle("优先使用 HTTP/3", $config.preferH3, subtitle: "DNS DOH 使用 HTTP/3 协议")
                        dnsToggle("遵循路由规则", $config.respectRules, subtitle: "DNS 连接遵循路由规则")
                        dnsToggle("使用 Hosts", $config.useHosts)
                        dnsToggle("使用系统 Hosts", $config.useSystemHosts)
                        dnsToggle("直连域名服务器遵循策略", $config.directNameserverFollowPolicy)

                        dnsTextArea("默认域名服务器", text: bindingList(\.defaultNameserver), subtitle: "用于解析 DNS 服务器的默认 DNS 服务器")
                        dnsTextArea("域名服务器", text: bindingList(\.nameserver), subtitle: "DNS 服务器列表，用逗号分隔")
                        dnsTextArea("代理服务器域名服务器", text: bindingList(\.proxyServerNameserver))
                        dnsTextArea("直连域名服务器", text: bindingList(\.directNameserver), subtitle: "直连出口域名解析服务器，支持 system 关键字")
                        dnsTextArea("Fake IP 过滤", text: bindingList(\.fakeIPFilter), subtitle: "跳过 Fake IP 解析的域名")
                        dnsTextArea("域名服务器策略", text: $config.nameserverPolicyText, subtitle: "格式: domain=server1;server2")
                        dnsTextArea("Hosts", text: $config.hostsText, subtitle: "格式: domain=ip")
                    }
                }
                .padding()
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    store.saveDNSConfig(config)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
            }
            .padding()
        }
        .frame(width: 560, height: showAdvanced ? 520 : 640)
        .onAppear { config = store.dnsConfig }
    }

    private func bindingList(_ keyPath: WritableKeyPath<DNSConfig, [String]>) -> Binding<String> {
        Binding(
            get: { config[keyPath: keyPath].joined(separator: ", ") },
            set: { config[keyPath: keyPath] = DNSConfig.parseList($0) }
        )
    }

    private func dnsToggle(_ title: String, _ binding: Binding<Bool>, subtitle: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: binding).labelsHidden()
        }
    }

    private func dnsField(_ title: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(title).frame(width: 140, alignment: .leading)
            TextField(title, text: binding).textFieldStyle(.roundedBorder)
        }
    }

    private func dnsPicker(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            Text(title).frame(width: 140, alignment: .leading)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
        }
    }

    private func dnsTextArea(_ title: String, text: Binding<String>, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            TextEditor(text: text)
                .font(.caption.monospaced())
                .frame(minHeight: 56)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).strokeBorder(VergeColor.border))
        }
    }
}
