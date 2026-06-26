import SwiftUI

private enum ConnectionColumn {
    static let host: CGFloat = 220
    static let traffic: CGFloat = 100
    static let speed: CGFloat = 110
    static let rule: CGFloat = 108
    static let close: CGFloat = 28
}

struct ConnectionsView: View {
    @Bindable var store: AppStore
    @State private var selectedID: String?
    @State private var detailItem: ConnectionItem?

    private var displayList: [ConnectionItem] {
        store.connectionTab == .active ? store.filteredConnections : store.filteredClosedConnections
    }

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.connections.pageTitle) {
                trafficStat("下载量", store.trafficTotals.downloadFormatted, VergeColor.download)
                trafficStat("上传量", store.trafficTotals.uploadFormatted, VergeColor.upload)
                Button("关闭全部") { Task { await store.closeAllConnections() } }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
                    .disabled(store.connections.isEmpty || !store.coreState.isRunning)
            }

            VergeFilterBar(
                query: $store.connectionFilter,
                options: $store.connectionFilterOptions,
                placeholder: "过滤条件"
            )

            HStack(spacing: 10) {
                VergeSegmentTabs(
                    selection: $store.connectionTab,
                    items: [
                        (.active, "活跃 \(store.connections.count)"),
                        (.closed, "已关闭 \(store.closedConnections.count)")
                    ]
                )
                Spacer()
            }
            .padding(.horizontal, VergeLayout.contentPadding)
            .padding(.bottom, 10)

            if displayList.isEmpty {
                connectionsEmptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        connectionTableHeader
                        ForEach(displayList) { item in
                            VergeConnectionRow(
                                item: item,
                                isSelected: selectedID == item.id,
                                showClose: store.connectionTab == .active,
                                onSelect: { selectedID = item.id },
                                onOpen: {
                                    selectedID = item.id
                                    detailItem = item
                                },
                                onClose: { Task { await store.closeConnection(item) } }
                            )
                            if item.id != displayList.last?.id {
                                Divider().opacity(0.3).padding(.leading, 14)
                            }
                        }
                    }
                    .background(vergeCardBackground)
                    .padding(VergeLayout.contentPadding)
                }
            }
        }
        .background(VergeColor.canvas)
        .sheet(item: $detailItem) { item in
            VergeConnectionDetailSheet(item: item, isActive: store.connectionTab == .active) {
                Task { await store.closeConnection(item) }
            }
        }
        .onChange(of: store.connectionTab) { _, _ in
            selectedID = nil
            detailItem = nil
        }
        .onAppear { Task { await store.refreshConnections() } }
    }

    private func trafficStat(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(title):")
                .font(VergeTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(VergeTypography.mono)
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private var connectionsEmptyState: some View {
        ContentUnavailableView {
            Label("暂无连接", systemImage: "arrow.left.arrow.right")
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
    }

    private var emptyDescription: String {
        if !store.coreState.isRunning {
            return "启动代理后将显示实时连接"
        }
        return store.connectionTab == .active ? "当前没有活动连接" : "暂无已关闭的连接记录"
    }

    private var connectionTableHeader: some View {
        VergeTableHeader(columns: headerColumns)
    }

    private var headerColumns: [VergeTableColumn] {
        var cols = [
            VergeTableColumn(title: "主机", width: ConnectionColumn.host),
            VergeTableColumn(title: "下载量", width: ConnectionColumn.traffic),
            VergeTableColumn(title: "上传量", width: ConnectionColumn.traffic),
            VergeTableColumn(title: "下载速度", width: ConnectionColumn.speed),
            VergeTableColumn(title: "上传速度", width: ConnectionColumn.speed),
            VergeTableColumn(title: "链路", flex: true),
            VergeTableColumn(title: "规则", width: ConnectionColumn.rule),
        ]
        if store.connectionTab == .active {
            cols.append(VergeTableColumn(title: "", width: ConnectionColumn.close))
        }
        return cols
    }
}

private struct VergeConnectionRow: View {
    let item: ConnectionItem
    let isSelected: Bool
    let showClose: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onClose: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.host)
                    .font(VergeTypography.bodyMedium)
                    .lineLimit(1)
                if !item.process.isEmpty && item.process != "—" {
                    Text(item.process)
                        .font(VergeTypography.small)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: ConnectionColumn.host, alignment: .leading)

            Text(item.downloadFormatted)
                .font(VergeTypography.mono)
                .foregroundStyle(VergeColor.download)
                .frame(width: ConnectionColumn.traffic, alignment: .leading)

            Text(item.uploadFormatted)
                .font(VergeTypography.mono)
                .foregroundStyle(VergeColor.upload)
                .frame(width: ConnectionColumn.traffic, alignment: .leading)

            Text(item.downloadSpeedFormatted)
                .font(VergeTypography.mono)
                .foregroundStyle(VergeColor.download)
                .frame(width: ConnectionColumn.speed, alignment: .leading)

            Text(item.uploadSpeedFormatted)
                .font(VergeTypography.mono)
                .foregroundStyle(VergeColor.upload)
                .frame(width: ConnectionColumn.speed, alignment: .leading)

            VergeChainLabel(chain: item.chain)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.rule)
                .font(VergeTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: ConnectionColumn.rule, alignment: .leading)

            if showClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .frame(width: ConnectionColumn.close)
                .opacity(hovered || isSelected ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(count: 1) { onSelect() }
        .onTapGesture(count: 2) { onOpen() }
        .onHover { hovered = $0 }
        .help("双击查看详情")
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                VergeColor.accentSoft.opacity(0.55)
            } else if hovered {
                VergeColor.surface.opacity(0.45)
            } else {
                Color.clear
            }
        }
    }
}

private struct VergeConnectionDetailSheet: View {
    let item: ConnectionItem
    let isActive: Bool
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("连接详情")
                    .font(VergeTypography.sectionTitle)
                Spacer()
                Button("关闭") { dismiss() }
            }

            VStack(spacing: 0) {
                detailRow("主机", item.host)
                Divider().opacity(0.35)
                detailRow("进程", item.process)
                Divider().opacity(0.35)
                detailRow("规则", item.rule)
                Divider().opacity(0.35)
                HStack(alignment: .top) {
                    Text("链路")
                        .font(VergeTypography.captionMedium)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    VergeChainLabel(chain: item.chain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Divider().opacity(0.35)
                detailRow("上传", "\(item.uploadFormatted) · \(item.uploadSpeedFormatted)")
                Divider().opacity(0.35)
                detailRow("下载", "\(item.downloadFormatted) · \(item.downloadSpeedFormatted)")
                Divider().opacity(0.35)
                detailRow("开始", item.startedAt.formatted(date: .abbreviated, time: .standard))
                if let closedAt = item.closedAt {
                    Divider().opacity(0.35)
                    detailRow("结束", closedAt.formatted(date: .abbreviated, time: .standard))
                }
            }
            .background(vergeCardBackground)

            if isActive {
                Button("断开此连接", role: .destructive) {
                    onClose()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(VergeTypography.captionMedium)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(VergeTypography.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    ConnectionsView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
