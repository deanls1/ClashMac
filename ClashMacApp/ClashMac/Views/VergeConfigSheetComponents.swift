import SwiftUI

// MARK: - Sheet chrome

struct VergeConfigSheetHeader: View {
    let title: String
    let symbol: String
    let onReset: () -> Void
    var trailing: AnyView?

    init(
        title: String,
        symbol: String,
        onReset: @escaping () -> Void,
        trailing: (any View)? = nil
    ) {
        self.title = title
        self.symbol = symbol
        self.onReset = onReset
        self.trailing = trailing.map { AnyView($0) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(VergeColor.accent)
                    .frame(width: 22, height: 22)
                Text(title)
                    .font(VergeTypography.sectionTitle)
            }
            Spacer(minLength: 8)
            Button("重置默认", action: onReset)
                .buttonStyle(.borderless)
                .foregroundStyle(VergeColor.upload)
                .font(VergeTypography.captionMedium)
            if let trailing {
                trailing
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
}

struct VergeConfigSheetFooter: View {
    let onCancel: () -> Void
    let onSave: () -> Void
    var saveDisabled: Bool = false

    var body: some View {
        HStack {
            Spacer()
            Button("取消", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button("保存", action: onSave)
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(saveDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(VergeColor.cardFill.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle().fill(VergeColor.border).frame(height: 0.5)
        }
    }
}

struct VergeConfigWarningBanner: View {
    let message: String
    var tone: Color = VergeColor.upload

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(tone)
            Text(message)
                .font(VergeTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tone.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(tone.opacity(0.22), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct VergeConfigEditorModeToggle: View {
    @Binding var isVisual: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) { isVisual = true }
            } label: {
                modeLabel("可视化", active: isVisual)
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.easeInOut(duration: 0.16)) { isVisual = false }
            } label: {
                modeLabel("高级", active: !isVisual)
            }
            .buttonStyle(.plain)
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(VergeColor.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 0.5)
                }
        }
    }

    private func modeLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(active ? VergeTypography.captionMedium : VergeTypography.caption)
            .foregroundStyle(active ? Color.white : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(VergeColor.accent)
                }
            }
    }
}

// MARK: - List rows (Verge ListItem style)

struct VergeConfigSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(VergeTypography.bodyMedium)
            .foregroundStyle(.primary)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }
}

struct VergeConfigToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            labelColumn
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(disabled)
        }
        .frame(minHeight: VergeLayout.settingsRowMinHeight)
        .opacity(disabled ? 0.45 : 1)
    }

    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(VergeTypography.body)
            if let subtitle {
                Text(subtitle)
                    .font(VergeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: VergeLayout.settingsLabelWidth, alignment: .leading)
    }
}

struct VergeConfigFieldRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            labelColumn
            VergeImportField(placeholder: placeholder, text: $text)
                .frame(maxWidth: .infinity)
        }
        .frame(minHeight: VergeLayout.settingsRowMinHeight)
    }

    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(VergeTypography.body)
            if let subtitle {
                Text(subtitle)
                    .font(VergeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: VergeLayout.settingsLabelWidth, alignment: .leading)
    }
}

struct VergeConfigSegmentRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var selection: String
    let options: [(value: String, label: String)]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            labelColumn
            HStack(spacing: 0) {
                ForEach(options, id: \.value) { option in
                    Button {
                        selection = option.value
                    } label: {
                        Text(option.label)
                            .font(selection == option.value ? VergeTypography.captionMedium : VergeTypography.caption)
                            .foregroundStyle(selection == option.value ? Color.white : Color.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                if selection == option.value {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(VergeColor.accent)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(VergeColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(VergeColor.border, lineWidth: 0.5)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: VergeLayout.settingsRowMinHeight)
    }

    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(VergeTypography.body)
            if let subtitle {
                Text(subtitle)
                    .font(VergeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: VergeLayout.settingsLabelWidth, alignment: .leading)
    }
}

struct VergeConfigStepperRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var value: Int
    let range: ClosedRange<Int>
    var suffix: String = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(VergeTypography.body)
                if let subtitle {
                    Text(subtitle).font(VergeTypography.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: VergeLayout.settingsLabelWidth, alignment: .leading)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                Stepper(value: $value, in: range, step: 1) {
                    Text("\(value)\(suffix)")
                        .font(VergeTypography.mono)
                        .frame(width: 72, alignment: .trailing)
                }
            }
        }
        .frame(minHeight: VergeLayout.settingsRowMinHeight)
    }
}

struct VergeConfigTextAreaRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var text: String
    var minHeight: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VergeTypography.bodyMedium)
                if let subtitle {
                    Text(subtitle)
                        .font(VergeTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            TextEditor(text: $text)
                .font(VergeTypography.mono)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: minHeight)
                .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(VergeColor.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(VergeColor.border, lineWidth: 0.5)
            }
    }
}

struct VergeConfigTagListEditor: View {
    @Binding var items: [String]
    var placeholder: String
    var hint: String? = nil
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !items.isEmpty {
                VergeConfigFlowLayout(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 6) {
                            Text(item)
                                .font(VergeTypography.caption)
                            Button {
                                items.removeAll { $0 == item }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            Capsule(style: .continuous)
                                .fill(VergeColor.surface)
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(VergeColor.border, lineWidth: 0.5)
                                }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                VergeImportField(placeholder: placeholder, text: $draft)
                Button("添加") { appendDraft() }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let hint {
                Text(hint)
                    .font(VergeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func appendDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !items.contains(trimmed) else { return }
        items.append(trimmed)
        draft = ""
    }
}

struct VergeConfigListDivider: View {
    var body: some View {
        Rectangle()
            .fill(VergeColor.border)
            .frame(height: 0.5)
            .padding(.vertical, 2)
    }
}

/// 简单流式标签布局
struct VergeConfigFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
