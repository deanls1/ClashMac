import SwiftUI

// MARK: - 连接链路

struct VergeChainLabel: View {
    let chain: String

    private var segments: [String] {
        chain
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 3) {
                    if let flag = NodeNameParser.countryFlag(from: segment) {
                        Text(flag).font(.caption)
                    } else if segment.uppercased() == "DIRECT" {
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(segment)
                        .font(VergeTypography.caption)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - 规则类型标签

struct VergeRuleTypeBadge: View {
    let type: String

    private var label: String {
        switch type.uppercased() {
        case "DOMAIN-SUFFIX": "DomainSuffix"
        case "DOMAIN-KEYWORD": "DomainKeyword"
        case "DOMAIN": "Domain"
        case "IP-CIDR", "IP-CIDR6": "IPCIDR"
        case "GEOSITE": "GeoSite"
        case "GEOIP": "GeoIP"
        case "MATCH": "Match"
        case "PROCESS-NAME": "Process"
        default: type
        }
    }

    var body: some View {
        Text(label)
            .font(VergeTypography.smallMedium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(VergeColor.surface))
    }
}

// MARK: - 解锁状态

struct VergeUnlockStatusBadge: View {
    let status: UnlockStatus

    var body: some View {
        switch status {
        case .testing:
            HStack(spacing: 5) {
                ProgressView().controlSize(.small)
                Text("测试中")
                    .font(VergeTypography.captionMedium)
            }
            .foregroundStyle(VergeColor.accent)
        default:
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                Text(status.vergeBadgeTitle)
                    .font(VergeTypography.captionMedium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundStyle(color)
        }
    }

    private var color: Color {
        switch status {
        case .unlocked: VergeColor.running
        case .locked, .failed: VergeColor.danger
        case .idle: .secondary
        case .testing: VergeColor.accent
        }
    }

    private var icon: String {
        switch status {
        case .unlocked: "checkmark"
        case .locked: "xmark"
        case .failed: "exclamationmark"
        case .idle: "minus"
        case .testing: "arrow.clockwise"
        }
    }
}

// MARK: - 列表表头

struct VergeTableHeader: View {
    let columns: [VergeTableColumn]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                if column.flex {
                    Text(column.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(column.title)
                        .frame(width: column.width, alignment: .leading)
                }
            }
        }
        .font(VergeTypography.captionMedium)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(VergeColor.surface.opacity(0.55))
    }
}

struct VergeTableColumn: Identifiable {
    let id = UUID()
    let title: String
    var width: CGFloat = 80
    var flex = false
}
