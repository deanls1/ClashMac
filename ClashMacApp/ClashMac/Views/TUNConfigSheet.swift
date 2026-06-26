import SwiftUI

struct TUNConfigSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var config = TUNConfig.vergeDefault
    @State private var newExcludeCIDR = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("虚拟网卡模式")
                    .font(.title2.weight(.bold))
                Spacer()
                Button("重置为默认值") {
                    config = .vergeDefault
                }
                .foregroundStyle(VergeColor.upload)
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stackPicker
                    tunField("虚拟网卡名称", text: $config.device)
                    tunToggle("自动设置全局路由", $config.autoRoute)
                    tunToggle("严格路由", $config.strictRoute)
                    tunToggle("自动选择流量出口接口", $config.autoDetectInterface)
                    tunField("DNS 劫持", text: bindingList(\.dnsHijack))
                    mtuField
                    excludeSection
                }
                .padding()
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    store.saveTUNConfig(config)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
            }
            .padding()
        }
        .frame(width: 520, height: 560)
        .onAppear { config = store.tunConfig }
    }

    private var stackPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TUN 模式堆栈").font(.subheadline.weight(.semibold))
            HStack(spacing: 0) {
                ForEach(["system", "gvisor", "mixed"], id: \.self) { value in
                    let label = value == "system" ? "System" : value == "gvisor" ? "GVisor" : "Mixed"
                    Button {
                        config.stack = value
                    } label: {
                        Text(label)
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(config.stack == value ? VergeColor.accent : Color.clear)
                            .foregroundStyle(config.stack == value ? .white : VergeColor.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(VergeColor.accent, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var mtuField: some View {
        HStack {
            Text("最大传输单元").frame(width: 140, alignment: .leading)
            Stepper(value: $config.mtu, in: 576...9000, step: 1) {
                Text("\(config.mtu)")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }

    private var excludeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("排除自定义网段").font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 6) {
                ForEach(config.routeExcludeAddress, id: \.self) { cidr in
                    HStack(spacing: 4) {
                        Text(cidr).font(.caption)
                        Button {
                            config.routeExcludeAddress.removeAll { $0 == cidr }
                        } label: {
                            Image(systemName: "xmark").font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(VergeColor.surface))
                }
            }
            HStack {
                TextField("192.168.0.0/16", text: $newExcludeCIDR)
                    .textFieldStyle(.roundedBorder)
                Button("新建") {
                    let trimmed = newExcludeCIDR.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !config.routeExcludeAddress.contains(trimmed) else { return }
                    config.routeExcludeAddress.append(trimmed)
                    newExcludeCIDR = ""
                }
                .disabled(newExcludeCIDR.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("仅支持 IPv4/IPv6 CIDR，例如 192.168.0.0/16 或 fd00::/8")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func bindingList(_ keyPath: WritableKeyPath<TUNConfig, [String]>) -> Binding<String> {
        Binding(
            get: { config[keyPath: keyPath].joined(separator: ", ") },
            set: { config[keyPath: keyPath] = TUNConfig.parseList($0) }
        )
    }

    private func tunField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).frame(width: 140, alignment: .leading)
            TextField(title, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func tunToggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: binding).labelsHidden()
        }
    }
}

extension TUNConfig {
    static func parseList(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

/// 简单流式标签布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
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
