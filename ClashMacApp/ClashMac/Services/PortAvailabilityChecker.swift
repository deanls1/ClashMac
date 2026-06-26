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
            let hint = command == "verge-mihomo" ? "Clash Verge" : command
            return "端口 \(port) 已被占用（\(hint)），请关闭其他代理客户端或修改混合端口"
        }
        return nil
    }
}
