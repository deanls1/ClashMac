import SwiftUI

struct LogsView: View {
    @Bindable var store: AppStore
    @State private var reverseOrder = false

    private var activeEntries: [LogEntry] {
        store.logsSource == .core ? store.filteredLogs : store.filteredAppLogs
    }

    private var displayedLogs: [LogEntry] {
        reverseOrder ? activeEntries.reversed() : activeEntries
    }

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.logs.pageTitle) {
                logSourcePicker
                VergeHeaderIconButton(symbol: store.logsPaused ? "play.fill" : "pause.fill", help: store.logsPaused ? "继续" : "暂停") {
                    store.logsPaused.toggle()
                }
                VergeHeaderIconButton(symbol: "arrow.up.arrow.down", help: "反转顺序") {
                    reverseOrder.toggle()
                }
                Button("清除") {
                    if store.logsSource == .core {
                        store.clearLogs()
                    } else {
                        store.clearAppLogs()
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
            }
            .padding(.horizontal, VergeLayout.contentPadding)

            logsFilterBar

            if displayedLogs.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "doc.text")
                } description: {
                    Text(emptyDescription)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(displayedLogs) { entry in
                                VergeLogRow(entry: entry)
                                    .id(entry.id)
                                Divider().opacity(0.2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .background(vergeCardBackground)
                    .padding(.horizontal, VergeLayout.contentPadding)
                    .padding(.bottom, VergeLayout.contentPadding)
                    .frame(maxWidth: VergeLayout.pageMaxWidth)
                    .frame(maxWidth: .infinity)
                    .onChange(of: activeEntries.count) { _, _ in
                        guard !store.logsPaused, !reverseOrder, let last = activeEntries.last else { return }
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(VergeColor.canvas)
        .onAppear { store.syncLogStreamForVisibleSection() }
        .onChange(of: store.logsSource) { _, _ in store.syncLogStreamForVisibleSection() }
    }

    private var emptyTitle: String {
        store.logsSource == .core ? "暂无内核日志" : "暂无应用日志"
    }

    private var emptyDescription: String {
        switch store.logsSource {
        case .core:
            store.coreState.isRunning ? "等待 Mihomo 输出…" : "启动代理后将显示内核日志"
        case .app:
            "应用启动、Helper、API 请求等事件会记录在这里"
        }
    }

    private var logSourcePicker: some View {
        VergeSegmentedControl(
            selection: $store.logsSource,
            items: LogsSource.allCases.map { (value: $0, label: $0.label) }
        )
    }

    private var logsFilterBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $store.logsDisplayFilter) {
                ForEach(LogsDisplayFilter.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 88)

            VergeSearchField(placeholder: "过滤条件", text: $store.logsFilter, maxWidth: .infinity)

            filterToggle("Aa", isOn: $store.logsFilterOptions.caseSensitive)
            filterToggle("ab", isOn: $store.logsFilterOptions.wholeWord)
            filterToggle(".*", isOn: $store.logsFilterOptions.useRegex)
        }
        .padding(.horizontal, VergeLayout.contentPadding)
        .padding(.bottom, 8)
        .frame(maxWidth: VergeLayout.pageMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private func filterToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .toggleStyle(.button)
            .font(VergeTypography.smallMedium)
    }
}

#Preview {
    LogsView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        s.logEntries = [
            LogEntry(level: .info, message: "[TCP] 198.18.0.1:63579 --> api2.cursor.sh:443"),
        ]
        s.appendAppLog(level: .info, message: "Clash Mac 启动")
        return s
    }())
}
