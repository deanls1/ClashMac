import SwiftUI

struct HomeView: View {
    @Bindable var store: AppStore

    var body: some View {
        VergeHomeView(store: store)
    }
}

#Preview {
    HomeView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
