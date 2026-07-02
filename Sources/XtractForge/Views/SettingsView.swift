import SwiftUI
import AppKit
import XtractForgeCore

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            DownloadersSettingsTab()
                .tabItem { Label("Downloaders", systemImage: "square.and.arrow.down.on.square") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }
        }
        .frame(width: 520)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            HStack {
                TextField("Download folder", text: $store.settings.downloadFolder)
                    .truncationMode(.middle)
                Button("Choose…") { chooseFolder() }
            }

            TextField("Speed limit", text: $store.settings.speedLimit,
                      prompt: Text("50K, 10M (empty = unlimited)"))

            Toggle("Stage downloads in a temp folder", isOn: $store.settings.stageToTemp)
            Text("Tools write into a hidden temp folder; files move to the download folder only when the download succeeds.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Organize downloads", selection: $store.settings.organize) {
                Text("Don't organize").tag(Organize.none)
                Text("By type (Video/Audio/Images)").tag(Organize.type)
                Text("By source site").tag(Organize.source)
            }

            Toggle("Offer clipboard links when the app activates", isOn: $store.settings.watchClipboard)
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: store.settings.downloadFolder)
        if panel.runModal() == .OK, let url = panel.url {
            store.settings.downloadFolder = url.path
        }
    }
}

// MARK: - Downloaders

private struct DownloadersSettingsTab: View {
    @Environment(SettingsStore.self) private var store
    @State private var statuses: [String: DependencyStatus] = [:]

    var body: some View {
        Form {
            ForEach(DownloaderRegistry.all, id: \.id) { downloader in
                Section {
                    downloaderSection(downloader)
                } header: {
                    HStack {
                        Text(downloader.name)
                        Spacer()
                        statusBadge(downloader.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await checkAll() }
    }

    @ViewBuilder
    private func downloaderSection(_ downloader: any Downloader) -> some View {
        @Bindable var store = store

        Toggle("Enabled", isOn: Binding(
            get: { store.isEnabled(downloader.id) },
            set: { store.setEnabled(downloader.id, $0) }
        ))
        .disabled(downloader.id == "yt-dlp") // catch-all stays on

        TextField("Binary path", text: binaryBinding(downloader.id),
                  prompt: Text(downloader.binaryDefault))

        switch downloader.id {
        case "yt-dlp":
            Toggle("Embed subtitles", isOn: $store.settings.embedSubtitles)
            Toggle("SponsorBlock (skip sponsor segments)", isOn: $store.settings.sponsorBlock)
        case "ffmpeg":
            Picker("Stream output container", selection: $store.settings.ffmpegContainer) {
                ForEach(["mp4", "mkv", "ts"], id: \.self) { Text($0).tag($0) }
            }
        case "lux":
            TextField("Cookie (optional)", text: $store.settings.luxCookie)
            Toggle("Multi-thread download", isOn: $store.settings.luxMultiThread)
        case "gallery-dl":
            TextField("Cookies file (optional)", text: $store.settings.galleryDlCookies,
                      prompt: Text("/path/to/cookies.txt"))
            TextField("Config file (optional)", text: $store.settings.galleryDlConfig,
                      prompt: Text("/path/to/gallery-dl.conf"))
        case "spotdl":
            Picker("Format", selection: $store.settings.spotdlFormat) {
                ForEach(["mp3", "flac", "ogg", "opus", "m4a", "wav"], id: \.self) { Text($0).tag($0) }
            }
            Picker("Bitrate", selection: $store.settings.spotdlBitrate) {
                ForEach(["128k", "192k", "256k", "320k"], id: \.self) { Text($0).tag($0) }
            }
        default:
            EmptyView()
        }

        if statuses[downloader.id]?.available == false {
            Text("Not found — install with: \(downloader.installHint)")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func statusBadge(_ id: String) -> some View {
        if let status = statuses[id] {
            if status.available {
                Label(status.version, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Label("Not installed", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        } else {
            ProgressView().controlSize(.mini)
        }
    }

    private func binaryBinding(_ id: String) -> Binding<String> {
        @Bindable var store = store
        switch id {
        case "yt-dlp": return $store.settings.ytdlpPath
        case "ffmpeg": return $store.settings.ffmpegPath
        case "lux": return $store.settings.luxPath
        case "gallery-dl": return $store.settings.galleryDlPath
        case "spotdl": return $store.settings.spotdlPath
        default: return $store.settings.curlPath
        }
    }

    private func checkAll() async {
        let settings = store.settings
        for downloader in DownloaderRegistry.all {
            let status = await downloader.checkDependency(settings: settings)
            statuses[downloader.id] = status
        }
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Picker("Appearance", selection: $store.settings.appearance) {
                Text("Follow System").tag(AppearanceSetting.system)
                Text("Light").tag(AppearanceSetting.light)
                Text("Dark").tag(AppearanceSetting.dark)
            }
            .pickerStyle(.inline)
        }
        .formStyle(.grouped)
    }
}
