import Foundation

enum UnlockService {
    static let defaultTargets: [UnlockTarget] = [
        UnlockTarget(id: "youtube", name: "YouTube", symbol: "play.rectangle.fill",
                     testURL: URL(string: "https://www.youtube.com/supported_browsers")!, successHint: "可访问"),
        UnlockTarget(id: "netflix", name: "Netflix", symbol: "film.fill",
                     testURL: URL(string: "https://www.netflix.com/title/80018499")!, successHint: "页面可达"),
        UnlockTarget(id: "disney", name: "Disney+", symbol: "sparkles.tv.fill",
                     testURL: URL(string: "https://www.disneyplus.com")!, successHint: "页面可达"),
        UnlockTarget(id: "openai", name: "OpenAI", symbol: "brain.head.profile",
                     testURL: URL(string: "https://api.openai.com/v1/models")!, successHint: "API 可达"),
        UnlockTarget(id: "bilibili", name: "Bilibili", symbol: "tv.fill",
                     testURL: URL(string: "https://api.bilibili.com/x/web-interface/nav")!, successHint: "国内直连"),
        UnlockTarget(id: "spotify", name: "Spotify", symbol: "music.note",
                     testURL: URL(string: "https://open.spotify.com")!, successHint: "页面可达")
    ]
}
