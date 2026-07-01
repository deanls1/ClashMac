import Foundation

// 代理 Provider 更新与网站延迟测试逻辑，从 AppStore 主体拆出以收敛巨石文件。
extension AppStore {
    func testWebsiteLatency(id: String) async {
        guard let index = websiteTests.firstIndex(where: { $0.id == id }) else { return }
        websiteTests[index].isTesting = true
        let url = websiteTests[index].url
        let port = coreState.isRunning ? mixedPort : nil
        let delay = await WebsiteLatencyService.measure(url: url, proxyPort: port)
        if let index = websiteTests.firstIndex(where: { $0.id == id }) {
            websiteTests[index].delayMs = delay
            websiteTests[index].isTesting = false
        }
    }

    func testAllWebsites() async {
        guard !isTestingWebsites else { return }
        isTestingWebsites = true
        defer { isTestingWebsites = false }
        for item in websiteTests {
            await testWebsiteLatency(id: item.id)
        }
    }

    func refreshProxyProviders() async {
        guard coreState.isRunning else {
            proxyProviders = []
            return
        }
        proxyProviders = (try? await api.fetchProxyProviders()) ?? []
    }

    func updateProxyProvider(_ name: String) async {
        guard coreState.isRunning, !updatingProviderNames.contains(name) else { return }
        updatingProviderNames.insert(name)
        defer { updatingProviderNames.remove(name) }
        do {
            try await api.updateProxyProvider(name)
            await refreshProxyProviders()
            await refreshGroups()
            updateStatusMessage = "Provider「\(name)」已更新"
        } catch {
            updateStatusMessage = "Provider 更新失败：\(error.localizedDescription)"
        }
    }

    func updateAllProxyProviders() async {
        guard coreState.isRunning else { return }
        for provider in proxyProviders {
            await updateProxyProvider(provider.name)
        }
    }
}
