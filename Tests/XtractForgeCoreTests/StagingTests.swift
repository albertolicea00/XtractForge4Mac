import XCTest
@testable import XtractForgeCore

final class StagingTests: XCTestCase {
    var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("xf-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testUrlHashIsStableAndShort() {
        let a = Staging.urlHash("https://youtu.be/x")
        let b = Staging.urlHash("https://youtu.be/x")
        let c = Staging.urlHash("https://youtu.be/y")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(a.count, 16)
    }

    func testStagingDirLayout() {
        let dir = Staging.stagingDir(for: "https://youtu.be/x", downloadFolder: "/Users/x/Downloads")
        XCTAssertEqual(dir.deletingLastPathComponent().lastPathComponent, ".xtractforge-tmp")
        XCTAssertEqual(dir.deletingLastPathComponent().deletingLastPathComponent().path,
                       "/Users/x/Downloads")
    }

    func testCategories() {
        XCTAssertEqual(Staging.category(forExtension: "mp4"), "Video")
        XCTAssertEqual(Staging.category(forExtension: "MP3"), "Audio")
        XCTAssertEqual(Staging.category(forExtension: "png"), "Images")
        XCTAssertEqual(Staging.category(forExtension: "zip"), "Files")
        XCTAssertEqual(Staging.category(forExtension: ""), "Files")
    }

    func testFinalizeMovesFilesAndCleansUp() throws {
        let url = "https://example.com/v"
        let staging = Staging.stagingDir(for: url, downloadFolder: tempRoot.path)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data("video".utf8).write(to: staging.appendingPathComponent("movie.mp4"))

        let moved = try Staging.finalize(stagingDir: staging, finalFolder: tempRoot.path,
                                         organize: .none, source: "example.com")

        XCTAssertEqual(moved.map(\.lastPathComponent), ["movie.mp4"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("movie.mp4").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
        // Empty .xtractforge-tmp parent is removed too.
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempRoot.appendingPathComponent(Staging.tempDirName).path))
    }

    func testFinalizeOrganizesByType() throws {
        let staging = Staging.stagingDir(for: "u", downloadFolder: tempRoot.path)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data().write(to: staging.appendingPathComponent("a.mp4"))
        try Data().write(to: staging.appendingPathComponent("b.mp3"))

        let moved = try Staging.finalize(stagingDir: staging, finalFolder: tempRoot.path,
                                         organize: .type, source: "x")

        let folders = Set(moved.map { $0.deletingLastPathComponent().lastPathComponent })
        XCTAssertEqual(folders, ["Video", "Audio"])
    }

    func testFinalizeOrganizesBySource() throws {
        let staging = Staging.stagingDir(for: "u", downloadFolder: tempRoot.path)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data().write(to: staging.appendingPathComponent("a.mp4"))

        let moved = try Staging.finalize(stagingDir: staging, finalFolder: tempRoot.path,
                                         organize: .source, source: "youtube.com")
        XCTAssertEqual(moved.first?.deletingLastPathComponent().lastPathComponent, "youtube.com")
    }

    func testFinalizeNeverOverwrites() throws {
        let staging = Staging.stagingDir(for: "u", downloadFolder: tempRoot.path)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: staging.appendingPathComponent("movie.mp4"))
        try Data("old".utf8).write(to: tempRoot.appendingPathComponent("movie.mp4"))

        let moved = try Staging.finalize(stagingDir: staging, finalFolder: tempRoot.path,
                                         organize: .none, source: "x")

        XCTAssertEqual(moved.first?.lastPathComponent, "movie (2).mp4")
        let old = try String(contentsOf: tempRoot.appendingPathComponent("movie.mp4"), encoding: .utf8)
        XCTAssertEqual(old, "old")
    }
}
