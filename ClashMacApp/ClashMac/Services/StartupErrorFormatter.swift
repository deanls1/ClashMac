import Foundation

enum StartupErrorFormatter {
    static func message(for error: Error, mixedPort: Int, coreStillRunning: Bool) -> String {
        if let conflict = PortAvailabilityChecker.conflictMessage(for: mixedPort) {
            return conflict
        }
        if let validation = error as? CoreConfigValidator.ValidationError,
           case .failed(let raw) = validation,
           let friendly = friendlyConfigMessage(from: raw) {
            return friendly
        }
        if let validation = error as? CoreConfigValidator.ValidationError {
            return validation.localizedDescription
        }
        if error is MihomoAPIError {
            if coreStillRunning {
                return "Mihomo 启动超时，请稍后重试"
            }
            if case MihomoAPIError.httpStatus(let code) = error, code == 400 || code == 401 || code == 403 {
                return "无法连接 Mihomo 控制接口（HTTP \(code)）。若本机同时运行 Clash Verge Rev，请确认 Clash Mac 混合端口为 \(ClashMacPorts.defaultMixedPort) 且两者不要同时开启 TUN。"
            }
            return "Mihomo 进程已退出，请检查配置是否正确或 GeoData 是否完整"
        }
        if let tunnel = error as? TunnelHelperError {
            return tunnel.localizedDescription
        }
        if let core = error as? CoreProcessError {
            return core.localizedDescription
        }
        if isOperationNotPermitted(error) {
            return tunPermissionHint
        }
        if isOperationNotPermitted(error.localizedDescription) {
            return tunPermissionHint
        }
        if let friendly = friendlyConfigMessage(from: error.localizedDescription) {
            return friendly
        }
        return error.localizedDescription
    }

    private static let tunPermissionHint = """
    TUN 模式需要特权 Helper。请确认：
    1. 应用已安装到「应用程序」文件夹
    2. 系统设置 → 通用 → 登录项 中已批准 ClashMac Helper
    3. 或在设置中关闭 TUN，改用系统代理模式
    """

    private static func isOperationNotPermitted(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSPOSIXErrorDomain && ns.code == Int(POSIXError.Code.EPERM.rawValue) {
            return true
        }
        return isOperationNotPermitted(ns.localizedDescription)
    }

    private static func isOperationNotPermitted(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains("operation not permitted")
            || text.contains("操作不被允许")
    }

    private static func friendlyConfigMessage(from raw: String) -> String? {
        let lineHint = yamlLineHint(from: raw)
        if raw.contains("geodata-mode") && raw.contains("cannot unmarshal") {
            return "配置字段 geodata-mode 类型错误（应为 true/false）。请重新启动代理以重新生成配置。"
        }
        if raw.contains("did not find expected") || raw.contains("yaml:") {
            return "配置文件 YAML 语法错误\(lineHint)。请重新启动代理以重新生成配置。"
        }
        if raw.contains("cannot unmarshal") {
            return "配置文件字段类型错误\(lineHint)。请重新启动代理以重新生成配置。"
        }
        return nil
    }

    private static func yamlLineHint(from raw: String) -> String {
        guard let range = raw.range(of: "line ") else { return "" }
        var index = range.upperBound
        var digits = ""
        while index < raw.endIndex, raw[index].isNumber {
            digits.append(raw[index])
            index = raw.index(after: index)
        }
        return digits.isEmpty ? "" : "（约第 \(digits) 行）"
    }
}
