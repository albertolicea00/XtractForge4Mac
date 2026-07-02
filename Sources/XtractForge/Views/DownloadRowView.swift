import SwiftUI
import AppKit
import XtractForgeCore

struct DownloadRowView: View {
    @Environment(DownloadManager.self) private var manager
    var item: DownloadItem

    var body: some View {
        HStack(spacing: 12) {
            stateIcon
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.state == .downloading || item.state == .paused {
                    ProgressView(value: item.progress.percent.map { min($0, 100) / 100 })
                        .progressViewStyle(.linear)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            actions
        }
        .padding(.vertical, 4)
    }

    private var stateIcon: some View {
        Group {
            switch item.state {
            case .fetchingInfo, .awaitingOptions:
                ProgressView().controlSize(.small)
            case .downloading:
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentColor)
            case .paused:
                Image(systemName: "pause.circle.fill").foregroundStyle(.orange)
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            case .cancelled:
                Image(systemName: "slash.circle").foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        switch item.state {
        case .fetchingInfo:
            return "Fetching info…"
        case .awaitingOptions:
            return "Choosing options…"
        case .downloading:
            var parts: [String] = []
            if let pct = item.progress.percent { parts.append(String(format: "%.1f%%", pct)) }
            if !item.progress.size.isEmpty { parts.append(item.progress.size) }
            if !item.progress.speed.isEmpty { parts.append(item.progress.speed) }
            if !item.progress.eta.isEmpty { parts.append("ETA " + item.progress.eta) }
            if let count = item.progress.fileCount { parts.append("\(count) files") }
            let status = parts.joined(separator: " · ")
            return status.isEmpty ? "Downloading… · \(item.downloaderId)" : status + " · " + item.downloaderId
        case .paused:
            return "Paused · \(item.downloaderId)"
        case .completed:
            return item.destination ?? "Completed"
        case .failed(let error):
            return error
        case .cancelled:
            return "Cancelled"
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            switch item.state {
            case .downloading:
                rowButton("pause.fill", "Pause") { manager.pause(item) }
                rowButton("xmark", "Cancel") { manager.cancel(item) }
            case .paused:
                rowButton("play.fill", "Resume") { manager.resume(item) }
                rowButton("xmark", "Cancel") { manager.cancel(item) }
            case .completed:
                rowButton("magnifyingglass", "Reveal in Finder") { reveal() }
                rowButton("trash", "Remove from list") { manager.remove(item) }
            case .failed:
                rowButton("arrow.clockwise", "Retry") { manager.retry(item) }
                rowButton("trash", "Remove from list") { manager.remove(item) }
            case .cancelled:
                rowButton("trash", "Remove from list") { manager.remove(item) }
            case .fetchingInfo, .awaitingOptions:
                rowButton("xmark", "Cancel") { manager.remove(item) }
            }
        }
        .buttonStyle(.borderless)
    }

    private func rowButton(_ icon: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .help(help)
    }

    private func reveal() {
        guard let destination = item.destination else { return }
        let url = URL(fileURLWithPath: destination)
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: destination, isDirectory: &isDir)
        if isDir.boolValue {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
