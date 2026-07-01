import Foundation

// 流媒体解锁检测相关逻辑，从 AppStore 主体拆出以收敛巨石文件。
extension AppStore {
    private var activeProxyName: String? {
        groups.flatMap(\.nodes).first(where: \.isSelected)?.name
    }

    func runUnlockTests() async {
        guard !unlockTargets.contains(where: { $0.status == .testing }) else { return }
        for index in unlockTargets.indices {
            unlockTargets[index].status = .testing
            let (status, region) = await UnlockService.test(unlockTargets[index], activeProxyName: activeProxyName)
            unlockTargets[index].status = status
            unlockTargets[index].regionCode = region
            unlockTargets[index].lastTestedAt = .now
        }
        try? UnlockTargetStore.save(unlockTargets)
    }

    func runSingleUnlockTest(_ target: UnlockTarget) async {
        guard let index = unlockTargets.firstIndex(where: { $0.id == target.id }) else { return }
        unlockTargets[index].status = .testing
        let (status, region) = await UnlockService.test(unlockTargets[index], activeProxyName: activeProxyName)
        unlockTargets[index].status = status
        unlockTargets[index].regionCode = region
        unlockTargets[index].lastTestedAt = .now
        try? UnlockTargetStore.save(unlockTargets)
    }

    func addCustomUnlockTarget() {
        guard !customUnlockName.isEmpty, let url = URL(string: customUnlockURL) else { return }
        let target = UnlockTarget(
            id: UUID().uuidString,
            name: customUnlockName,
            symbol: "link",
            testURL: url,
            successHint: "自定义"
        )
        unlockTargets.append(target)
        customUnlockName = ""
        customUnlockURL = ""
        try? UnlockTargetStore.save(unlockTargets)
    }
}
