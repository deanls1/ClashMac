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

    /// 构建 XPC 接口并显式限制各参数的可解码类型，避免 NSSecureCoding 回退到 NSObject。
    static func makeInterface() -> NSXPCInterface {
        let interface = NSXPCInterface(with: HelperProtocol.self)

        let stringClasses = NSSet(array: [NSString.self]) as! Set<AnyHashable>
        let optionalStringClasses = NSSet(array: [NSString.self, NSNull.self]) as! Set<AnyHashable>
        let numberClasses = NSSet(array: [NSNumber.self]) as! Set<AnyHashable>

        let startSel = #selector(HelperProtocol.startTunnel(corePath:configPath:workDirectory:secret:reply:))
        for index in 0..<4 {
            interface.setClasses(stringClasses, for: startSel, argumentIndex: index, ofReply: false)
        }
        interface.setClasses(numberClasses, for: startSel, argumentIndex: 0, ofReply: true)
        interface.setClasses(optionalStringClasses, for: startSel, argumentIndex: 1, ofReply: true)

        let stopSel = #selector(HelperProtocol.stopTunnel(reply:))
        interface.setClasses(numberClasses, for: stopSel, argumentIndex: 0, ofReply: true)
        interface.setClasses(optionalStringClasses, for: stopSel, argumentIndex: 1, ofReply: true)

        let statusSel = #selector(HelperProtocol.tunnelStatus(reply:))
        interface.setClasses(numberClasses, for: statusSel, argumentIndex: 0, ofReply: true)
        interface.setClasses(numberClasses, for: statusSel, argumentIndex: 1, ofReply: true)

        return interface
    }
}
