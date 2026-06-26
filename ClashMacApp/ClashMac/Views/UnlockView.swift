import SwiftUI

struct UnlockView: View {
    @Bindable var store: AppStore
    @State private var showAddForm = false

    var body: some View {
        VStack(spacing: 0) {
            VergePageHeader(DashboardSection.unlock.pageTitle) {
                Button {
                    showAddForm.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .help("添加自定义检测")
                Button {
                    Task { await store.runUnlockTests() }
                } label: {
                    Label("测试全部", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
                .disabled(!store.coreState.isRunning)
            }

            ScrollView {
                VStack(spacing: 16) {
                    if showAddForm {
                        addForm
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14),
                        ],
                        spacing: 14
                    ) {
                        ForEach(store.unlockTargets) { target in
                            VergeUnlockCard(target: target) {
                                Task { await store.runSingleUnlockTest(target) }
                            }
                        }
                    }
                }
                .padding(VergeLayout.contentPadding)
                .frame(maxWidth: .infinity)
            }
        }
        .background(VergeColor.canvas)
    }

    private var addForm: some View {
        HStack(spacing: 10) {
            VergeImportField(placeholder: "名称", text: $store.customUnlockName, width: 140)
            VergeImportField(placeholder: "检测 URL", text: $store.customUnlockURL)
            Button("添加") {
                store.addCustomUnlockTarget()
                showAddForm = false
            }
            .buttonStyle(.borderedProminent)
            .tint(VergeColor.accent)
            .disabled(store.customUnlockName.isEmpty || store.customUnlockURL.isEmpty)
        }
        .padding(16)
        .background(vergeCardBackground)
    }
}

private struct VergeUnlockCard: View {
    let target: UnlockTarget
    let onTest: () -> Void
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(target.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer()
                Button(action: onTest) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VergeColor.accent)
                        .padding(6)
                        .background(Circle().fill(VergeColor.accentSoft))
                }
                .buttonStyle(.plain)
                .disabled(target.status == .testing)
            }

            HStack(spacing: 8) {
                statusBadge
                if let code = target.regionCode {
                    regionBadge(code)
                }
                Spacer()
            }

            Spacer(minLength: 0)

            if let tested = target.lastTestedAt {
                Text(tested.formatted(date: .numeric, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .frame(minHeight: 120, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .fill(VergeColor.cardFill)
                .shadow(color: hovered ? VergeColor.shadow : VergeColor.shadow.opacity(0.3), radius: hovered ? 12 : 6, y: hovered ? 4 : 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .strokeBorder(hovered ? VergeColor.accent.opacity(0.25) : VergeColor.border, lineWidth: 0.5)
        }
        .scaleEffect(hovered ? 1.01 : 1)
        .animation(.easeOut(duration: 0.15), value: hovered)
        .onHover { hovered = $0 }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch target.status {
        case .testing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("测试中").font(.caption.weight(.medium))
            }
            .foregroundStyle(VergeColor.accent)
        default:
            HStack(spacing: 4) {
                Image(systemName: badgeIcon)
                    .font(.caption2)
                Text(target.status.vergeBadgeTitle)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(badgeColor.opacity(0.12)))
            .foregroundStyle(badgeColor)
        }
    }

    private func regionBadge(_ code: String) -> some View {
        HStack(spacing: 3) {
            Text(regionFlag(code))
            Text(code)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(VergeColor.surface))
        .foregroundStyle(.secondary)
    }

    private var badgeColor: Color {
        switch target.status {
        case .unlocked: VergeColor.running
        case .locked, .failed: VergeColor.danger
        case .idle: .secondary
        case .testing: VergeColor.accent
        }
    }

    private var badgeIcon: String {
        switch target.status {
        case .unlocked: "checkmark"
        case .locked: "xmark"
        case .failed: "questionmark"
        case .idle: "minus"
        case .testing: "arrow.clockwise"
        }
    }

    private func regionFlag(_ code: String) -> String {
        let base: UInt32 = 127397
        return code.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(base + scalar.value)
        }.map { String($0) }.joined()
    }
}

#Preview {
    UnlockView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
