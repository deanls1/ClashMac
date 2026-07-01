import AppKit
import SwiftUI

/// 对齐 Clash Verge Rev 的 VirtualList：仅渲染可见行，支持 3 万+ 规则流畅滚动。
struct RulesVirtualTableView: NSViewRepresentable {
    let rules: [RuleItem]
    let indices: [Int]
    let dataRevision: Int
    let onToggle: (RuleItem) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onToggle: onToggle)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let tableView = NSTableView()
        tableView.style = .plain
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.gridStyleMask = []
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.selectionHighlightStyle = .regular
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rule"))
        column.resizingMask = [.autoresizingMask]
        tableView.addTableColumn(column)

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let changed = coordinator.rules.count != rules.count
            || coordinator.indices != indices
            || coordinator.dataRevision != dataRevision
        coordinator.rules = rules
        coordinator.indices = indices
        coordinator.dataRevision = dataRevision
        coordinator.onToggle = onToggle
        if changed {
            coordinator.tableView?.reloadData()
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var rules: [RuleItem] = []
        var indices: [Int] = []
        var dataRevision = 0
        var onToggle: (RuleItem) -> Void
        weak var tableView: NSTableView?

        init(onToggle: @escaping (RuleItem) -> Void) {
            self.onToggle = onToggle
        }

        private var rowCount: Int {
            indices.isEmpty ? rules.count : indices.count
        }

        private func rule(at row: Int) -> RuleItem? {
            guard row >= 0 else { return nil }
            if indices.isEmpty {
                guard row < rules.count else { return nil }
                return rules[row]
            }
            guard row < indices.count else { return nil }
            let ruleIndex = indices[row]
            guard rules.indices.contains(ruleIndex) else { return nil }
            return rules[ruleIndex]
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rowCount
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let rule = rule(at: row) else { return nil }
            let identifier = NSUserInterfaceItemIdentifier("RulesCell")

            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? RuleTableCell ?? {
                let view = RuleTableCell()
                view.identifier = identifier
                return view
            }()

            cell.configure(rule: rule)
            return cell
        }

        @objc func handleDoubleClick(_ sender: Any?) {
            guard let tableView = sender as? NSTableView else { return }
            let row = tableView.clickedRow
            guard let rule = rule(at: row) else { return }
            onToggle(rule)
        }
    }
}

private final class RuleTableCell: NSTableCellView {
    private let indexField = NSTextField(labelWithString: "")
    private let payloadField = NSTextField(labelWithString: "")
    private let typeField = NSTextField(labelWithString: "")
    private let proxyField = NSTextField(labelWithString: "")
    private let separator = NSBox()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        [indexField, payloadField, typeField, proxyField, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        indexField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        indexField.textColor = .tertiaryLabelColor
        indexField.alignment = .right

        payloadField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        payloadField.lineBreakMode = .byTruncatingTail

        typeField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        typeField.textColor = .secondaryLabelColor

        proxyField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        proxyField.alignment = .right

        separator.boxType = .separator
        separator.alphaValue = 0.28

        NSLayoutConstraint.activate([
            indexField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            indexField.centerYAnchor.constraint(equalTo: centerYAnchor),
            indexField.widthAnchor.constraint(equalToConstant: 54),

            typeField.leadingAnchor.constraint(equalTo: indexField.trailingAnchor, constant: 12),
            typeField.centerYAnchor.constraint(equalTo: centerYAnchor),
            typeField.widthAnchor.constraint(equalToConstant: 96),

            payloadField.leadingAnchor.constraint(equalTo: typeField.trailingAnchor),
            payloadField.trailingAnchor.constraint(equalTo: proxyField.leadingAnchor, constant: -18),
            payloadField.centerYAnchor.constraint(equalTo: centerYAnchor),

            proxyField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            proxyField.centerYAnchor.constraint(equalTo: centerYAnchor),
            proxyField.widthAnchor.constraint(equalToConstant: 130),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 78),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    func configure(rule: RuleItem) {
        indexField.stringValue = "\(rule.index + 1)"
        payloadField.stringValue = rule.payload.isEmpty ? "-" : rule.payload
        payloadField.textColor = rule.isEnabled ? .labelColor : .secondaryLabelColor
        typeField.stringValue = rule.type
        proxyField.stringValue = rule.proxy
        proxyField.textColor = RulesTablePolicyStyle.nsColor(for: rule.proxy)
        alphaValue = rule.isEnabled ? 1 : 0.45
    }
}

private enum RulesTablePolicyStyle {
    static func nsColor(for policy: String) -> NSColor {
        NSColor(VergePolicyStyle.color(for: policy))
    }
}
