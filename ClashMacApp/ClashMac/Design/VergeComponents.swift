import SwiftUI

// MARK: - 两级卡片体系
//
// 页面级卡片继续使用 `vergeCardBackground`（带阴影，r12）。
// 以下两个用于「卡片内部的嵌套面板 / 列表卡 / 输入框」，一律无阴影、描边为 hairline，
// 通过圆角阶梯（r10 > r8）表达层级，避免各页各写一套背景导致视觉不一致。

/// 嵌套/次级面板：r10、hairline 描边、无阴影。
var vergeInnerCardBackground: some View {
    RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius, style: .continuous)
        .fill(VergeColor.cardFill)
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius, style: .continuous)
                .strokeBorder(VergeColor.border, lineWidth: VergeStroke.hairline)
        }
}

/// 列表卡 / 内容卡：r8、cardFill 填充、hairline 描边、无阴影。
var vergeFlatCardBackground: some View {
    RoundedRectangle(cornerRadius: VergeLayout.fieldRadius, style: .continuous)
        .fill(VergeColor.cardFill)
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.fieldRadius, style: .continuous)
                .strokeBorder(VergeColor.border, lineWidth: VergeStroke.hairline)
        }
}

/// 输入框 / 紧凑字段：r8、surface 填充（比卡片更「凹陷」）、hairline 描边。
var vergeFieldBackground: some View {
    RoundedRectangle(cornerRadius: VergeLayout.fieldRadius, style: .continuous)
        .fill(VergeColor.surface)
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.fieldRadius, style: .continuous)
                .strokeBorder(VergeColor.border, lineWidth: VergeStroke.hairline)
        }
}

// MARK: - 统一分段控件
//
// 取代此前散落的 5 套实现（VergeModePills / VergeSegmentTabs / 配置模式切换 /
// 日志来源 picker / 首页网络 chips）。统一为「圆角矩形」外形，选中态用 accent 填充 + onAccent 文字。

struct VergeSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let items: [(value: Value, label: String)]
    /// 是否等宽平分（如「活跃/已关闭」这类填满整行的场景）；默认按内容宽度。
    var equalWidths: Bool = false

    init(selection: Binding<Value>, items: [(value: Value, label: String)], equalWidths: Bool = false) {
        self._selection = selection
        self.items = items
        self.equalWidths = equalWidths
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items, id: \.value) { item in
                segment(for: item)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.segmentOuterRadius, style: .continuous)
                .fill(VergeColor.surface)
        }
    }

    @ViewBuilder
    private func segment(for item: (value: Value, label: String)) -> some View {
        let selected = selection == item.value
        Button {
            selection = item.value
        } label: {
            Text(item.label)
                .font(VergeTypography.smallMedium)
                .foregroundStyle(selected ? VergeColor.onAccent : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .frame(maxWidth: equalWidths ? .infinity : nil)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: VergeLayout.segmentInnerRadius, style: .continuous)
                            .fill(VergeColor.accent)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
