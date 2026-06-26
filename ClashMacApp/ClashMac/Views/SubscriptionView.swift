import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SubscriptionView: View {
    @Bindable var store: AppStore
    @State private var renamingProfile: Profile?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.subscription.pageTitle) {
                Button { importLocalYAML() } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("导入本地")
                Button {
                    Task { await store.refreshAllSubscriptions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("全部更新")
                .disabled(store.profiles.allSatisfy { $0.subscriptionURL == nil } || store.isRefreshingSubscriptions)
                Button { importLocalYAML() } label: {
                    Image(systemName: "doc")
                }
                .help("新建")
            }

            ScrollView {
                VStack(spacing: 20) {
                    importBar
                    profileGrid
                }
                .padding(VergeLayout.contentPadding)
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)
            }
        }
        .background(VergeColor.canvas)
        .sheet(item: $renamingProfile) { profile in
            renameSheet(profile)
        }
    }

    @ViewBuilder
    private var profileGrid: some View {
        if store.profiles.isEmpty {
            ContentUnavailableView {
                Label("暂无配置", systemImage: "tray.full")
            } description: {
                Text("在上方粘贴订阅链接，或导入本地 YAML")
            }
            .padding(.top, 40)
        } else {
            VStack(spacing: 10) {
                ForEach(store.profiles) { profile in
                    VergeProfileCard(
                        profile: profile,
                        isActive: profile.id == store.activeProfile?.id,
                        activate: { Task { await store.activateProfile(profile) } },
                        refresh: { Task { await store.refreshSubscription(profile) } },
                        rename: {
                            renameText = profile.name
                            renamingProfile = profile
                        },
                        delete: { Task { await store.deleteProfile(profile) } }
                    )
                }
            }
        }
    }

    private func renameSheet(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名配置").font(.headline)
            TextField("名称", text: $renameText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { renamingProfile = nil }
                Button("保存") {
                    store.renameProfile(profile, to: renameText)
                    renamingProfile = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private var importBar: some View {
        HStack(spacing: 10) {
            VergeImportField(placeholder: "订阅文件链接", text: $store.subscriptionURLInput) {
                if let text = NSPasteboard.general.string(forType: .string) {
                    store.subscriptionURLInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            Button("导入") {
                Task { await store.importSubscription() }
            }
            .buttonStyle(.bordered)
            .disabled(store.subscriptionURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("新建") { importLocalYAML() }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
        }
    }

    private func importLocalYAML() {
        let panel = NSOpenPanel()
        if let yaml = UTType(filenameExtension: "yaml"),
           let yml = UTType(filenameExtension: "yml") {
            panel.allowedContentTypes = [yaml, yml]
        }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "选择 Mihomo / Clash 配置文件"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await store.importLocalProfile(name: store.subscriptionNameInput, from: url) }
        }
    }
}

private struct VergeProfileCard: View {
    let profile: Profile
    let isActive: Bool
    let activate: () -> Void
    let refresh: () -> Void
    let rename: () -> Void
    let delete: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 0) {
            if isActive {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(VergeColor.accent)
                    .frame(width: 4)
                    .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(VergeTypography.bodyMedium)
                            .lineLimit(1)
                        if let url = profile.subscriptionURL {
                            Text(URL(string: url)?.host ?? url)
                                .font(VergeTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("本地配置")
                                .font(VergeTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if profile.subscriptionURL != nil {
                        Button(action: refresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(VergeColor.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text(VergeRelativeTime.chinese(from: profile.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if let expires = profile.expiresAt {
                        Text(expires.formatted(.dateTime.year().month().day()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .fill(VergeColor.cardFill)
                .shadow(color: VergeColor.shadow.opacity(hovered || isActive ? 0.12 : 0.06), radius: hovered || isActive ? 8 : 4, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .strokeBorder(isActive ? VergeColor.accent.opacity(0.45) : VergeColor.border, lineWidth: isActive ? 1 : 0.5)
        }
        .scaleEffect(hovered && !isActive ? 1.008 : 1)
        .animation(.easeOut(duration: 0.15), value: hovered)
        .contentShape(RoundedRectangle(cornerRadius: VergeLayout.cardRadius))
        .onTapGesture { if !isActive { activate() } }
        .onHover { hovered = $0 }
        .contextMenu {
            Button(isActive ? "已启用" : "启用", action: activate).disabled(isActive)
            if profile.subscriptionURL != nil {
                Button("更新订阅", action: refresh)
            }
            Button("重命名", action: rename)
            Divider()
            Button("删除", role: .destructive, action: delete)
        }
    }
}

#Preview {
    SubscriptionView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
