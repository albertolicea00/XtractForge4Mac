import Foundation

/// A spawned child process with a merged stdout+stderr line stream.
public final class RunningProcess: @unchecked Sendable {
    public let process: Process
    /// Merged stdout + stderr, line by line (handles \n and bare \r progress lines).
    public let lines: AsyncStream<String>

    init(process: Process, lines: AsyncStream<String>) {
        self.process = process
        self.lines = lines
    }

    public var isRunning: Bool { process.isRunning }
    public var exitCode: Int32 { process.terminationStatus }

    /// SIGSTOP the process (pause).
    @discardableResult
    public func suspend() -> Bool { process.suspend() }

    /// SIGCONT the process (resume).
    @discardableResult
    public func resume() -> Bool { process.resume() }

    /// SIGTERM, escalating to SIGKILL after a grace period.
    public func terminate(killAfter seconds: TimeInterval = 5) {
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { [weak process] in
            if let process, process.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }

    public func waitUntilExit() async -> Int32 {
        await withCheckedContinuation { continuation in
            if !process.isRunning && process.processIdentifier != 0 {
                continuation.resume(returning: process.terminationStatus)
                return
            }
            process.terminationHandler = { p in
                continuation.resume(returning: p.terminationStatus)
            }
        }
    }
}

public enum ProcessRunner {
    /// Directories searched when the binary is a bare name and not on the
    /// inherited PATH (GUI apps don't get the shell's PATH).
    static let fallbackDirs = [
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        NSHomeDirectory() + "/.local/bin",
    ]

    /// Resolve a binary name/path to an executable absolute path if possible.
    public static func resolveBinary(_ binary: String) -> String {
        let fm = FileManager.default
        if binary.contains("/") {
            return (binary as NSString).expandingTildeInPath
        }
        var dirs = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
        dirs.append(contentsOf: fallbackDirs)
        for dir in dirs {
            let candidate = dir + "/" + binary
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return binary
    }

    /// Spawn a long-running command, streaming merged stdout+stderr lines.
    public static func run(_ command: Command, currentDirectory: URL? = nil) throws -> RunningProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolveBinary(command.binary))
        process.arguments = command.args
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        let lines = AsyncStream<String> { continuation in
            let group = DispatchGroup()
            for pipe in [outPipe, errPipe] {
                group.enter()
                DispatchQueue.global().async {
                    let handle = pipe.fileHandleForReading
                    var buffer = Data()
                    while true {
                        let chunk = handle.availableData
                        if chunk.isEmpty { break }
                        buffer.append(chunk)
                        // Split on \n and \r (yt-dlp/curl redraw progress with bare \r).
                        while let idx = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
                            let lineData = buffer[buffer.startIndex..<idx]
                            buffer.removeSubrange(buffer.startIndex...idx)
                            if let line = String(data: lineData, encoding: .utf8),
                               !line.isEmpty {
                                continuation.yield(line)
                            }
                        }
                    }
                    if let rest = String(data: buffer, encoding: .utf8), !rest.isEmpty {
                        continuation.yield(rest)
                    }
                    group.leave()
                }
            }
            group.notify(queue: .global()) {
                continuation.finish()
            }
        }

        try process.run()
        return RunningProcess(process: process, lines: lines)
    }

    public struct CaptureResult: Sendable {
        public let exitCode: Int32
        public let stdout: String
        public let stderr: String
        public var success: Bool { exitCode == 0 }
    }

    /// Run a short command to completion and capture its output (for
    /// `checkDependency` / `getInfo`).
    public static func capture(_ binary: String, _ args: [String]) async throws -> CaptureResult {
        let resolved = resolveBinary(binary)
        guard FileManager.default.isExecutableFile(atPath: resolved) else {
            throw DownloadError.binaryNotFound(binary)
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: resolved)
                process.arguments = args
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                process.standardInput = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                // Read fully before waiting to avoid pipe-buffer deadlock.
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: CaptureResult(
                    exitCode: process.terminationStatus,
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: String(data: errData, encoding: .utf8) ?? ""
                ))
            }
        }
    }
}
