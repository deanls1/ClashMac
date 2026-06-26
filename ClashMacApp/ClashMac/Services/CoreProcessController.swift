import Foundation

enum CoreProcessError: LocalizedError {
    case coreNotFound
    case alreadyRunning
    case notRunning
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .coreNotFound: "未找到 Mihomo 内核，请将二进制放入 Resources/Core/ 或通过 Homebrew 安装"
        case .alreadyRunning: "Mihomo 已在运行"
        case .notRunning: "Mihomo 未运行"
        case .launchFailed(let msg): msg
        }
    }
}

final class CoreProcessController: @unchecked Sendable {
    static let shared = CoreProcessController()

    private var process: Process?
    private let lock = NSLock()

    var pid: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning == true ? process?.processIdentifier : nil
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning == true
    }

    func start(coreURL: URL, configURL: URL, workDirectory: URL, runtime: RuntimeConfig) throws {
        lock.lock()
        defer { lock.unlock() }

        if process?.isRunning == true {
            throw CoreProcessError.alreadyRunning
        }

        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        WorkDirectorySanitizer.prepareForUserCore(in: workDirectory)

        let proc = Process()
        proc.executableURL = coreURL
        var args = [
            "-f", configURL.path,
            "-d", workDirectory.path,
            "-ext-ctl-unix", runtime.controllerUnixPath,
            "-secret", runtime.secret,
        ]
        if runtime.enableExternalController {
            args.append(contentsOf: [
                "-ext-ctl",
                RuntimeConfigBuilder.guardedControllerAddress(
                    host: runtime.controllerHost,
                    port: runtime.controllerPort
                ),
            ])
        }
        proc.arguments = args
        proc.currentDirectoryURL = workDirectory

        var env = ProcessInfo.processInfo.environment
        env["CLASH_OVERRIDE_EXTERNAL_UI"] = ""
        proc.environment = env

        let errPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            throw CoreProcessError.launchFailed(error.localizedDescription)
        }

        process = proc
    }

    func stop(waitForExit: Bool = false) {
        lock.lock()
        let proc = process
        process = nil
        lock.unlock()

        guard let proc, proc.isRunning else { return }
        proc.terminate()

        DispatchQueue.global(qos: .utility).async {
            let deadline = Date().addingTimeInterval(2)
            while proc.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if proc.isRunning {
                proc.interrupt()
            }
            if waitForExit {
                proc.waitUntilExit()
            }
        }
    }
}
