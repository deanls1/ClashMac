import SwiftUI

struct ConnectionsView: View {
    @Bindable var store: AppStore
    @State private var tableSelection = Set<ConnectionItem.ID>()
    @State private var detailItem: ConnectionItem?
    @State private var sortOrder: [KeyPathComparator<ConnectionItem>] = [
        KeyPathComparator(\.downloadSpeed, order: .reverse)
    ]

    private var filteredList: [ConnectionItem] {
        store.connectionTab == .active ? store.searchedConnections : store.searchedClosedConnections
    }

    private var selectedItem: ConnectionItem? {
        guard let id = tableSelection.first else { return nil }
        return filteredList.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.connections.pageTitle) {
                trafficStat("下载量", store.trafficTotals.downloadFormatted, VergeColor.download)
                trafficStat("上传量", store.trafficTotals.uploadFormatted, VergeColor.upload)
                if let selectedItem {
                    Button("详情") { detailItem = selectedItem }
                        .controlSize(.small)
                }
                Button("关闭全部") { Task { await store.closeAllConnections() } }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
                    .disabled(store.connections.isEmpty || !store.coreState.isRunning)
            }
            .padding(.horizontal, VergeLayout.contentPadding)

            VergeFilterBar(
                query: $store.connectionFilter,
                options: $store.connectionFilterOptions,
                placeholder: "过滤条件"
            )

            HStack(spacing: 10) {
                VergeSegmentedControl(
                    selection: $store.connectionTab,
                    items: [
                        (value: .active, label: "活跃 \(store.connections.count)"),
                        (value: .closed, label: "已关闭 \(store.closedConnections.count)")
                    ]
                )

                Text("点击列头排序")
                    .font(VergeTypography.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding(.horizontal, VergeLayout.contentPadding)
            .padding(.bottom, 10)

            if filteredList.isEmpty {
                connectionsEmptyState
            } else {
                connectionsTable
            }
        }
        .background(VergeColor.canvas)
        .sheet(item: $detailItem) { item in
            VergeConnectionDetailSheet(item: item, isActive: store.connectionTab == .active) {
                Task { await store.closeConnection(item) }
            }
        }
        .onChange(of: store.connectionTab) { _, _ in
            tableSelection = []
            detailItem = nil
        }
        .onAppear { Task { await store.refreshConnections() } }
    }

    private var connectionsTable: some View {
        Table(filteredList, selection: $tableSelection, sortOrder: $sortOrder) {
            TableColumn("主机", value: \.host) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.host)
                        .font(VergeTypography.bodyMedium)
                        .lineLimit(1)
                    if !item.process.isEmpty && item.process != "—" {
                        Text(item.process)
                            .font(VergeTypography.bodyMedium)
                            .foregroundStyle(VergeColor.accent)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 140, ideal: 220)

            TableColumn("下载量", value: \.download) { item in
                Text(item.downloadFormatted)
                    .font(VergeTypography.mono)
                    .foregroundStyle(VergeColor.download)
            }
            .width(min: 72, ideal: 100)

            TableColumn("上传量", value: \.upload) { item in
                Text(item.uploadFormatted)
                    .font(VergeTypography.mono)
                    .foregroundStyle(VergeColor.upload)
            }
            .width(min: 72, ideal: 100)

            TableColumn("下载速度", value: \.downloadSpeed) { item in
                Text(item.downloadSpeedFormatted)
                    .font(VergeTypography.mono)
                    .foregroundStyle(VergeColor.download)
            }
            .width(min: 80, ideal: 110)

            TableColumn("上传速度", value: \.uploadSpeed) { item in
                Text(item.uploadSpeedFormatted)
                    .font(VergeTypography.mono)
                    .foregroundStyle(VergeColor.upload)
            }
            .width(min: 80, ideal: 110)

            TableColumn("链路", value: \.chain) { item in
                VergeChainLabel(chain: item.chain)
            }
            .width(min: 120)

            TableColumn("规则", value: \.rule) { item in
                Text(item.rule)
                    .font(VergeTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 88, ideal: 108)

            if store.connectionTab == .active {
                TableColumn("") { item in
                    Button {
                        Task { await store.closeConnection(item) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("断开连接")
                }
                .width(28)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .padding(.horizontal, VergeLayout.contentPadding)
        .padding(.bottom, VergeLayout.contentPadding)
        .frame(maxWidth: VergeLayout.pageMaxWidth)
        .frame(maxWidth: .infinity)
        .onKeyPress(.return) {
            if let selectedItem {
                detailItem = selectedItem
                return .handled
            }
            return .ignored
        }
        .contextMenu(forSelectionType: ConnectionItem.ID.self) { selection in
            if let id = selection.first, let item = filteredList.first(where: { $0.id == id }) {
                Button("查看详情") { detailItem = item }
                if store.connectionTab == .active {
                    Button("断开连接", role: .destructive) {
                        Task { await store.closeConnection(item) }
                    }
                }
            }
        }
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
}

private struct VergeConnectionDetailSheet: View {
    let item: ConnectionItem
    let isActive: Bool
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(VergeColor.accent)
                    .frame(width: 22, height: 22)
                Text("连接详情")
                    .font(VergeTypography.sectionTitle)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(VergeColor.cardFill.opacity(0.92))
            .overlay(alignment: .bottom) {
                Rectangle().fill(VergeColor.border).frame(height: 0.5)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
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
            .padding(16)

            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                if isActive {
                    Button("断开此连接", role: .destructive) {
                        onClose()
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(VergeColor.cardFill.opacity(0.92))
            .overlay(alignment: .top) {
                Rectangle().fill(VergeColor.border).frame(height: 0.5)
            }
        }
        .background(VergeColor.canvas)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

#Preview {
    ConnectionsView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
