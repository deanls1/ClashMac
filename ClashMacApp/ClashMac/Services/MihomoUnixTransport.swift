import Foundation
import Darwin

enum MihomoUnixTransportError: LocalizedError {
    case connectFailed
    case requestFailed
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .connectFailed: "无法连接 Mihomo Unix Socket"
        case .requestFailed: "Mihomo API 请求失败"
        case .invalidResponse: "Mihomo 返回无效数据"
        case .httpStatus(let code): "Mihomo HTTP \(code)"
        }
    }
}

/// HTTP over Unix Domain Socket（Verge Rev 通过 tauri-plugin-mihomo LocalSocket 协议通信）。
enum MihomoUnixTransport {
    static func request(
        socketPath: String,
        method: String,
        path: String,
        secret: String,
        body: Data? = nil,
        query: String? = nil
    ) throws -> Data {
        let fd = try connect(to: socketPath)
        defer { close(fd) }

        let fullPath: String
        if let query, !query.isEmpty {
            fullPath = path.contains("?") ? "\(path)&\(query)" : "\(path)?\(query)"
        } else {
            fullPath = path
        }

        var headerLines = [
            "\(method.uppercased()) \(fullPath) HTTP/1.1",
            "Host: localhost",
            "Authorization: Bearer \(secret)",
            "Connection: close"
        ]
        if body != nil {
            headerLines.append("Content-Type: application/json")
            headerLines.append("Content-Length: \(body!.count)")
        }
        let header = headerLines.joined(separator: "\r\n") + "\r\n\r\n"

        try writeAll(fd, Data(header.utf8))
        if let body { try writeAll(fd, body) }

        let (status, responseBody) = try readHTTPResponse(fd: fd)
        guard (200..<300).contains(status) else {
            throw MihomoUnixTransportError.httpStatus(status)
        }
        return responseBody
    }

    // MARK: - Socket

    private static func connect(to socketPath: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw MihomoUnixTransportError.connectFailed }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw MihomoUnixTransportError.connectFailed
        }
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            pathBytes.withUnsafeBufferPointer { src in
                memcpy(ptr, src.baseAddress!, src.count)
            }
        }

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, size)
            }
        }
        guard result == 0 else {
            close(fd)
            throw MihomoUnixTransportError.connectFailed
        }
        return fd
    }

    private static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var sent = 0
            while sent < raw.count {
                let n = write(fd, raw.baseAddress!.advanced(by: sent), raw.count - sent)
                guard n > 0 else { throw MihomoUnixTransportError.requestFailed }
                sent += n
            }
        }
    }

    private static func readHTTPResponse(fd: Int32) throws -> (Int, Data) {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 8192)

        while true {
            let n = read(fd, &chunk, chunk.count)
            if n <= 0 { break }
            buffer.append(chunk, count: n)
            if buffer.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) != nil { break }
        }

        guard let headerEnd = buffer.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) else {
            throw MihomoUnixTransportError.invalidResponse
        }

        let headerData = buffer[..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw MihomoUnixTransportError.invalidResponse
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else { throw MihomoUnixTransportError.invalidResponse }
        let statusParts = statusLine.split(separator: " ")
        guard statusParts.count >= 2, let status = Int(statusParts[1]) else {
            throw MihomoUnixTransportError.invalidResponse
        }

        var contentLength: Int?
        for line in lines.dropFirst() {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                contentLength = Int(line.split(separator: ":", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespaces) ?? "")
            }
        }

        var body = buffer[headerEnd.upperBound...]
        if let contentLength {
            while body.count < contentLength {
                let n = read(fd, &chunk, chunk.count)
                if n <= 0 { break }
                body.append(contentsOf: chunk.prefix(n))
            }
            return (status, Data(body.prefix(contentLength)))
        }
        return (status, Data(body))
    }
}

