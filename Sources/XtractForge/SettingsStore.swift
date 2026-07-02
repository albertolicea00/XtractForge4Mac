import Foundation
import Observation
import XtractForgeCore

/// Observable wrapper around `AppSettings`, persisted as JSON in UserDefaults.
@Observable
final class SettingsStore {
    private static let key = "appSettings"

    var settings: AppSettings {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func isEnabled(_ downloaderId: String) -> Bool {
        !settings.disabledDownloaders.contains(downloaderId)
    }

    func setEnabled(_ downloaderId: String, _ enabled: Bool) {
        var list = settings.disabledDownloaders.filter { $0 != downloaderId }
        if !enabled { list.append(downloaderId) }
        settings.disabledDownloaders = list
    }
}
