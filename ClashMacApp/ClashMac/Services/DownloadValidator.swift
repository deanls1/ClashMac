import Foundation
import CryptoKit

/// 下载完整性校验（参考 Verge prebuild 的 magic bytes 检查）。
enum DownloadValidator {
    enum ValidationError: LocalizedError {
        case invalidGzip
        case emptyPayload
        case invalidMachO
        case checksumMismatch

        var errorDescription: String? {
            switch self {
            case .invalidGzip: "下载内容不是有效的 gzip 文件"
            case .emptyPayload: "下载内容为空"
            case .invalidMachO: "解压后不是有效的 macOS 可执行文件"
            case .checksumMismatch: "文件校验和不匹配"
            }
        }
    }

    static func validateGzip(_ data: Data) throws {
        guard data.count >= 2 else { throw ValidationError.invalidGzip }
        guard data[0] == 0x1f, data[1] == 0x8b else { throw ValidationError.invalidGzip }
    }

    static func validateMachOExecutable(_ data: Data) throws {
        guard data.count >= 4 else { throw ValidationError.invalidMachO }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        let ok: Set<UInt32> = [
            0xFEED_FACF, // MH_MAGIC_64
            0xCFFA_EDFE, // MH_CIGAM_64
            0xFEED_FACE, // MH_MAGIC
            0xCEFA_EDFE  // MH_CIGAM
        ]
        guard ok.contains(magic) else { throw ValidationError.invalidMachO }
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func validateSHA256(_ data: Data, expected: String) throws {
        let actual = sha256Hex(of: data)
        guard actual.caseInsensitiveCompare(expected.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame else {
            throw ValidationError.checksumMismatch
        }
    }
}
