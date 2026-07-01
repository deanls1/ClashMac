import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SubscriptionView: View {
    @Bindable var store: AppStore
    @State private var renamingProfile: Profile?
    @State private var renameText = ""

    private let profileColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.subscription.pageTitle) {
                VergeHeaderIconButton(
                    symbol: store.isProfileReorderMode ? "checkmark" : "arrow.up.arrow.down",
                    help: store.isProfileReorderMode ? "完成排序" : "调整顺序"
                ) {
                    store.isProfileReorderMode.toggle()
                }
                VergeHeaderIconButton(symbol: "square.and.arrow.down", help: "导入本地") {
                    importLocalYAML()
                }
                VergeHeaderIconButton(symbol: "arrow.clockwise", help: "全部更新") {
                    Task { await store.refreshAllSubscriptions() }
                }
                .disabled(store.profiles.allSatisfy { $0.subscriptionURL == nil } || store.isRefreshingSubscriptions)
                VergeHeaderIconButton(symbol: "doc.badge.plus", help: "新建") {
                    importLocalYAML()
                }
            }
            .padding(.horizontal, VergeLayout.contentPadding)

            importBar
                .padding(.horizontal, VergeLayout.contentPadding)
                .padding(.bottom, 12)

            profileContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VergeColor.canvas)
        .sheet(item: $renamingProfile) { profile in
            renameSheet(profile)
        }
        .sheet(isPresented: $store.isProfileEditorPresented) {
            ProfileEditorSheet(store: store)
        }
    }

    @ViewBuilder
    private var profileContent: some View {
        if store.profiles.isEmpty {
            ContentUnavailableView {
                Label("暂无配置", systemImage: "tray.full")
            } description: {
                Text("在上方粘贴订阅链接，或导入本地 YAML")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.isProfileReorderMode {
            List {
                ForEach(store.profiles) { profile in
                    profileCard(for: profile, showDragHandle: true)
                        .listRowInsets(EdgeInsets(top: 6, leading: VergeLayout.contentPadding, bottom: 6, trailing: VergeLayout.contentPadding))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onMove { source, destination in
                    store.moveProfile(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        } else {
            ScrollView {
                LazyVGrid(columns: profileColumns, alignment: .leading, spacing: 10) {
                    ForEach(store.profiles) { profile in
                        profileCard(for: profile, showDragHandle: false)
                    }
                }
                .padding(VergeLayout.contentPadding)
                .frame(maxWidth: VergeLayout.pageMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func profileCard(for profile: Profile, showDragHandle: Bool = false) -> some View {
        VergeProfileCard(
            profile: profile,
            isActive: profile.id == store.activeProfile?.id,
            showDragHandle: showDragHandle,
            activate: { Task { await store.activateProfile(profile) } },
            refresh: { Task { await store.refreshSubscription(profile) } },
            refreshViaProxy: { Task { await store.refreshSubscriptionViaProxy(profile) } },
            rename: {
                renameText = profile.name
                renamingProfile = profile
            },
            editSection: { section in store.openProfileEditor(profile, section: section) },
            openFile: { store.openProfileInFinder(profile) },
            delete: { Task { await store.deleteProfile(profile) } }
        )
    }

    private func renameSheet(_ profile: Profile) -> some View {
        VergeEditorShell(
            title: "编辑信息",
            saveTitle: "保存",
            cancel: { renamingProfile = nil },
            save: {
                if !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    store.renameProfile(profile, to: renameText)
                    renamingProfile = nil
                }
            }
        ) {
            TextField("名称", text: $renameText)
                .textFieldStyle(.roundedBorder)
        }
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
        .padding(10)
        .background(vergeCardBackground)
        .frame(maxWidth: VergeLayout.pageMaxWidth)
        .frame(maxWidth: .infinity)
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

struct ProfileEditorSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VergeEditorShell(
            title: store.profileEditorTitle,
            saveTitle: "保存",
            cancel: { dismiss() },
            save: {
                Task { await store.saveProfileEditor() }
            }
        ) {
            TextEditor(text: $store.profileEditorYAML)
                .font(VergeTypography.mono)
                .padding(12)
                .background(VergeColor.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 1)
                }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}
private struct VergeProfileCard: View {
    let profile: Profile
    let isActive: Bool
    var showDragHandle = false
    let activate: () -> Void
    let refresh: () -> Void
    let refreshViaProxy: () -> Void
    let rename: () -> Void
    let editSection: (ProfileYAMLSection) -> Void
    let openFile: () -> Void
    let delete: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 0) {
            if isActive {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(VergeColor.accent)
                    .frame(width: 4)
                    .padding(.vertical, 6)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    if showDragHandle {
                        Image(systemName: "line.3.horizontal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 3)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(VergeTypography.bodyMedium)
                            .foregroundStyle(isActive ? VergeColor.accent : .primary)
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

                    Spacer(minLength: 0)

                    if isActive {
                        VergeStatusBadge(text: "当前", tone: .success)
                    }
                    if profile.subscriptionURL != nil {
                        Button(action: refresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VergeColor.accent)
                        }
                        .buttonStyle(.plain)
                        .help("更新订阅")
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

                HStack(spacing: 6) {
                    profileAction("使用", disabled: isActive, action: activate)
                    profileAction("编辑", action: { editSection(.full) })
                    if profile.subscriptionURL != nil {
                        profileAction("更新", action: refresh)
                        profileAction("代理更新", action: refreshViaProxy)
                    }
                    Spacer(minLength: 0)
                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("删除")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
        }
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VergeColor.cardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isActive ? VergeColor.accent.opacity(0.55) : VergeColor.border, lineWidth: isActive ? 1.2 : 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(count: 2) { activate() }
        .onHover { hovered = $0 }
        .contextMenu {
            Button("使用", action: activate).disabled(isActive)
            Button("编辑信息", action: rename)
            Button("编辑文件") { editSection(.full) }
            Button("编辑规则") { editSection(.rules) }
            Button("编辑节点") { editSection(.proxies) }
            Button("编辑代理组") { editSection(.proxyGroups) }
            Divider()
            Button("打开文件", action: openFile)
            if profile.subscriptionURL != nil {
                Button("更新", action: refresh)
                Button("更新（代理）", action: refreshViaProxy)
            }
            Divider()
            Button("删除", role: .destructive, action: delete)
        }
    }

    private func profileAction(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(VergeTypography.smallMedium)
            .buttonStyle(.borderless)
            .disabled(disabled)
    }
}

#Preview {
    SubscriptionView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
