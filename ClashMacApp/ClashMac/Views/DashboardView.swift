import AppKit
import SwiftUI

struct DashboardView: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: 0) {
            VergeSidebar(store: store)

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VergeColor.canvas)
        }
        .frame(minWidth: 1000, minHeight: 680)
        .font(VergeTypography.body)
        .preferredColorScheme(store.appearance.colorScheme)
        .background(VergeColor.canvas)
        .onChange(of: store.selectedSection) { _, section in
            // 规则页的数据/过滤刷新由 RulesView.onAppear 独占，避免与此处重复触发导致双倍开销。
            store.syncLogStreamForVisibleSection()
            store.syncLiveDataForSection(section)
        }
        .onChange(of: store.logsSource) { _, _ in
            store.syncLogStreamForVisibleSection()
        }
        .onAppear {
            store.setDashboardVisible(true)
            DispatchQueue.main.async {
                for window in NSApp.windows where window.title == "Clash Mac" {
                    window.center()
                }
            }
        }
        .onDisappear {
            store.setDashboardVisible(false)
            MainWindowController.dashboardDidClose()
        }
        .sheet(isPresented: $store.isRulesEditorPresented) {
            RulesEditorSheet(store: store)
        }
        .sheet(isPresented: $store.isDNSOverwritePresented) {
            DNSOverwriteSheet(store: store)
        }
        .sheet(isPresented: $store.isTUNConfigPresented) {
            TUNConfigSheet(store: store)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch store.selectedSection {
        case .home: HomeView(store: store)
        case .proxy: ProxyGridView(store: store)
        case .subscription: SubscriptionView(store: store)
        case .connections: ConnectionsView(store: store)
        case .rules: RulesView(store: store)
        case .logs: LogsView(store: store)
        case .unlock: UnlockView(store: store)
        case .settings: SettingsDetailView(store: store)
        }
    }
}

#Preview {
    DashboardView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
