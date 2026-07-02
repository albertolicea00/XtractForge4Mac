import SwiftUI
import AppKit
import XtractForgeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NotificationService.requestPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct XtractForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var store: SettingsStore
    @State private var manager: DownloadManager
    @State private var intake: IntakeService
    private let activityKeeper = ActivityKeeper()

    init() {
        let store = SettingsStore()
        let manager = DownloadManager(settingsProvider: { store.settings })
        manager.onStateChange = { item in
            switch item.state {
            case .completed:
                NotificationService.notifyCompleted(title: item.title, destination: item.destination)
            case .failed(let error):
                NotificationService.notifyFailed(title: item.title, error: error)
            default:
                break
            }
        }
        _store = State(initialValue: store)
        _manager = State(initialValue: manager)
        _intake = State(initialValue: IntakeService(manager: manager))
    }

    var body: some Scene {
        Window("XtractForge", id: "main") {
            MainView()
                .environment(store)
                .environment(manager)
                .environment(intake)
                .onAppear { Appearance.apply(store.settings.appearance) }
                .onChange(of: store.settings.appearance) { _, newValue in
                    Appearance.apply(newValue)
                }
                .onChange(of: manager.activeCount) { _, count in
                    NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
                    activityKeeper.update(active: count > 0)
                }
        }
        .defaultSize(width: 560, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Paste URL") {
                    intake.pasteFromClipboard()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Open Downloads Folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: store.settings.downloadFolder))
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Clear Finished") {
                    manager.clearFinished()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(store)
        }
    }
}
