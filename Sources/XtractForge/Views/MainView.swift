import SwiftUI
import AppKit
import UniformTypeIdentifiers
import XtractForgeCore

struct MainView: View {
    @Environment(DownloadManager.self) private var manager
    @Environment(SettingsStore.self) private var store
    @Environment(IntakeService.self) private var intake

    @State private var isDropTargeted = false
    @State private var clipboardSuggestion: String?
    @State private var lastClipboardChange = NSPasteboard.general.changeCount

    private var itemAwaitingOptions: DownloadItem? {
        manager.items.first { $0.state == .awaitingOptions }
    }

    var body: some View {
        VStack(spacing: 0) {
            DropZoneView(isTargeted: isDropTargeted)
                .padding()

            if let suggestion = clipboardSuggestion {
                clipboardBanner(suggestion)
            }

            Divider()

            if manager.items.isEmpty {
                emptyState
            } else {
                List(manager.items) { item in
                    DownloadRowView(item: item)
                        .listRowSeparator(.visible)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .onDrop(of: [.url, .fileURL, .text, .plainText], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    intake.pasteFromClipboard()
                } label: {
                    Label("Paste URL", systemImage: "doc.on.clipboard")
                }
                .help("Paste a URL from the clipboard (⇧⌘V)")

                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: store.settings.downloadFolder))
                } label: {
                    Label("Open Downloads Folder", systemImage: "folder")
                }
                .help("Open the downloads folder (⇧⌘O)")

                Button {
                    manager.clearFinished()
                } label: {
                    Label("Clear Finished", systemImage: "xmark.bin")
                }
                .help("Remove finished items from the list (⇧⌘K)")
                .disabled(manager.items.allSatisfy { $0.state.isActive || $0.state == .awaitingOptions })
            }
        }
        .sheet(item: sheetBinding) { item in
            OptionsSheet(item: item)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            checkClipboard()
        }
    }

    private var sheetBinding: Binding<DownloadItem?> {
        Binding(
            get: { itemAwaitingOptions },
            set: { newValue in
                // Sheet dismissed without choosing → drop the pending item.
                if newValue == nil, let pending = itemAwaitingOptions {
                    manager.remove(pending)
                }
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 42))
                .foregroundStyle(.tertiary)
            Text("No downloads yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Drop a link above, or paste one with ⇧⌘V")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func clipboardBanner(_ url: String) -> some View {
        HStack {
            Image(systemName: "link")
            Text(url)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Download") {
                intake.submit(text: url)
                clipboardSuggestion = nil
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button {
                clipboardSuggestion = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        Task { @MainActor in intake.submit(text: url.path) }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        Task { @MainActor in intake.submit(text: url.absoluteString) }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSString.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSString.self) { text, _ in
                    if let text = text as? String {
                        Task { @MainActor in intake.submit(text: text) }
                    }
                }
            }
        }
        return handled
    }

    private func checkClipboard() {
        guard store.settings.watchClipboard else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastClipboardChange else { return }
        lastClipboardChange = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string),
              let first = Intake.extractURLs(from: text).first,
              !manager.items.contains(where: { $0.url == first }) else { return }
        clipboardSuggestion = first
    }
}
