import SwiftUI

struct RulesView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.rules.pageTitle) {
                Button("添加规则") { store.isAddRulePresented = true }
                    .controlSize(.small)
                Button("编辑 YAML") { store.loadRulesEditor() }
                    .controlSize(.small)
            }

            VergeFilterBar(
                query: $store.rulesFilter,
                options: $store.rulesFilterOptions,
                placeholder: "过滤条件"
            )

            if store.filteredRules.isEmpty {
                ContentUnavailableView("暂无规则", systemImage: "list.bullet.rectangle", description: Text("启动代理后从 Mihomo 加载"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(store.filteredRules.enumerated()), id: \.element.id) { offset, rule in
                            VergeRuleRow(rule: rule, displayIndex: rule.index + 1) {
                                Task { await store.toggleRule(rule) }
                            }
                            if offset < store.filteredRules.count - 1 {
                                Divider().opacity(0.35).padding(.leading, 48)
                            }
                        }
                    }
                    .background(vergeCardBackground)
                    .padding(VergeLayout.contentPadding)
                }
            }
        }
        .background(VergeColor.canvas)
        .sheet(isPresented: $store.isAddRulePresented) {
            VergeAddRuleSheet(store: store)
        }
        .onAppear { Task { await store.refreshRules() } }
    }
}

private struct VergeRuleRow: View {
    let rule: RuleItem
    let displayIndex: Int
    let onToggle: () -> Void
    @State private var hovered = false

    private var domainText: String {
        rule.payload.isEmpty ? rule.type : rule.payload
    }

    private var typeLabel: String {
        rule.type
            .replacingOccurrences(of: "DOMAIN-SUFFIX", with: "DomainSuffix")
            .replacingOccurrences(of: "DOMAIN", with: "Domain")
            .replacingOccurrences(of: "IP-CIDR", with: "IPCIDR")
            .replacingOccurrences(of: "GEOSITE", with: "GeoSite")
            .replacingOccurrences(of: "GEOIP", with: "GeoIP")
            .replacingOccurrences(of: "MATCH", with: "Match")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(displayIndex)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 28, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                Text(domainText)
                    .font(.subheadline)
                    .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                Text(typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VergePolicyLabel(policy: rule.proxy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(hovered ? VergeColor.surface.opacity(0.5) : Color.clear)
        .opacity(rule.isEnabled ? 1 : 0.5)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onToggle() }
        .onHover { hovered = $0 }
        .help("双击切换启用状态")
    }
}

private struct VergeAddRuleSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("添加规则")
                .font(.system(.title3, design: .rounded, weight: .bold))

            Picker("类型", selection: $store.newRuleType) {
                ForEach(RuleAddType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            VergeImportField(placeholder: "匹配值（如 google.com）", text: $store.newRulePayload)
            VergeImportField(placeholder: "策略组", text: $store.newRuleProxy)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加并重载") {
                    Task { await store.addVisualRule(); dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

struct RulesEditorSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("编辑规则 (YAML)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
                Button("取消") { dismiss() }
                Button("保存并重载") {
                    Task { await store.saveRulesAndReload() }
                }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            TextEditor(text: $store.rulesYAML)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(VergeColor.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(width: 600, height: 460)
    }
}

#Preview {
    RulesView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
