import SwiftUI
import XtractForgeCore

/// Per-download options shown before queueing (format/quality + any
/// downloader-declared option fields).
struct OptionsSheet: View {
    @Environment(DownloadManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    let item: DownloadItem

    @State private var selectedFormat = "best"
    @State private var audioOnly = false
    @State private var audioFormat = "mp3"
    @State private var fieldValues: [String: String] = [:]

    private var info: MediaInfo? { item.info }
    private var isYtDlp: Bool { item.downloaderId == "yt-dlp" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding()

            Divider()

            Form {
                if let info, !info.formats.isEmpty {
                    Picker("Format", selection: $selectedFormat) {
                        Text("Best available").tag("best")
                        ForEach(info.formats) { format in
                            Text(formatLabel(format)).tag(format.formatId)
                        }
                    }
                    .disabled(audioOnly)
                }

                if isYtDlp {
                    Toggle("Audio only", isOn: $audioOnly)
                    if audioOnly {
                        Picker("Audio format", selection: $audioFormat) {
                            ForEach(["mp3", "m4a", "opus", "flac", "wav"], id: \.self) {
                                Text($0.uppercased()).tag($0)
                            }
                        }
                    }
                }

                if let info {
                    ForEach(info.optionFields) { field in
                        optionFieldView(field)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let info, info.isPlaylist {
                    Label("Playlist · \(info.entryCount) items", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    manager.remove(item)
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Download") {
                    manager.start(
                        item,
                        options: fieldValues,
                        formatId: (selectedFormat == "best" || audioOnly) ? nil : selectedFormat,
                        audioOnly: audioOnly
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 440)
        .frame(minHeight: 260, maxHeight: 480)
        .onAppear {
            for field in info?.optionFields ?? [] {
                fieldValues[field.key] = field.defaultValue
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(item.downloaderId)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                if let info, !info.uploader.isEmpty {
                    Text(info.uploader)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let info, info.duration > 0 {
                    Text(Formatters.duration(info.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func optionFieldView(_ field: OptionField) -> some View {
        switch field.kind {
        case .text:
            TextField(field.label, text: binding(field), prompt: Text(field.placeholder))
        case .toggle:
            Toggle(field.label, isOn: Binding(
                get: { fieldValues[field.key] == "true" },
                set: { fieldValues[field.key] = $0 ? "true" : "false" }
            ))
        case .select:
            Picker(field.label, selection: binding(field)) {
                ForEach(field.options, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    private func binding(_ field: OptionField) -> Binding<String> {
        Binding(
            get: { fieldValues[field.key] ?? field.defaultValue },
            set: { fieldValues[field.key] = $0 }
        )
    }

    private func formatLabel(_ format: MediaFormat) -> String {
        var parts = [format.resolution.isEmpty ? format.formatId : format.resolution]
        if !format.ext.isEmpty { parts.append(format.ext) }
        if !format.note.isEmpty { parts.append(format.note) }
        let size = Formatters.bytes(format.filesize)
        if !size.isEmpty { parts.append(size) }
        return parts.joined(separator: " · ")
    }
}
