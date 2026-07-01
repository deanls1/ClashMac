import AppKit
import UniformTypeIdentifiers

enum MenuBarIconStore {
    private static let fileName = "tray-icon"

    static func iconsDirectory() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("icons", isDirectory: true)
    }

    static func savedIconURL() -> URL {
        iconsDirectory().appendingPathComponent(fileName)
    }

    static func importIcon(from source: URL) throws -> URL {
        try RuntimeConfigBuilder.ensureDirectories()
        try FileManager.default.createDirectory(at: iconsDirectory(), withIntermediateDirectories: true)

        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw MenuBarIconError.unsupportedFormat(ext)
        }

        let destination = iconsDirectory().appendingPathComponent("\(fileName).\(ext)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func removeSavedIcon() {
        let dir = iconsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where file.lastPathComponent.hasPrefix(fileName) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func loadImage(from path: String?, template: Bool = false) -> NSImage? {
        guard let path, FileManager.default.fileExists(atPath: path),
              let image = NSImage(contentsOfFile: path) else { return nil }
        let prepared = prepareForMenuBar(image)
        prepared.isTemplate = template
        return prepared
    }

    nonisolated(unsafe) private static var cachedDefaultIcon: NSImage?

    static func defaultAppIcon() -> NSImage? {
        if let cachedDefaultIcon { return cachedDefaultIcon }
        guard let image = NSImage(named: "AppLogo") else { return nil }
        let prepared = prepareForMenuBar(image)
        prepared.isTemplate = false
        cachedDefaultIcon = prepared
        return prepared
    }

    static func prepareForMenuBar(_ image: NSImage) -> NSImage {
        let target = NSSize(width: 18, height: 18)
        let resized = NSImage(size: target)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1)
        resized.unlockFocus()
        return resized
    }

    private static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "icns", "pdf", "svg", "heic", "webp"]

    enum MenuBarIconError: LocalizedError {
        case unsupportedFormat(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext):
                "不支持的图标格式：.\(ext)"
            }
        }
    }

    static var openPanelAllowedTypes: [UTType] {
        [.png, .jpeg, .icns, .pdf, .svg, .heic, .webP]
    }
}
