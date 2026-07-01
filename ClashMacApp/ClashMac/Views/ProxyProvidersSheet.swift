import SwiftUI

struct ProxyProvidersSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var isUpdatingAll: Bool {
        !store.updatingProviderNames.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if store.proxyProviders.isEmpty {
                ContentUnavailableView {
                    Label("暂无 Provider", systemImage: "externaldrive")
                } description: {
                    Text("当前配置未使用 proxy-providers")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.proxyProviders) { provider in
                            providerRow(provider)
                            if provider.id != store.proxyProviders.last?.id {
                                Divider().opacity(0.35)
                            }
                        }
                    }
                    .background(vergeCardBackground)
                    .padding(16)
                }
            }

            footer
        }
        .frame(width: 520, height: 420)
        .background(VergeColor.canvas)
        .task { await store.refreshProxyProviders() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive")
                .font(.body.weight(.semibold))
                .foregroundStyle(VergeColor.accent)
                .frame(width: 22, height: 22)
            Text("Proxy Provider")
                .font(VergeTypography.sectionTitle)
            Spacer()
            if !store.proxyProviders.isEmpty {
                Button("全部更新") {
                    Task { await store.updateAllProxyProviders() }
                }
                .controlSize(.small)
                .disabled(isUpdatingAll)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(VergeColor.cardFill.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle().fill(VergeColor.border).frame(height: 0.5)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(VergeColor.cardFill.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle().fill(VergeColor.border).frame(height: 0.5)
        }
    }

    private func providerRow(_ provider: ProxyProvider) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(VergeTypography.bodyMedium)
                HStack(spacing: 8) {
                    Text(provider.vehicleType)
                        .font(VergeTypography.smallMedium)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VergeColor.surface))
                        .foregroundStyle(.secondary)
                    Text("更新于 \(provider.updatedAtLabel)")
                        .font(VergeTypography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if store.updatingProviderNames.contains(provider.name) {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.updateProxyProvider(provider.name) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("更新 Provider")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    ProxyProvidersSheet(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        s.proxyProviders = [
            ProxyProvider(name: "sub-provider", vehicleType: "HTTP", updatedAt: .now),
        ]
        return s
    }())
}
