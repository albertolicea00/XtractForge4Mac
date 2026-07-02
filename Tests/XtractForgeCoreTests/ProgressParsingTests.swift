import XCTest
@testable import XtractForgeCore

final class ProgressParsingTests: XCTestCase {
    func testYtDlpProgressLine() {
        let update = YtDlp().parseProgress("[download]  42.5% of ~120.5MiB at 3.2MiB/s ETA 00:42")
        XCTAssertEqual(update?.percent, 42.5)
        XCTAssertEqual(update?.size, "120.5MiB")
        XCTAssertEqual(update?.speed, "3.2MiB/s")
        XCTAssertEqual(update?.eta, "00:42")
    }

    func testYtDlpProgressWithoutTilde() {
        let update = YtDlp().parseProgress("[download] 100.0% of 55.3MiB at 10.1MiB/s ETA 00:00")
        XCTAssertEqual(update?.percent, 100.0)
        XCTAssertEqual(update?.size, "55.3MiB")
    }

    func testYtDlpIgnoresNonProgressLines() {
        XCTAssertNil(YtDlp().parseProgress("[youtube] dQw4: Downloading webpage"))
        XCTAssertNil(YtDlp().parseProgress("[download] Destination: video.mp4"))
    }

    func testLuxProgress() {
        let update = Lux().parseProgress(" 2.34 MiB / 10.00 MiB [====>-----] 23.40% 4.31 MiB/s")
        XCTAssertEqual(update?.percent, 23.40)
        XCTAssertEqual(update?.speed, "4.31 MiB/s")
    }

    func testGalleryDlFileCount() {
        let update = GalleryDl().parseProgress("#12 https://i.pximg.net/img/a.png")
        XCTAssertNil(update?.percent)
        XCTAssertEqual(update?.fileCount, 12)
        XCTAssertNil(GalleryDl().parseProgress("no counter here"))
    }

    func testSpotDlHeuristics() {
        XCTAssertEqual(SpotDl().parseProgress("Downloaded \"Artist - Song\"")?.percent, 100)
        XCTAssertEqual(SpotDl().parseProgress("Skipping Song (already exists)")?.percent, 100)
        XCTAssertEqual(SpotDl().parseProgress("Downloading Song")?.percent, 50)
        XCTAssertNil(SpotDl().parseProgress("Processing query"))
    }

    func testFFmpegProgress() {
        let update = FFmpegTool().parseProgress(
            "frame=  100 fps= 25 q=-1.0 size=  2048kB time=00:01:02.50 bitrate=1000.0kbits/s speed=1.02x")
        XCTAssertNil(update?.percent)
        XCTAssertEqual(update?.size, "00:01:02")
        XCTAssertEqual(update?.speed, "1.02x")
        XCTAssertNil(FFmpegTool().parseProgress("Stream mapping:"))
    }

    func testCurlProgress() {
        XCTAssertEqual(Curl().parseProgress(" 42  120M   42  50M    0     0  3319k      0  0:00:37  0:00:15  0:00:22 3800k")?.percent, 42)
        XCTAssertEqual(Curl().parseProgress("100  120M  100  120M    0     0  4000k      0  0:00:30  0:00:30 --:--:-- 4100k")?.percent, 100)
        XCTAssertNil(Curl().parseProgress("curl: (6) Could not resolve host"))
        XCTAssertNil(Curl().parseProgress("  % Total    % Received % Xferd"))
    }
}