/// WebSocket over Unix Domain Socket（日志 / 流量订阅）。
final class MihomoUnixWebSocket: @unchecked Sendable {
    private var fd: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.clashmac.mihomo.ws", qos: .utility)

    func connect(socketPath: String, path: String, secret: String) throws {
        disconnect()
        fd = try Self.openSocket(path: socketPath)
        let key = Data((0..<16).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
        let requestLines = [
            "GET \(path) HTTP/1.1",
            "Host: localhost",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Key: \(key)",
            "Sec-WebSocket-Version: 13",
            "Authorization: Bearer \(secret)",
            ""
        ]
        let request = requestLines.joined(separator: "\r\n") + "\r\n"
        try MihomoUnixTransportWriteAll(fd, Data(request.utf8))
        _ = try Self.readUpgradeResponse(fd: fd)
        isRunning = true
    }

    func receiveText(onMessage: @escaping @Sendable (String) -> Void, onClose: @escaping @Sendable () -> Void) {
        queue.async { [weak self] in
            guard let self, self.isRunning, self.fd >= 0 else { return }
            while self.isRunning {
                do {
                    if let text = try Self.readTextFrame(fd: self.fd) {
                        onMessage(text)
                    }
                } catch {
                    self.isRunning = false
                    onClose()
                    break
                }
            }
        }
    }

    func disconnect() {
        isRunning = false
        if fd >= 0 {
            close(fd)
            fd = -1
        }
    }

    private static func openSocket(path: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw MihomoUnixTransportError.connectFailed }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw MihomoUnixTransportError.connectFailed
        }
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            pathBytes.withUnsafeBufferPointer { src in
                memcpy(ptr, src.baseAddress!, src.count)
            }
        }
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            close(fd)
            throw MihomoUnixTransportError.connectFailed
        }
        return fd
    }

    private static func readUpgradeResponse(fd: Int32) throws {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while buffer.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) == nil {
            let n = read(fd, &chunk, chunk.count)
            guard n > 0 else { throw MihomoUnixTransportError.invalidResponse }
            buffer.append(chunk, count: n)
        }
        guard let text = String(data: buffer, encoding: .utf8), text.contains(" 101 ") else {
            throw MihomoUnixTransportError.invalidResponse
        }
    }

    private static func readTextFrame(fd: Int32) throws -> String? {
        var header = [UInt8](repeating: 0, count: 2)
        guard readExact(fd, &header, 2) else { return nil }

        let opcode = header[0] & 0x0F
        if opcode == 0x8 { throw MihomoUnixTransportError.invalidResponse }

        var length = Int(header[1] & 0x7F)
        if length == 126 {
            var ext = [UInt8](repeating: 0, count: 2)
            guard readExact(fd, &ext, 2) else { return nil }
            length = Int(ext[0]) << 8 | Int(ext[1])
        } else if length == 127 {
            var ext = [UInt8](repeating: 0, count: 8)
            guard readExact(fd, &ext, 8) else { return nil }
            length = ext.suffix(4).reduce(0) { ($0 << 8) | Int($1) }
        }

        var payload = [UInt8](repeating: 0, count: length)
        guard readExact(fd, &payload, length) else { return nil }

        if opcode == 0x1 || opcode == 0x0 {
            return String(bytes: payload, encoding: .utf8)
        }
        return nil
    }

    private static func readExact(_ fd: Int32, _ buffer: inout [UInt8], _ count: Int) -> Bool {
        var received = 0
        while received < count {
            let n = read(fd, &buffer[received], count - received)
            if n <= 0 { return false }
            received += n
        }
        return true
    }
}

private func MihomoUnixTransportWriteAll(_ fd: Int32, _ data: Data) throws {
    try data.withUnsafeBytes { raw in
        var sent = 0
        while sent < raw.count {
            let n = write(fd, raw.baseAddress!.advanced(by: sent), raw.count - sent)
            guard n > 0 else { throw MihomoUnixTransportError.requestFailed }
            sent += n
        }
    }
}
