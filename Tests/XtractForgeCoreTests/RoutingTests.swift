import XCTest
@testable import XtractForgeCore

final class RoutingTests: XCTestCase {
    func testSpotifyRoutesToSpotDl() {
        XCTAssertEqual(DownloaderRegistry.route("https://open.spotify.com/track/abc")?.id, "spotdl")
        XCTAssertEqual(DownloaderRegistry.route("spotify:track:abc")?.id, "spotdl")
    }

    func testGallerySitesRouteToGalleryDl() {
        XCTAssertEqual(DownloaderRegistry.route("https://www.pixiv.net/en/artworks/1")?.id, "gallery-dl")
        XCTAssertEqual(DownloaderRegistry.route("https://www.instagram.com/p/xyz/")?.id, "gallery-dl")
        XCTAssertEqual(DownloaderRegistry.route("https://x.com/user/status/1")?.id, "gallery-dl")
        XCTAssertEqual(DownloaderRegistry.route("https://imgur.com/gallery/abc")?.id, "gallery-dl")
    }

    func testAsianSitesRouteToLux() {
        XCTAssertEqual(DownloaderRegistry.route("https://www.bilibili.com/video/BV1x")?.id, "lux")
        XCTAssertEqual(DownloaderRegistry.route("https://v.douyin.com/abc/")?.id, "lux")
    }

    func testYouTubeRoutesToYtDlp() {
        // Deviation from the old app: YouTube belongs to the core engine, not lux.
        XCTAssertEqual(DownloaderRegistry.route("https://www.youtube.com/watch?v=dQw4w9WgXcQ")?.id, "yt-dlp")
        XCTAssertEqual(DownloaderRegistry.route("https://youtu.be/dQw4w9WgXcQ")?.id, "yt-dlp")
    }

    func testStreamsRouteToFFmpeg() {
        XCTAssertEqual(DownloaderRegistry.route("https://cdn.example.com/live/index.m3u8")?.id, "ffmpeg")
        XCTAssertEqual(DownloaderRegistry.route("https://cdn.example.com/x.m3u8?token=1")?.id, "ffmpeg")
        XCTAssertEqual(DownloaderRegistry.route("rtmp://live.example.com/app/key")?.id, "ffmpeg")
        XCTAssertEqual(DownloaderRegistry.route("/Users/x/Movies/clip.mp4")?.id, "ffmpeg")
    }

    func testDirectFilesRouteToCurl() {
        XCTAssertEqual(DownloaderRegistry.route("https://example.com/file.zip")?.id, "curl")
        XCTAssertEqual(DownloaderRegistry.route("https://example.com/song.mp3?ref=1")?.id, "curl")
        XCTAssertEqual(DownloaderRegistry.route("https://example.com/image.jpg")?.id, "curl")
    }

    func testStreamsNeverRouteToCurl() {
        XCTAssertNotEqual(DownloaderRegistry.route("https://example.com/live.m3u8")?.id, "curl")
    }

    func testUnknownUrlFallsBackToYtDlp() {
        XCTAssertEqual(DownloaderRegistry.route("https://random-video-site.example/watch/1")?.id, "yt-dlp")
    }

    func testDisabledDownloaderIsSkipped() {
        let routed = DownloaderRegistry.route("https://www.instagram.com/p/xyz/",
                                              disabled: ["gallery-dl"])
        XCTAssertEqual(routed?.id, "yt-dlp")
    }

    func testAllDisabledReturnsNil() {
        let allIds = DownloaderRegistry.all.map(\.id)
        XCTAssertNil(DownloaderRegistry.route("https://example.com/file.zip", disabled: allIds))
    }

    func testRegistryOrder() {
        XCTAssertEqual(DownloaderRegistry.all.map(\.id),
                       ["spotdl", "gallery-dl", "lux", "ffmpeg", "curl", "yt-dlp"])
    }
}
