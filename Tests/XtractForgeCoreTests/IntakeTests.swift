import XCTest
@testable import XtractForgeCore

final class IntakeTests: XCTestCase {
    func testExtractsHttpUrls() {
        let urls = Intake.extractURLs(from: "check https://youtu.be/x and http://a.com/b.mp4 out")
        XCTAssertEqual(urls, ["https://youtu.be/x", "http://a.com/b.mp4"])
    }

    func testExtractsMultilineAndDeduplicates() {
        let text = """
        https://youtu.be/x
        https://youtu.be/x
        https://open.spotify.com/track/y
        """
        XCTAssertEqual(Intake.extractURLs(from: text),
                       ["https://youtu.be/x", "https://open.spotify.com/track/y"])
    }

    func testExtractsSpotifyUriAndStreams() {
        XCTAssertEqual(Intake.extractURLs(from: "spotify:track:abc"), ["spotify:track:abc"])
        XCTAssertEqual(Intake.extractURLs(from: "rtmp://live.x.com/key"), ["rtmp://live.x.com/key"])
    }

    func testTrimsTrailingPunctuation() {
        XCTAssertEqual(Intake.extractURLs(from: "look: https://a.com/v.mp4."),
                       ["https://a.com/v.mp4"])
    }

    func testBareDomainWithPathGetsScheme() {
        XCTAssertEqual(Intake.extractURLs(from: "youtube.com/watch?v=x"),
                       ["https://youtube.com/watch?v=x"])
    }

    func testPlainTextYieldsNothing() {
        XCTAssertTrue(Intake.extractURLs(from: "just some words. e.g nothing here").isEmpty)
        XCTAssertTrue(Intake.extractURLs(from: "").isEmpty)
    }
}
