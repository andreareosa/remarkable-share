import Foundation

struct ProcessResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String
    var ok: Bool { status == 0 }
}

enum ProcessRunner {
    /// Runs an executable directly (no shell) with an optional stdin payload and a hard timeout.
    static func run(
        _ executable: String,
        _ arguments: [String],
        stdin: Data? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 20
    ) async -> ProcessResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                if let environment {
                    process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
                }
                let out = Pipe(), err = Pipe(), input = Pipe()
                process.standardOutput = out
                process.standardError = err
                process.standardInput = input

                // Drain pipes concurrently so large outputs can't deadlock the child.
                var outData = Data(), errData = Data()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
                group.enter()
                DispatchQueue.global().async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ProcessResult(status: -1, stdout: "", stderr: error.localizedDescription))
                    return
                }

                let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)

                DispatchQueue.global().async {
                    if let stdin { try? input.fileHandleForWriting.write(contentsOf: stdin) }
                    try? input.fileHandleForWriting.close()
                }

                process.waitUntilExit()
                watchdog.cancel()
                group.wait()
                continuation.resume(returning: ProcessResult(
                    status: process.terminationStatus,
                    stdout: String(decoding: outData, as: UTF8.self),
                    stderr: String(decoding: errData, as: UTF8.self)
                ))
            }
        }
    }
}
