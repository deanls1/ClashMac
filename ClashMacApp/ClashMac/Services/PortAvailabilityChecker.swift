import Foundation

enum PortAvailabilityChecker {
    /// 若端口已被其他进程监听，返回简短描述（进程名或 PID）。
    static func conflictMessage(for port: Int, excludingOwnPID: Int32? = nil) -> String? {
        guard port > 0, port <= 65535 else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = output.split(separator: "\n").dropFirst()
        guard !lines.isEmpty else { return nil }

        for line in lines {
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 2 else { continue }
            let command = parts[0]
            if let pid = Int32(parts[1]), pid == excludingOwnPID { continue }
            if command.lowercased().contains("mihomo") { continue }
            let hint = friendlyProcessName(command)
            return conflictMessage(port: port, process: hint)
        }
        return nil
    }

    private static func friendlyProcessName(_ command: String) -> String {
        switch command.lowercased() {
        case "verge-mihomo", "clash-verge", "clash verge":
            return "Clash Verge Rev"
        case "mihomo", "clash-meta", "clash":
            return command
        default:
            return command
        }
    }

    private static func conflictMessage(port: Int, process: String) -> String {
        if port == ClashMacPorts.vergeRevMixedPort || port == ClashMacPorts.vergeRevControllerPort {
            return "端口 \(port) 已被占用（\(process)）。Clash Verge Rev 默认使用 7897/9097，请在 Clash Mac 设置中改用 \(ClashMacPorts.defaultMixedPort)/\(ClashMacPorts.defaultControllerPort)，或关闭 Verge。"
        }
        if port == ClashMacPorts.legacyMixedPort || port == ClashMacPorts.legacyControllerPort {
            return "端口 \(port) 已被占用（\(process)）。请关闭其他 Clash 客户端，或在 Clash Mac 设置中修改混合端口（默认 \(ClashMacPorts.defaultMixedPort)）。"
        }
        return "端口 \(port) 已被占用（\(process)），请关闭其他代理客户端或在设置中修改端口"
    }
}
