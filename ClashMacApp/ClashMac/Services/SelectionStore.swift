import Foundation

/// 本地持久化「策略组 → 选中节点」的映射，作为节点选择的唯一可见来源。
/// 内核重启后由 AppStore 主动回放，避免依赖内核二进制缓存（cache.db）在用户态/特权态切换时丢失。
enum SelectionStore {
    nonisolated(unsafe) private static let queue = DispatchQueue(label: "com.clashmac.selectionstore")

    private static func fileURL() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("selections.json")
    }

    static func all() -> [String: String] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL()),
                  let map = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return map
        }
    }

    static func set(group: String, node: String) {
        queue.sync {
            var map: [String: String] = {
                guard let data = try? Data(contentsOf: fileURL()),
                      let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                    return [:]
                }
                return decoded
            }()
            guard map[group] != node else { return }
            map[group] = node
            persist(map)
        }
    }

    /// 移除已不存在的策略组的记录，保持文件精简（在拉到最新分组后调用）。
    static func prune(keeping groupNames: Set<String>) {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL()),
                  var map = try? JSONDecoder().decode([String: String].self, from: data) else {
                return
            }
            let filtered = map.filter { groupNames.contains($0.key) }
            guard filtered.count != map.count else { return }
            map = filtered
            persist(map)
        }
    }

    private static func persist(_ map: [String: String]) {
        let dir = RuntimeConfigBuilder.appSupportDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(map) {
            try? data.write(to: fileURL(), options: .atomic)
        }
    }
}
