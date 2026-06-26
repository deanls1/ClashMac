import AppKit
import Foundation

enum ProxyEnvironmentClipboard {
    static func copyMixedPort(_ port: Int) {
        let text = """
        export http_proxy=http://127.0.0.1:\(port)
        export https_proxy=http://127.0.0.1:\(port)
        export all_proxy=socks5://127.0.0.1:\(port)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
