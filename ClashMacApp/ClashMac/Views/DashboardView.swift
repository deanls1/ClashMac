import SwiftUI

struct DashboardView: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: 0) {
            VergeSidebar(store: store)

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VergeColor.canvas)
                .id(store.selectedSection)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity
                ))
        }
        .frame(minWidth: 1000, minHeight: 680)
        .font(VergeTypography.body)
        .preferredColorScheme(store.appearance.colorScheme)
        .background(VergeColor.canvas)
        .animation(.easeInOut(duration: 0.2), value: store.selectedSection)
        .onDisappear {
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
