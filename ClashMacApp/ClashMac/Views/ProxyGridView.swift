import SwiftUI

struct ProxyGridView: View {
    @Bindable var store: AppStore
    @State private var searchText = ""
    @State private var expandAll = true
    @State private var hideOffline = false
    @State private var groupSortKey: ProxyGroupSortKey = .defaultOrder
    @State private var nodeSortKey: ProxyNodeSortKey = .defaultOrder

    private var filteredGroups: [ProxyGroup] {
        let base: [ProxyGroup]
        if searchText.isEmpty {
            base = store.groups
        } else {
            base = store.groups.compactMap { group in
                let nodes = group.nodes.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText)
                }
                guard !nodes.isEmpty else { return nil }
                return ProxyGroup(
                    name: group.name,
                    nodes: nodes,
                    selectedNode: group.selectedNode,
                    groupType: group.groupType
                )
            }
        }
        return sortedGroups(base)
    }

    private func sortedGroups(_ groups: [ProxyGroup]) -> [ProxyGroup] {
        switch groupSortKey {
        case .defaultOrder:
            return groups
        case .name:
            return groups.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .latency:
            return groups.sorted { groupLatencyRank($0) < groupLatencyRank($1) }
        }
    }

    private func groupLatencyRank(_ group: ProxyGroup) -> Int {
        group.nodes.compactMap(\.delay).min() ?? Int.max
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.groups.isEmpty {
                VStack(spacing: 0) {
                    header
                    emptyState
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        toolbar
                        ForEach(filteredGroups) { group in
                            VergeProxyGroupBlock(
                                store: store,
                                group: group,
                                expandAll: expandAll,
                                hideOffline: hideOffline,
                                nodeSortKey: nodeSortKey
                            )
                        }
                    }
                    .padding(VergeLayout.contentPadding)
                    .frame(maxWidth: VergeLayout.pageMaxWidth)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(VergeColor.canvas)
        .sheet(isPresented: $store.isProxyProvidersPresented) {
            ProxyProvidersSheet(store: store)
        }
        .onAppear {
            Task { await store.refreshGroupsIfNeeded() }
        }
    }

    private var header: some View {
        VergePageHeader(DashboardSection.proxy.pageTitle) {
            VergeModePills(store: store)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            VergeSearchField(placeholder: "搜索节点", text: $searchText, maxWidth: 260)

            Toggle(isOn: $hideOffline) {
                Text("隐藏离线")
                    .font(VergeTypography.caption)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Menu {
                Picker("分组", selection: $groupSortKey) {
                    ForEach(ProxyGroupSortKey.allCases) { key in
                        Text(key.label).tag(key)
                    }
                }
                Divider()
                Picker("节点", selection: $nodeSortKey) {
                    ForEach(ProxyNodeSortKey.allCases) { key in
                        Text(key.label).tag(key)
                    }
                }
            } label: {
                Label(groupSortKey.label, systemImage: "arrow.up.arrow.down")
                    .font(VergeTypography.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                store.isProxyProvidersPresented = true
                Task { await store.refreshProxyProviders() }
            } label: {
                Label("Provider", systemImage: "externaldrive")
                    .font(VergeTypography.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!store.coreState.isRunning)

            Button {
                withAnimation { expandAll.toggle() }
            } label: {
                Label(expandAll ? "全部折叠" : "全部展开", systemImage: expandAll ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .font(VergeTypography.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                Task { await store.testAllGroups() }
            } label: {
                if store.isTestingAllGroups {
                    ProgressView().controlSize(.small)
                } else {
                    Label("全部测速", systemImage: "speedometer")
                        .font(VergeTypography.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!store.coreState.isRunning || store.isTestingAllGroups)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无代理组", systemImage: "server.rack")
        } description: {
            if let err = store.runtimeDataError {
                Text(err)
            } else {
                Text(store.coreState.isRunning ? "当前配置中没有策略组" : "导入订阅并启动代理后，策略组与节点将显示在这里")
            }
        } actions: {
            if !store.coreState.isRunning {
                Button("启动代理") { Task { await store.start() } }
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
            } else {
                Button("重新加载") { Task { await store.refreshRuntimeDataWithRetry() } }
                Button("前往订阅") { store.selectedSection = .subscription }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct VergeProxyGroupBlock: View {
    @Bindable var store: AppStore
    let group: ProxyGroup
    let expandAll: Bool
    let hideOffline: Bool
    let nodeSortKey: ProxyNodeSortKey
    @State private var isExpanded = true

    private var visibleNodes: [ProxyNode] {
        let nodes = hideOffline ? group.nodes.filter(\.isAlive) : group.nodes
        return sortedNodes(nodes)
    }

    private func sortedNodes(_ nodes: [ProxyNode]) -> [ProxyNode] {
        switch nodeSortKey {
        case .defaultOrder:
            return nodes
        case .name:
            return nodes.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .latency:
            return nodes.sorted { nodeLatencyRank($0) < nodeLatencyRank($1) }
        }
    }

    private func nodeLatencyRank(_ node: ProxyNode) -> Int {
        node.delay ?? Int.max
    }

    private var selectedNode: ProxyNode? {
        group.nodes.first(where: \.isSelected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(group.name)
                                    .font(VergeTypography.sectionTitle)
                                    .lineLimit(1)
                                Text(group.groupTypeLabel)
                                    .font(VergeTypography.smallMedium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(VergeColor.surface))
                                    .foregroundStyle(.secondary)
                            }
                            if let selected = selectedNode {
                                Text(selected.name)
                                    .font(VergeTypography.caption)
                                    .foregroundStyle(VergeColor.accent)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("\(group.nodes.count)")
                            .font(VergeTypography.smallMedium.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(VergeColor.surface))
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                groupActionButton(symbol: "speedometer", help: "测速整组") {
                    Task { await store.testDelays(for: group) }
                }

                groupActionButton(symbol: "bolt.fill", help: "自动选择最快节点") {
                    Task { await store.selectFastest(in: group) }
                }
                .disabled(!store.coreState.isRunning)
            }

            if isExpanded {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 8),
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(visibleNodes) { node in
                        VergeProxyNodeCard(
                            node: node,
                            isTesting: store.testingNodeIDs.contains(node.id),
                            onSelect: { Task { await store.selectNode(group: group, node: node) } },
                            onTest: { Task { await store.testNodeDelay(group: group, node: node) } }
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background { vergeInnerCardBackground }
        .onChange(of: expandAll) { _, value in
            withAnimation { isExpanded = value }
        }
    }

    private func groupActionButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(VergeColor.surface))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview {
    ProxyGridView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
