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
                    VStack(alignment: .leading, spacing: 16) {
                        header
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无代理组", systemImage: "server.rack")
        } description: {
            Text("导入订阅并启动代理后，策略组与节点将显示在这里")
        } actions: {
            Button("前往订阅") { store.selectedSection = .subscription }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        groupIcon
                        Text(group.name)
                            .font(.headline)
                        Text("Selector")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VergeColor.surface))
                            .foregroundStyle(.secondary)
                        if let selected = group.nodes.first(where: \.isSelected) {
                            if let flag = NodeNameParser.countryFlag(from: selected.name) {
                                Text(flag).font(.caption)
                            }
                        }
                        Spacer()
                        Text("\(group.nodes.count)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(VergeColor.surface))
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                Button {
                    Task { await store.testDelays(for: group) }
                } label: {
                    Image(systemName: "speedometer")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }

            if isExpanded {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: VergeLayout.nodeCardMinWidth), spacing: 10)],
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
                .fill(VergeColor.running.opacity(0.15))
                .frame(width: 28, height: 28)
            Image(systemName: group.name.contains("Google") ? "magnifyingglass" : "arrow.triangle.2.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VergeColor.running)
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
