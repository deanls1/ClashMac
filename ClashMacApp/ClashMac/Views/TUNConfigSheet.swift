import SwiftUI

struct TUNConfigSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var config = TUNConfig.vergeDefault

    private let stackOptions: [(value: String, label: String)] = [
        ("mixed", "Mixed"),
        ("gvisor", "GVisor"),
        ("system", "System"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VergeConfigSheetHeader(
                title: "TUN 模式",
                symbol: "point.3.connected.trianglepath.dotted",
                onReset: { config = .vergeDefault }
            )

            VergeConfigWarningBanner(
                message: "macOS 推荐使用 Mixed 堆栈并开启严格路由，可避免 DNS 环路。若不清楚这些选项，请保持默认。"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    generalSection
                    deviceSection
                    routingSection
                    excludeSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            VergeConfigSheetFooter(
                onCancel: { dismiss() },
                onSave: {
                    store.saveTUNConfig(config)
                    dismiss()
                }
            )
        }
        .frame(width: 560, height: 640)
        .background(VergeColor.canvas)
        .onAppear { config = store.tunConfig }
    }

    // MARK: - Sections

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VergeConfigSectionTitle(title: "常规")
            VergeConfigSegmentRow(
                title: "堆栈模式",
                subtitle: "Mixed 在 macOS 上更稳定",
                selection: $config.stack,
                options: stackOptions
            )
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VergeConfigSectionTitle(title: "设备")
            VergeConfigFieldRow(
                title: "网卡名称",
                subtitle: "macOS 默认 \(ClashMacPorts.defaultTUNDevice)",
                text: $config.device,
                placeholder: ClashMacPorts.defaultTUNDevice
            )
            VergeConfigListDivider()
            VergeConfigStepperRow(
                title: "MTU",
                subtitle: "最大传输单元",
                value: $config.mtu,
                range: 576...9000,
                suffix: " B"
            )
            VergeConfigListDivider()
            VStack(alignment: .leading, spacing: 8) {
                Text("DNS 劫持")
                    .font(VergeTypography.body)
                Text("TUN 模式下拦截的 DNS 请求地址")
                    .font(VergeTypography.caption)
                    .foregroundStyle(.secondary)
                VergeConfigTagListEditor(
                    items: $config.dnsHijack,
                    placeholder: "any:53",
                    hint: "常见值：any:53、tcp://any:53"
                )
            }
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var routingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VergeConfigSectionTitle(title: "路由")
            VergeConfigToggleRow(
                title: "自动设置全局路由",
                subtitle: "将系统默认路由指向 TUN 设备",
                isOn: $config.autoRoute
            )
            VergeConfigListDivider()
            VergeConfigToggleRow(
                title: "严格路由",
                subtitle: "macOS 建议开启，防止 DNS 泄漏与环路",
                isOn: $config.strictRoute
            )
            VergeConfigListDivider()
            VergeConfigToggleRow(
                title: "自动检测出口网卡",
                subtitle: "自动选择物理网卡作为上游",
                isOn: $config.autoDetectInterface
            )
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var excludeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VergeConfigSectionTitle(title: "排除网段")
            Text("以下 CIDR 不经过 TUN，常用于局域网地址")
                .font(VergeTypography.caption)
                .foregroundStyle(.secondary)
            VergeConfigTagListEditor(
                items: $config.routeExcludeAddress,
                placeholder: "192.168.0.0/16",
                hint: "支持 IPv4 / IPv6 CIDR"
            )
        }
        .padding(14)
        .background(sectionBackground)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
            .fill(VergeColor.cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                    .strokeBorder(VergeColor.border, lineWidth: 0.5)
            }
    }
}

extension TUNConfig {
    static func parseList(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
