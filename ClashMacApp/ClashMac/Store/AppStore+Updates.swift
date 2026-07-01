import Foundation

// 内核 / GeoData 更新相关逻辑，从 AppStore 主体拆出以收敛巨石文件。
extension AppStore {
    func checkCoreUpdate() async {
        guard !isCheckingCore else { return }
        isCheckingCore = true
        updateStatusMessage = "正在检查内核版本…"
        defer { isCheckingCore = false }
        do {
            let status = try await CoreUpdateService.checkForUpdate(localVersion: version)
            latestCoreVersion = status.remoteVersion
            coreUpdateAvailable = status.updateAvailable
            if !status.isInstalled && CoreLocator.bundledCoreURL() == nil {
                updateStatusMessage = "未安装内核，最新 v\(status.remoteVersion)"
            } else if status.updateAvailable {
                let local = status.localVersion ?? "未知"
                updateStatusMessage = "发现新版本 v\(status.remoteVersion)（当前 \(local)）"
            } else {
                updateStatusMessage = "内核已是最新 v\(status.remoteVersion)"
            }
        } catch {
            updateStatusMessage = "检查失败：\(error.localizedDescription)"
        }
    }

    func updateCore(restartIfRunning: Bool = true) async {
        if isUpdatingCore {
            updateStatusMessage = updateStatusMessage ?? "内核下载已在进行中…"
            return
        }
        isUpdatingCore = true
        coreUpdateProgress = 0
        updateStatusMessage = "准备下载内核…"
        defer {
            isUpdatingCore = false
            coreUpdateProgress = 0
        }
        let wasRunning = coreState.isRunning
        do {
            let url = try await CoreUpdateService.downloadAndInstall { [weak self] progress, message in
                Task { @MainActor in
                    self?.coreUpdateProgress = progress
                    self?.updateStatusMessage = message
                }
            }
            corePath = url.path
            version = CoreLocator.coreVersion(at: url) ?? "—"
            latestCoreVersion = try? await CoreUpdateService.latestVersion()
            coreUpdateAvailable = false
            updateStatusMessage = "内核已更新至 \(coreVersionLabel)"
            if restartIfRunning && wasRunning {
                await stop()
                await start()
            }
        } catch {
            let detail = error.localizedDescription
            updateStatusMessage = "内核下载失败：\(detail)"
            if case CoreUpdateError.downloadFailed = error {
                updateStatusMessage = "内核下载失败：未找到适配当前架构的安装包"
            }
        }
    }

    func checkGeoData() async {
        guard !isCheckingGeoData else { return }
        isCheckingGeoData = true
        updateStatusMessage = "正在检查 GeoData…"
        defer { isCheckingGeoData = false }
        do {
            let status = try await GeoDataUpdateService.checkStatus()
            geoDataRelease = status.remoteRelease
            geoLocalRelease = status.localRelease
            geoMissingFiles = status.missingFiles
            if status.isComplete {
                let local = status.localRelease ?? "已安装"
                updateStatusMessage = "GeoData 已就绪（\(local)）"
            } else {
                updateStatusMessage = "缺少 \(status.missingFiles.joined(separator: "、"))，最新 \(status.remoteRelease)"
            }
        } catch {
            updateStatusMessage = "GeoData 检查失败：\(error.localizedDescription)"
        }
    }

    func updateGeoData() async {
        if isUpdatingGeoData {
            updateStatusMessage = updateStatusMessage ?? "GeoData 下载已在进行中…"
            return
        }
        isUpdatingGeoData = true
        geoUpdateProgress = 0
        updateStatusMessage = "准备下载 GeoData…"
        defer {
            isUpdatingGeoData = false
            geoUpdateProgress = 0
        }
        do {
            try await GeoDataUpdateService.downloadAll { [weak self] progress, message in
                Task { @MainActor in
                    self?.geoUpdateProgress = progress
                    self?.updateStatusMessage = message
                }
            }
            let status = try await GeoDataUpdateService.checkStatus()
            geoDataRelease = status.remoteRelease
            geoLocalRelease = status.localRelease
            geoMissingFiles = status.missingFiles
            updateStatusMessage = "GeoData 已更新至 \(status.remoteRelease)"
            if coreState.isRunning {
                try? await api.reloadConfig()
            }
        } catch {
            updateStatusMessage = "GeoData 下载失败：\(error.localizedDescription)"
        }
    }
}
