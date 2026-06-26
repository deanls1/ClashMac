import Foundation

enum CoreMemoryMonitor {
    static func formatted(forPID pid: Int32?) -> String {
        guard let pid, pid > 0 else { return "—" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "rss=", "-p", "\(pid)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "—" }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return "—" }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let kb = Int(text), kb > 0 else { return "—" }
        if kb >= 1024 * 1024 {
            return String(format: "%.1f GB", Double(kb) / 1024 / 1024)
        }
        if kb >= 1024 {
            return String(format: "%.1f MB", Double(kb) / 1024)
        }
        return "\(kb) KB"
    }
}
