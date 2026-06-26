import Foundation
import Darwin

enum HelperAudit {
    static func effectiveGID(for connection: NSXPCConnection) -> gid_t? {
        guard let token = copyAuditToken(from: connection) else { return nil }

        var auid: uid_t = 0
        var euid: uid_t = 0
        var egid: gid_t = 0
        var ruid: uid_t = 0
        var rgid: gid_t = 0
        var pid: pid_t = 0
        var asid: au_asid_t = 0
        var tid = au_tid()

        audit_token_to_au32(
            token,
            &auid,
            &euid,
            &egid,
            &ruid,
            &rgid,
            &pid,
            &asid,
            &tid
        )
        return egid
    }

    private static func copyAuditToken(from connection: NSXPCConnection) -> audit_token_t? {
        let sel = NSSelectorFromString("auditToken")
        guard connection.responds(to: sel) else { return nil }
        let method = connection.method(for: sel)
        typealias Getter = @convention(c) (AnyObject, Selector) -> audit_token_t
        let token = unsafeBitCast(method, to: Getter.self)(connection, sel)
        return token
    }
}
