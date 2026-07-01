import SwiftUI

struct DNSOverwriteSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var config = DNSConfig.vergeDefault
    @State private var isVisual = true
    @State private var yamlText = ""
    @State private var yamlError: String?

    var body: some View {
        VStack(spacing: 0) {
            VergeConfigSheetHeader(
                title: "DNS 设置",
                symbol: "globe",
                onReset: resetToDefaults,
                trailing: AnyView(VergeConfigEditorModeToggle(isVisual: $isVisual))
            )

            VergeConfigWarningBanner(
                message: "如果你不清楚这些设置，请保持 DNS 覆写开启并使用默认值。配置将写入独立文件并覆盖订阅中的 DNS 段。"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isVisual {
                        generalSection
                        nameserverSection
                        fallbackFilterSection
                        hostsSection
                    } else {
                        yamlSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            if let yamlError {
                Text(yamlError)
                    .font(VergeTypography.caption)
                    .foregroundStyle(VergeColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            VergeConfigSheetFooter(
                onCancel: { dismiss() },
                onSave: save,
                saveDisabled: yamlError != nil && !isVisual
            )
        }
        .frame(width: 580, height: 680)
        .background(VergeColor.canvas)
        .onAppear {
            config = store.dnsConfig
            refreshYAMLFromConfig()
        }
        .onChange(of: isVisual) { _, visual in
            if visual {
                applyYAMLToConfigIfPossible()
            } else {
                refreshYAMLFromConfig()
            }
        }
        .onChange(of: config) { _, _ in
            guard isVisual else { return }
            refreshYAMLFromConfig()
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VergeConfigSectionTitle(title: "常规")
            VergeConfigToggleRow(title: "启用 DNS", isOn: $config.enable)
            VergeConfigListDivider()
            VergeConfigFieldRow(
                title: "监听地址",
                subtitle: store.tunEnabled ? "TUN 模式下写入配置" : "非 TUN 模式不会监听 53 端口",
                text: $config.listen,
                placeholder: ":53"
            )
            VergeConfigListDivider()
            VergeConfigSegmentRow(
                title: "增强模式",
                selection: $config.enhancedMode,
                options: [("fake-ip", "fake-ip"), ("redir-host", "redir-host")]
            )
            VergeConfigListDivider()
            VergeConfigFieldRow(
                title: "Fake IP 范围",
                text: $config.fakeIPRange,
                placeholder: "198.18.0.1/16"
            )
            VergeConfigListDivider()
            VergeConfigSegmentRow(
                title: "Fake IP 过滤模式",
                selection: $config.fakeIPFilterMode,
                options: [("blacklist", "blacklist"), ("whitelist", "whitelist")]
            )
            VergeConfigListDivider()
            VergeConfigToggleRow(title: "IPv6", subtitle: "启用 IPv6 DNS 解析", isOn: $config.ipv6)
            VergeConfigListDivider()
            VergeConfigToggleRow(title: "优先 HTTP/3", subtitle: "DoH 使用 HTTP/3", isOn: $config.preferH3)
            VergeConfigListDivider()
            VergeConfigToggleRow(title: "遵循路由规则", subtitle: "DNS 连接遵循路由规则", isOn: $config.respectRules)
            VergeConfigListDivider()
            VergeConfigToggleRow(title: "使用 Hosts", isOn: $config.useHosts)
            VergeConfigListDivider()
            VergeConfigToggleRow(title: "使用系统 Hosts", isOn: $config.useSystemHosts)
            VergeConfigListDivider()
            VergeConfigToggleRow(
                title: "直连 NS 遵循策略",
                isOn: $config.directNameserverFollowPolicy
            )
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var nameserverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VergeConfigSectionTitle(title: "域名服务器")
            VergeConfigTextAreaRow(
                title: "默认域名服务器",
                subtitle: "解析 DNS 服务器域名时使用，支持 system",
                text: bindingList(\.defaultNameserver),
                minHeight: 72
            )
            VergeConfigTextAreaRow(
                title: "域名服务器",
                subtitle: "主 DNS 列表，逗号分隔",
                text: bindingList(\.nameserver),
                minHeight: 72
            )
            VergeConfigTextAreaRow(
                title: "Fallback",
                subtitle: "备用 DNS，通常留空",
                text: bindingList(\.fallback),
                minHeight: 56
            )
            VergeConfigTextAreaRow(
                title: "代理服务器域名服务器",
                text: bindingList(\.proxyServerNameserver),
                minHeight: 64
            )
            VergeConfigTextAreaRow(
                title: "直连域名服务器",
                subtitle: "支持 system 关键字",
                text: bindingList(\.directNameserver),
                minHeight: 64
            )
            VergeConfigTextAreaRow(
                title: "Fake IP 过滤",
                subtitle: "跳过 Fake IP 的域名",
                text: bindingList(\.fakeIPFilter),
                minHeight: 88
            )
            VergeConfigTextAreaRow(
                title: "域名服务器策略",
                subtitle: "格式：domain=server1;server2",
                text: $config.nameserverPolicyText,
                minHeight: 64
            )
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var fallbackFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VergeConfigSectionTitle(title: "Fallback Filter")
            VergeConfigToggleRow(title: "GeoIP", isOn: $config.fallbackGeoip)
            VergeConfigListDivider()
            VergeConfigFieldRow(
                title: "GeoIP 国家码",
                text: $config.fallbackGeoipCode,
                placeholder: "CN"
            )
            VergeConfigListDivider()
            VergeConfigTextAreaRow(
                title: "IP CIDR",
                text: bindingList(\.fallbackIpcidr),
                minHeight: 56
            )
            VergeConfigListDivider()
            VergeConfigTextAreaRow(
                title: "Domain",
                subtitle: "触发 fallback 的域名后缀",
                text: bindingList(\.fallbackDomain),
                minHeight: 64
            )
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var hostsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VergeConfigSectionTitle(title: "Hosts")
            VergeConfigTextAreaRow(
                title: "Hosts 覆写",
                subtitle: "格式：domain=ip 或 domain=ip1;ip2",
                text: $config.hostsText,
                minHeight: 72
            )
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var yamlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VergeConfigSectionTitle(title: "高级编辑")
            Text("直接编辑 YAML。切回「可视化」前会自动尝试解析。")
                .font(VergeTypography.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $yamlText)
                .font(VergeTypography.mono)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 480)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VergeColor.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(VergeColor.border, lineWidth: 0.5)
                        }
                }
                .onChange(of: yamlText) { _, _ in
                    yamlError = nil
                }
        }
        .padding(14)
        .background(sectionBackground)
    }

    // MARK: - Actions

    private func resetToDefaults() {
        config = .vergeDefault
        yamlError = nil
        refreshYAMLFromConfig()
    }

    private func save() {
        if isVisual {
            store.saveDNSConfig(config)
            dismiss()
            return
        }
        do {
            let parsed = try DNSDocumentCodec.decode(yamlText)
            store.saveDNSConfig(parsed)
            dismiss()
        } catch {
            yamlError = error.localizedDescription
        }
    }

    private func refreshYAMLFromConfig() {
        yamlText = DNSDocumentCodec.encode(config, includePrivilegedListen: store.tunEnabled)
    }

    private func applyYAMLToConfigIfPossible() {
        guard !yamlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            config = try DNSDocumentCodec.decode(yamlText)
            yamlError = nil
        } catch {
            yamlError = "YAML 解析失败：\(error.localizedDescription)"
        }
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
            .fill(VergeColor.cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                    .strokeBorder(VergeColor.border, lineWidth: 0.5)
            }
    }

    private func bindingList(_ keyPath: WritableKeyPath<DNSConfig, [String]>) -> Binding<String> {
        Binding(
            get: { config[keyPath: keyPath].joined(separator: ", ") },
            set: { config[keyPath: keyPath] = DNSConfig.parseList($0) }
        )
    }
}
