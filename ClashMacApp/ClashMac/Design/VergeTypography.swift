import SwiftUI

/// 中文界面优先使用系统默认字体（PingFang SC），避免 rounded 设计在中文下显得廉价。
enum VergeTypography {
    static let pageTitle = Font.system(size: 26, weight: .bold)
    static let sectionTitle = Font.system(size: 15, weight: .semibold)
    static let cardTitle = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
    static let captionMedium = Font.system(size: 13, weight: .medium)
    static let small = Font.system(size: 12, weight: .regular)
    static let smallMedium = Font.system(size: 12, weight: .medium)
    static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let monoLarge = Font.system(size: 14, weight: .semibold, design: .monospaced)
    static let nav = Font.system(size: 15, weight: .regular)
    static let navSelected = Font.system(size: 15, weight: .semibold)
    static let statValue = Font.system(size: 15, weight: .semibold, design: .monospaced)
}

extension View {
    func vergeBodyText() -> some View {
        font(VergeTypography.body)
    }
}
