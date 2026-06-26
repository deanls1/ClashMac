import AppKit
import SwiftUI

@MainActor
final class HotkeyService {
    static let shared = HotkeyService()

    private var localMonitor: Any?
    private var globalMonitor: Any?

    func registerTogglePower(global: Bool, handler: @escaping () -> Void) {
        removeMonitor()

        if global {
            guard globalHotkeyAvailable else {
                requestAccessibilityPermission()
                return
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                guard Self.isToggleShortcut(event) else { return }
                handler()
            }
        } else {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard Self.isToggleShortcut(event) else { return event }
                handler()
                return nil
            }
        }
    }

    func removeMonitor() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    var globalHotkeyAvailable: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func isToggleShortcut(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains([.command, .shift])
            && event.charactersIgnoringModifiers?.lowercased() == "p"
    }
}
