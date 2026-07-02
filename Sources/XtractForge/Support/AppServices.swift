import AppKit
import Observation
import UserNotifications
import XtractForgeCore

/// Single entry point for every URL that enters the app (drop, paste,
/// clipboard watch — and later the xtractforge:// scheme).
@MainActor
@Observable
final class IntakeService {
    let manager: DownloadManager

    init(manager: DownloadManager) {
        self.manager = manager
    }

    /// Extracts URLs from arbitrary text and queues each one.
    /// Returns how many downloads were queued.
    @discardableResult
    func submit(text: String) -> Int {
        let urls = Intake.extractURLs(from: text)
        for url in urls {
            manager.submit(url)
        }
        return urls.count
    }

    func pasteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            submit(text: text)
        }
    }
}

/// Completion notifications. UNUserNotificationCenter requires a real app
/// bundle — when running the bare SPM executable it is skipped.
enum NotificationService {
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestPermission() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyCompleted(title: String, destination: String?) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Download complete"
        content.body = title
        if let destination { content.subtitle = destination }
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func notifyFailed(title: String, error: String) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Download failed"
        content.body = "\(title)\n\(error)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

enum Appearance {
    static func apply(_ setting: AppearanceSetting) {
        switch setting {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// Keeps the machine from App-Napping while downloads run.
@MainActor
final class ActivityKeeper {
    private var token: NSObjectProtocol?

    func update(active: Bool) {
        if active, token == nil {
            token = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "Downloading media"
            )
        } else if !active, let token {
            ProcessInfo.processInfo.endActivity(token)
            self.token = nil
        }
    }
}

enum Formatters {
    static func bytes(_ count: Int64?) -> String {
        guard let count, count > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    static func duration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "" }
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
