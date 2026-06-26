import Foundation

@objc protocol HelperProtocol {
    func startTunnel(
        corePath: String,
        configPath: String,
        workDirectory: String,
        secret: String,
        reply: @escaping (Bool, String?) -> Void
    )
    func stopTunnel(reply: @escaping (Bool, String?) -> Void)
    func tunnelStatus(reply: @escaping (Bool, Int32) -> Void)
}

enum HelperConstants {
    static let machServiceName = "com.clashmac.helper"
}
