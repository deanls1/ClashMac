import SwiftUI

struct RulesView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.rules.pageTitle) {
                Text("\(store.rules.count) 条")
                    .font(VergeTypography.captionMedium)
                    .foregroundStyle(.secondary)
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
                ContentUnavailableView {
                    Label("暂无规则", systemImage: "list.bullet.rectangle")
                } description: {
                    Text(emptyDescription)
                } actions: {
                    if !store.coreState.isRunning {
                        Button("启动代理") { Task { await store.start() } }
                            .buttonStyle(.borderedProminent)
                            .tint(VergeColor.accent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        rulesTableHeader
                        ForEach(Array(store.filteredRules.enumerated()), id: \.element.id) { offset, rule in
                            VergeRuleRow(rule: rule, displayIndex: rule.index + 1) {
                                Task { await store.toggleRule(rule) }
                            }
                            if offset < store.filteredRules.count - 1 {
                                Divider().opacity(0.3).padding(.leading, 52)
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

    private var emptyDescription: String {
        store.coreState.isRunning ? "当前没有匹配的规则" : "启动代理后从 Mihomo 加载规则"
    }

    private var rulesTableHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 36, alignment: .trailing)
            Text("匹配项")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("类型")
                .frame(width: 108, alignment: .leading)
            Text("策略")
                .frame(width: 140, alignment: .leading)
        }
        .font(VergeTypography.captionMedium)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(VergeColor.surface.opacity(0.55))
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

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(displayIndex)")
                .font(VergeTypography.small.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)

            Text(domainText)
                .font(VergeTypography.body)
                .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            VergeRuleTypeBadge(type: rule.type)
                .frame(width: 108, alignment: .leading)

            VergePolicyLabel(policy: rule.proxy)
                .frame(width: 140, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(hovered ? VergeColor.surface.opacity(0.45) : Color.clear)
        .opacity(rule.isEnabled ? 1 : 0.45)
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
                .font(VergeTypography.sectionTitle)

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
                    .font(VergeTypography.sectionTitle)
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
                .font(VergeTypography.mono)
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
