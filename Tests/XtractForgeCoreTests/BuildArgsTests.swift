import XCTest
@testable import XtractForgeCore

final class BuildArgsTests: XCTestCase {
    let folder = "/tmp/dl"

    func options(_ pluginOptions: [String: String] = [:], formatId: String? = nil,
                 audioOnly: Bool = false, isPlaylist: Bool = false,
                 resume: Bool = false) -> DownloadOptions {
        DownloadOptions(downloadFolder: folder, formatId: formatId, audioOnly: audioOnly,
                        isPlaylist: isPlaylist, resume: resume, pluginOptions: pluginOptions)
    }

    // MARK: yt-dlp

    func testYtDlpDefaults() {
        let cmd = YtDlp().buildArgs("https://youtu.be/x", options: options(), settings: AppSettings())
        XCTAssertEqual(cmd.binary, "yt-dlp")
        XCTAssertEqual(cmd.args, ["-o", "/tmp/dl/%(title)s.%(ext)s",
                                  "-f", "bestvideo+bestaudio/best",
                                  "https://youtu.be/x"])
    }

    func testYtDlpPlaylistTemplate() {
        let cmd = YtDlp().buildArgs("u", options: options(isPlaylist: true), settings: AppSettings())
        XCTAssertTrue(cmd.args.contains("/tmp/dl/%(playlist_title)s/%(playlist_index)s - %(title)s.%(ext)s"))
    }

    func testYtDlpAudioOnly() {
        let cmd = YtDlp().buildArgs("u", options: options(audioOnly: true), settings: AppSettings())
        XCTAssertTrue(cmd.args.contains("-x"))
        XCTAssertEqual(cmd.args[cmd.args.firstIndex(of: "--audio-format")! + 1], "mp3")
        XCTAssertFalse(cmd.args.contains("-f"))
    }

    func testYtDlpExplicitFormatWinsOverAudioOnly() {
        let cmd = YtDlp().buildArgs("u", options: options(formatId: "137+140"), settings: AppSettings())
        XCTAssertEqual(cmd.args[cmd.args.firstIndex(of: "-f")! + 1], "137+140")
    }

    func testYtDlpSettingsFlags() {
        var settings = AppSettings()
        settings.speedLimit = "5M"
        settings.embedSubtitles = true
        settings.sponsorBlock = true
        let cmd = YtDlp().buildArgs("u", options: options(resume: true), settings: settings)
        XCTAssertEqual(cmd.args[cmd.args.firstIndex(of: "-r")! + 1], "5M")
        XCTAssertTrue(cmd.args.contains("--embed-subs"))
        XCTAssertTrue(cmd.args.contains("--all-subs"))
        XCTAssertEqual(cmd.args[cmd.args.firstIndex(of: "--sponsorblock-remove")! + 1], "all")
        XCTAssertTrue(cmd.args.contains("-c"))
        XCTAssertEqual(cmd.args.last, "u")
    }

    // MARK: lux

    func testLuxDefaults() {
        let cmd = Lux().buildArgs("https://bilibili.com/v", options: options(), settings: AppSettings())
        XCTAssertEqual(cmd.args, ["-o", folder, "https://bilibili.com/v"])
    }

    func testLuxAllOptions() {
        var settings = AppSettings()
        settings.luxCookie = "SESSDATA=abc"
        settings.luxMultiThread = true
        let cmd = Lux().buildArgs("u", options: options(formatId: "dash-flv"), settings: settings)
        XCTAssertEqual(cmd.args, ["-o", folder, "-f", "dash-flv", "-c", "SESSDATA=abc", "-m", "u"])
    }

    func testLuxBestFormatIsOmitted() {
        let cmd = Lux().buildArgs("u", options: options(formatId: "best"), settings: AppSettings())
        XCTAssertFalse(cmd.args.contains("-f"))
    }

    // MARK: gallery-dl

    func testGalleryDlArgs() {
        var settings = AppSettings()
        settings.galleryDlCookies = "/c.txt"
        settings.galleryDlConfig = "/g.conf"
        let cmd = GalleryDl().buildArgs("u", options: options(), settings: settings)
        XCTAssertEqual(cmd.args, ["-d", folder, "--cookies", "/c.txt", "--config", "/g.conf", "u"])
    }

    // MARK: spotdl

    func testSpotDlArgs() {
        let cmd = SpotDl().buildArgs("https://open.spotify.com/track/x",
                                     options: options(), settings: AppSettings())
        XCTAssertEqual(cmd.args, [
            "download", "https://open.spotify.com/track/x",
            "--output", "/tmp/dl/{artist} - {title}.{output-ext}",
            "--format", "mp3", "--bitrate", "320k",
        ])
    }

    // MARK: ffmpeg

    func testFFmpegStreamRecording() {
        let cmd = FFmpegTool().buildArgs("https://cdn.x.com/live/master.m3u8",
                                         options: options(), settings: AppSettings())
        XCTAssertEqual(cmd.args, ["-y", "-stats", "-i", "https://cdn.x.com/live/master.m3u8",
                                  "-c", "copy", "-bsf:a", "aac_adtstoasc", "/tmp/dl/master.mp4"])
    }

    func testFFmpegMkvSkipsBitstreamFilter() {
        let cmd = FFmpegTool().buildArgs("https://x.com/s.m3u8",
                                         options: options(["container": "mkv"]),
                                         settings: AppSettings())
        XCTAssertFalse(cmd.args.contains("-bsf:a"))
        XCTAssertEqual(cmd.args.last, "/tmp/dl/s.mkv")
    }

    func testFFmpegLocalConvertCopy() {
        let cmd = FFmpegTool().buildArgs("/Users/x/clip.mov", options: options(), settings: AppSettings())
        XCTAssertEqual(cmd.args, ["-y", "-stats", "-i", "/Users/x/clip.mov",
                                  "-vcodec", "copy", "-acodec", "copy",
                                  "/tmp/dl/clip_converted.mp4"])
    }

    func testFFmpegExtractAudioMp3() {
        let cmd = FFmpegTool().buildArgs(
            "/Users/x/clip.mp4",
            options: options(["action": "extract_audio", "container": "mp3", "audioCodec": "mp3"]),
            settings: AppSettings()
        )
        XCTAssertTrue(cmd.args.contains("-vn"))
        XCTAssertEqual(cmd.args[cmd.args.firstIndex(of: "-acodec")! + 1], "libmp3lame")
        XCTAssertEqual(cmd.args.last, "/tmp/dl/clip_converted.mp3")
    }

    // MARK: curl

    func testCurlDefaults() {
        let cmd = Curl().buildArgs("https://example.com/file.zip", options: options(), settings: AppSettings())
        XCTAssertEqual(cmd.args, ["-L", "--create-dirs", "-o", "/tmp/dl/file.zip",
                                  "https://example.com/file.zip"])
    }

    func testCurlResumeAndSpeedLimitAndRename() {
        var settings = AppSettings()
        settings.speedLimit = "1M"
        let cmd = Curl().buildArgs("https://example.com/file.zip",
                                   options: options(["filename": "renamed.zip"], resume: true),
                                   settings: settings)
        XCTAssertEqual(cmd.args, ["-L", "--create-dirs", "-C", "-", "-o", "/tmp/dl/renamed.zip",
                                  "https://example.com/file.zip", "--limit-rate", "1M"])
    }
}
