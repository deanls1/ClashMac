import SwiftUI

struct RulesView: View {
    @Bindable var store: AppStore
    @State private var filterDebounceTask: Task<Void, Never>?

    private var hasActiveFilter: Bool {
        !store.rulesFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.rules.pageTitle) {
                if store.isLoadingRules && store.rules.isEmpty {
                    ProgressView().controlSize(.small)
                }
                Text("\(store.rulesMatchCount.formatted()) 条")
                    .font(VergeTypography.captionMedium)
                    .foregroundStyle(.secondary)
                Button("添加规则") { store.isAddRulePresented = true }
                    .controlSize(.small)
                Button("编辑 YAML") { store.loadRulesEditor() }
                    .controlSize(.small)
                Button("刷新") { Task { await store.refreshRules() } }
                    .controlSize(.small)
                    .disabled(!store.coreState.isRunning || store.isLoadingRules)
            }
            .padding(.horizontal, VergeLayout.contentPadding)

            VergeFilterBar(
                query: $store.rulesFilter,
                options: $store.rulesFilterOptions,
                placeholder: "过滤条件"
            )
            .onChange(of: store.rulesFilter) { _, _ in debounceFilter() }
            .onChange(of: store.rulesFilterOptions) { _, _ in store.scheduleRulesFilterRebuild() }

            Group {
                if !store.rules.isEmpty {
                    rulesTable
                } else if store.displayedRuleIndices.isEmpty && hasActiveFilter && !store.isRulesFilterPending {
                    noMatchState
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VergeColor.canvas)
        .sheet(isPresented: $store.isAddRulePresented) {
            VergeAddRuleSheet(store: store)
        }
        .onAppear {
            if store.displayedRuleIndices.isEmpty, !store.rules.isEmpty {
                store.scheduleRulesFilterRebuild()
            }
            Task { await store.refreshRulesOnRulesPageAppear() }
        }
    }

    private var rulesTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tableHeaderText("#", width: 54, alignment: .trailing)
                tableHeaderText("类型", width: 96)
                tableHeaderText("规则", alignment: .leading)
                tableHeaderText("策略", width: 130)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(VergeColor.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(VergeColor.border).frame(height: 0.5)
            }

            RulesVirtualTableView(
                rules: store.rules,
                indices: store.displayedRuleIndices,
                dataRevision: store.rulesDataRevision,
                onToggle: { rule in
                    Task { await store.toggleRule(rule) }
                }
            )
        }
        .background(vergeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous))
        .padding(.horizontal, VergeLayout.contentPadding)
        .padding(.bottom, VergeLayout.contentPadding)
        .frame(maxWidth: VergeLayout.pageMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private func tableHeaderText(
        _ text: String,
        width: CGFloat? = nil,
        alignment: Alignment = .leading
    ) -> some View {
        Text(text)
            .font(VergeTypography.smallMedium)
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无规则", systemImage: "list.bullet.rectangle")
        } description: {
            Text(emptyDescription)
        } actions: {
            if !store.coreState.isRunning {
                Button("启动代理") { Task { await store.start() } }
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
            } else {
                Button("重新加载") { Task { await store.refreshRules() } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noMatchState: some View {
        ContentUnavailableView {
            Label("无匹配规则", systemImage: "magnifyingglass")
        } description: {
            Text("尝试调整过滤条件")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func debounceFilter() {
        filterDebounceTask?.cancel()
        filterDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            store.scheduleRulesFilterRebuild()
        }
    }

    private var emptyDescription: String {
        if store.isLoadingRules {
            return "正在后台加载规则…"
        }
        if let err = store.runtimeDataError { return err }
        return store.coreState.isRunning ? "当前没有规则" : "启动代理后从 Mihomo 加载规则"
    }
}

private struct VergeAddRuleSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VergeEditorShell(
            title: "添加规则",
            saveTitle: "添加并重载",
            cancel: { dismiss() },
            save: {
                Task { await store.addVisualRule(); dismiss() }
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
            Picker("类型", selection: $store.newRuleType) {
                ForEach(RuleAddType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            VergeImportField(placeholder: "匹配值（如 google.com）", text: $store.newRulePayload)
            VergeImportField(placeholder: "策略组", text: $store.newRuleProxy)
            }
            }
        .frame(width: 400)
    }
}

struct RulesEditorSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VergeEditorShell(
            title: "编辑规则 (YAML)",
            saveTitle: "保存并重载",
            cancel: { dismiss() },
            save: {
                Task { await store.saveRulesAndReload() }
            }
        ) {
            TextEditor(text: $store.rulesYAML)
                .font(VergeTypography.mono)
                .padding(12)
                .background(VergeColor.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 1)
                }
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
