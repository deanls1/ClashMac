import SwiftUI

struct ProxyGridView: View {
    @Bindable var store: AppStore
    @State private var searchText = ""
    @State private var expandAll = true
    @State private var hideOffline = false

    private var filteredGroups: [ProxyGroup] {
        guard !searchText.isEmpty else { return store.groups }
        return store.groups.compactMap { group in
            let nodes = group.nodes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
            guard !nodes.isEmpty else { return nil }
            return ProxyGroup(name: group.name, nodes: nodes, selectedNode: group.selectedNode)
        }
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
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        toolbar
                        ForEach(filteredGroups) { group in
                            VergeProxyGroupBlock(
                                store: store,
                                group: group,
                                expandAll: expandAll,
                                hideOffline: hideOffline
                            )
                        }
                    }
                    .padding(VergeLayout.contentPadding)
                }
            }
        }
        .background(VergeColor.canvas)
        .onAppear { Task { await store.refreshAll() } }
    }

    private var header: some View {
        VergePageHeader(DashboardSection.proxy.pageTitle) {
            VergeModePills(store: store)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            VergeSearchField(placeholder: "搜索节点", text: $searchText, maxWidth: .infinity)

            Toggle(isOn: $hideOffline) {
                Text("隐藏离线")
                    .font(VergeTypography.caption)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Button {
                withAnimation { expandAll.toggle() }
            } label: {
                Label(expandAll ? "全部折叠" : "全部展开", systemImage: expandAll ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .font(VergeTypography.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(vergeCardBackground)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无代理组", systemImage: "server.rack")
        } description: {
            Text(store.coreState.isRunning ? "当前配置中没有策略组" : "导入订阅并启动代理后，策略组与节点将显示在这里")
        } actions: {
            if !store.coreState.isRunning {
                Button("启动代理") { Task { await store.start() } }
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
            } else {
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
    @State private var isExpanded = true

    private var visibleNodes: [ProxyNode] {
        hideOffline ? group.nodes.filter(\.isAlive) : group.nodes
    }

    private var selectedNode: ProxyNode? {
        group.nodes.first(where: \.isSelected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        groupIcon
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(group.name)
                                    .font(VergeTypography.sectionTitle)
                                Text("Selector")
                                    .font(VergeTypography.smallMedium)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(VergeColor.surface))
                                    .foregroundStyle(.secondary)
                            }
                            if let selected = selectedNode {
                                HStack(spacing: 4) {
                                    if let flag = NodeNameParser.countryFlag(from: selected.name) {
                                        Text(flag)
                                    }
                                    Text(selected.name)
                                        .font(VergeTypography.caption)
                                        .foregroundStyle(VergeColor.accent)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        Text("\(group.nodes.count)")
                            .font(VergeTypography.smallMedium.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 24, minHeight: 24)
                            .background(Circle().fill(VergeColor.surface))
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    Task { await store.testDelays(for: group) }
                } label: {
                    Image(systemName: "speedometer")
                        .font(.body)
                        .foregroundStyle(VergeColor.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(VergeColor.accentSoft))
                }
                .buttonStyle(.plain)
                .help("测速整组")
            }

            if isExpanded {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 156, maximum: 220), spacing: 10)],
                    spacing: 10
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
        .padding(16)
        .background(vergeCardBackground)
        .onChange(of: expandAll) { _, value in
            withAnimation { isExpanded = value }
        }
    }

    private var groupIcon: some View {
        ZStack {
            Circle()
                .fill(VergeColor.accentSoft)
                .frame(width: 32, height: 32)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VergeColor.accent)
        }
    }
}

#Preview {
    ProxyGridView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
