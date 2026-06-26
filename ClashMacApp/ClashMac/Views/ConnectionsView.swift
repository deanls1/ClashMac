import SwiftUI

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
                Text("下载量: \(store.trafficTotals.downloadFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("上传量: \(store.trafficTotals.uploadFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("关闭全部") { Task { await store.closeAllConnections() } }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
                    .disabled(store.connections.isEmpty)
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
            .padding(.bottom, 8)

            if displayList.isEmpty {
                ContentUnavailableView("暂无连接", systemImage: "arrow.left.arrow.right", description: Text("启动代理后将显示实时连接"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VergeColor.canvas)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        connectionTableHeader
                        ForEach(displayList) { item in
                            VergeConnectionRow(
                                item: item,
                                isSelected: selectedID == item.id,
                                showClose: store.connectionTab == .active
                            ) {
                                selectedID = item.id
                            } onOpen: {
                                selectedID = item.id
                                detailItem = item
                            } onClose: {
                                Task { await store.closeConnection(item) }
                            }
                            Divider().opacity(0.35).padding(.leading, 14)
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

    private var connectionTableHeader: some View {
        HStack(spacing: 0) {
            headerCell("主机", width: 200)
            headerCell("下载量", width: 72)
            headerCell("上传量", width: 72)
            headerCell("下载速度", width: 76)
            headerCell("上传速度", width: 76)
            headerCell("链路", flex: true)
            headerCell("规则", width: 96)
            if store.connectionTab == .active {
                Spacer().frame(width: 24)
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(VergeColor.surface.opacity(0.6))
    }

    private func headerCell(_ text: String, width: CGFloat? = nil, flex: Bool = false) -> some View {
        Group {
            if flex {
                Text(text).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text).frame(width: width, alignment: .leading)
            }
        }
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

    private var isDirect: Bool {
        item.chain.uppercased().contains("DIRECT")
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(item.host)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)

            Text(item.downloadFormatted)
                .font(.caption.monospacedDigit())
                .foregroundStyle(VergeColor.download)
                .frame(width: 72, alignment: .leading)

            Text(item.uploadFormatted)
                .font(.caption.monospacedDigit())
                .foregroundStyle(VergeColor.upload)
                .frame(width: 72, alignment: .leading)

            Text(item.downloadSpeedFormatted)
                .font(.caption.monospacedDigit())
                .foregroundStyle(VergeColor.download)
                .frame(width: 76, alignment: .leading)

            Text(item.uploadSpeedFormatted)
                .font(.caption.monospacedDigit())
                .foregroundStyle(VergeColor.upload)
                .frame(width: 76, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: isDirect ? "globe" : "point.3.connected.trianglepath.dotted")
                    .font(.caption2)
                    .foregroundStyle(isDirect ? .secondary : VergeColor.accent)
                Text(item.chain)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.rule)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)

            if showClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .frame(width: 24)
            }
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? VergeColor.accentSoft.opacity(0.5) : (hovered ? VergeColor.surface : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture(count: 1) { onSelect() }
        .onTapGesture(count: 2) { onOpen() }
        .onHover { hovered = $0 }
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
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Button("关闭") { dismiss() }
            }

            VStack(spacing: 0) {
                detailRow("主机", item.host)
                Divider().opacity(0.4)
                detailRow("进程", item.process)
                Divider().opacity(0.4)
                detailRow("规则", item.rule)
                Divider().opacity(0.4)
                detailRow("链路", item.chain)
                Divider().opacity(0.4)
                detailRow("上传", "\(item.uploadFormatted) · \(item.uploadSpeedFormatted)/s")
                Divider().opacity(0.4)
                detailRow("下载", "\(item.downloadFormatted) · \(item.downloadSpeedFormatted)/s")
                Divider().opacity(0.4)
                detailRow("开始", item.startedAt.formatted(date: .abbreviated, time: .standard))
                if let closedAt = item.closedAt {
                    Divider().opacity(0.4)
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
        .frame(width: 480)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

#Preview {
    ConnectionsView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
