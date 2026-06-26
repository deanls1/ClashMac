import SwiftUI

struct UnlockView: View {
    @Bindable var store: AppStore
    @State private var showAddForm = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

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
                    Text("测试全部")
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
                .disabled(!store.coreState.isRunning || store.unlockTargets.contains { $0.status == .testing })
            }

            ScrollView {
                VStack(spacing: 14) {
                    if !store.coreState.isRunning {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("请先启动代理后再进行解锁测试")
                                .font(VergeTypography.body)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("启动代理") { Task { await store.start() } }
                                .controlSize(.small)
                                .buttonStyle(.borderedProminent)
                                .tint(VergeColor.accent)
                        }
                        .padding(14)
                        .background(vergeCardBackground)
                    }

                    if showAddForm { addForm }

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.unlockTargets) { target in
                            VergeUnlockCard(
                                target: target,
                                canDelete: store.isCustomUnlockTarget(target),
                                onTest: { Task { await store.runSingleUnlockTest(target) } },
                                onDelete: { store.removeUnlockTarget(target) }
                            )
                        }
                    }
                }
                .padding(VergeLayout.contentPadding)
                .frame(maxWidth: 900)
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
    let canDelete: Bool
    let onTest: () -> Void
    let onDelete: () -> Void
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VergeColor.accentSoft.opacity(0.6))
                        .frame(width: 36, height: 36)
                    Image(systemName: target.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VergeColor.accent)
                }

                Text(target.name)
                    .font(VergeTypography.bodyMedium)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VergeColor.danger)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(VergeColor.danger.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onTest) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VergeColor.accent)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(VergeColor.accentSoft))
                }
                .buttonStyle(.plain)
                .disabled(target.status == .testing)
            }

            Spacer(minLength: 14)

            HStack(spacing: 8) {
                VergeUnlockStatusBadge(status: target.status)
                if let code = target.regionCode {
                    regionBadge(code)
                }
                Spacer()
            }

            if let tested = target.lastTestedAt {
                Text(tested.formatted(date: .numeric, time: .standard))
                    .font(VergeTypography.small)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .frame(minHeight: 118, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .fill(VergeColor.cardFill)
                .shadow(color: VergeColor.shadow.opacity(hovered ? 0.14 : 0.06), radius: hovered ? 10 : 5, y: hovered ? 3 : 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .strokeBorder(
                    statusBorderColor.opacity(hovered ? 0.35 : 0.2),
                    lineWidth: 0.5
                )
        }
        .onHover { hovered = $0 }
    }

    private var statusBorderColor: Color {
        switch target.status {
        case .unlocked: VergeColor.running
        case .locked, .failed: VergeColor.danger
        default: VergeColor.border
        }
    }

    private func regionBadge(_ code: String) -> some View {
        HStack(spacing: 4) {
            Text(regionFlag(code))
            Text(code.uppercased())
                .font(VergeTypography.captionMedium)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(VergeColor.surface))
        .foregroundStyle(.secondary)
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
