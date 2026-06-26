import Foundation

enum StartupErrorFormatter {
    static func message(for error: Error, mixedPort: Int, coreStillRunning: Bool) -> String {
        if let conflict = PortAvailabilityChecker.conflictMessage(for: mixedPort) {
            return conflict
        }
        if error is MihomoAPIError {
            if coreStillRunning {
                return "Mihomo 启动超时，请稍后重试"
            }
            return "Mihomo 进程已退出，请检查配置是否正确或 GeoData 是否完整"
        }
        if let validation = error as? CoreConfigValidator.ValidationError {
            return validation.localizedDescription
        }
        if let tunnel = error as? TunnelHelperError {
            return tunnel.localizedDescription
        }
        if let core = error as? CoreProcessError {
            return core.localizedDescription
        }
        return error.localizedDescription
    }
}
