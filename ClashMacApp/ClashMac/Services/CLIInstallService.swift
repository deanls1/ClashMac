import Foundation

enum CLIInstallService {
    enum CLIError: LocalizedError {
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .writeFailed: "CLI 安装失败"
            }
        }
    }

    static func cliDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin", isDirectory: true)
    }

    static func cliPath() -> URL {
        cliDirectory().appendingPathComponent("clashmac")
    }

    static func envFileURL() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("cli.env")
    }

    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: cliPath().path)
    }

    static func writeEnvironment(runtime: RuntimeConfig) throws {
        let content = """
        CLASHMAC_SECRET="\(runtime.secret)"
        CLASHMAC_SOCKET="\(runtime.controllerUnixPath)"
        CLASHMAC_PORT="\(runtime.controllerPort)"
        CLASHMAC_HOST="\(runtime.controllerHost)"
        CLASHMAC_HTTP_ENABLED="\(runtime.enableExternalController ? "1" : "0")"
        """
        try FileManager.default.createDirectory(
            at: RuntimeConfigBuilder.appSupportDirectory(),
            withIntermediateDirectories: true
        )
        try content.write(to: envFileURL(), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: envFileURL().path)
    }

    static func install() throws -> URL {
        let envPath = envFileURL().path
        let script = """
        #!/bin/bash
        set -euo pipefail
        ENV_FILE="\(envPath)"
        if [[ ! -f "$ENV_FILE" ]]; then
          echo "Clash Mac 未运行或未生成 CLI 配置，请先启动代理。" >&2
          exit 1
        fi
        # shellcheck disable=SC1090
        source "$ENV_FILE"
        AUTH=(-H "Authorization: Bearer ${CLASHMAC_SECRET}")

        api() {
          if [[ "${CLASHMAC_HTTP_ENABLED:-0}" == "1" ]]; then
            curl -sf "${AUTH[@]}" "http://${CLASHMAC_HOST}:${CLASHMAC_PORT}$1"
          else
            curl -sf --unix-socket "${CLASHMAC_SOCKET}" "${AUTH[@]}" "http://localhost$1"
          fi
        }

        api_mut() {
          local method="$1" path="$2" body="${3:-}"
          if [[ "${CLASHMAC_HTTP_ENABLED:-0}" == "1" ]]; then
            curl -sf -X "$method" "${AUTH[@]}" -H "Content-Type: application/json" ${body:+-d "$body"} "http://${CLASHMAC_HOST}:${CLASHMAC_PORT}${path}"
          else
            curl -sf -X "$method" --unix-socket "${CLASHMAC_SOCKET}" "${AUTH[@]}" -H "Content-Type: application/json" ${body:+-d "$body"} "http://localhost${path}"
          fi
        }

        cmd="${1:-help}"
        case "$cmd" in
          status)
            api "/version" && echo
            api "/configs" | python3 -c "import sys,json; c=json.load(sys.stdin); print('mode:', c.get('mode','?'))" 2>/dev/null || true
            ;;
          on)
            api_mut PUT "/configs" '{"enabled":true}' >/dev/null
            echo "已启用"
            ;;
          off)
            api_mut DELETE "/connections" >/dev/null || true
            echo "已关闭全部连接"
            ;;
          mode)
            m="${2:-rule}"
            api_mut PATCH "/configs" "{\\"mode\\":\\"$m\\"}" >/dev/null
            echo "模式: $m"
            ;;
          proxies)
            api "/proxies"
            ;;
          help|*)
            echo "用法: clashmac {status|mode rule|global|direct|proxies|off|help}"
            ;;
        esac
        """

        try FileManager.default.createDirectory(at: cliDirectory(), withIntermediateDirectories: true)
        let dest = cliPath()
        try script.write(to: dest, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        return dest
    }
}
