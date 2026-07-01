import Foundation

/// Clash Mac 默认端口，刻意与 Clash Verge Rev（7897 / 9097）及经典 Clash（7890 / 9090）错开。
enum ClashMacPorts {
    static let defaultMixedPort = 7895
    static let defaultControllerPort = 9095
    static let defaultTUNDevice = "utun2048"

    /// Clash Verge Rev 常见默认，用于冲突提示。
    static let vergeRevMixedPort = 7897
    static let vergeRevControllerPort = 9097

    static let legacyMixedPort = 7890
    static let legacyControllerPort = 9090
}
