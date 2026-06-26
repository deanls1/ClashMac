import SwiftUI

struct LogsView: View {
    @Bindable var store: AppStore
    @State private var reverseOrder = false

    private var displayedLogs: [LogEntry] {
        reverseOrder ? store.filteredLogs.reversed() : store.filteredLogs
    }

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.logs.pageTitle) {
                VergeHeaderIconButton(symbol: store.logsPaused ? "play.fill" : "pause.fill", help: store.logsPaused ? "继续" : "暂停") {
                    store.logsPaused.toggle()
                }
                VergeHeaderIconButton(symbol: "arrow.up.arrow.down", help: "反转顺序") {
                    reverseOrder.toggle()
                }
                Button("清除") { store.clearLogs() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
            }

            logsFilterBar

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(displayedLogs) { entry in
                            VergeLogBlock(entry: entry)
                                .id(entry.id)
                            Divider().opacity(0.2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(vergeCardBackground)
                .padding(VergeLayout.contentPadding)
                .onChange(of: store.filteredLogs.count) { _, _ in
                    guard !store.logsPaused, !reverseOrder, let last = store.filteredLogs.last else { return }
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .background(VergeColor.canvas)
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
    }

    private func filterToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .toggleStyle(.button)
            .font(.caption.weight(.medium))
    }
}

private struct VergeLogBlock: View {
    let entry: LogEntry

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(Self.timestampFormatter.string(from: entry.timestamp))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(entry.level.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(levelColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(levelColor.opacity(0.12)))
            }
            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var levelColor: Color {
        switch entry.level {
        case .info: VergeColor.accent
        case .warning: VergeColor.upload
        case .error: VergeColor.danger
        case .debug: Color.purple
        }
    }
}

#Preview {
    LogsView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        s.logEntries = [
            LogEntry(level: .info, message: "[TCP] 198.18.0.1:63579 --> api2.cursor.sh:443 match DomainSuffix(cursor.sh) using Cursor[新加坡]"),
            LogEntry(level: .info, message: "[TCP] 198.18.0.1:63580 --> github.com:443 match Match using 手动切换[新加坡]"),
            LogEntry(level: .warning, message: "[DNS] slow response from 223.5.5.5"),
        ]
        return s
    }())
}
