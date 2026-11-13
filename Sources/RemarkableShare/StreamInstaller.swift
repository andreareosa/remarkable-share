import Foundation
import RemarkableShareCore

enum StreamInstallerError: LocalizedError {
    case download(String)
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .download(let detail): return "Couldn't download goMarkableStream: \(detail)"
        case .checksumMismatch: return "Downloaded file failed its checksum — not installing it."
        }
    }
}

/// Puts the pinned, checksum-verified goMarkableStream build on the tablet when it's missing
/// (first run, factory reset). The binary lives in /home, which survives firmware updates.
enum StreamInstaller {
    static func isInstalled() async throws -> Bool {
        try await TabletSSH.run(RemoteCommands.isInstalled) == "yes"
    }

    static func install() async throws {
        let data: Data
        do {
            let (body, response) = try await URLSession.shared.data(from: TabletConfig.streamDownloadURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw StreamInstallerError.download("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            data = body
        } catch let error as StreamInstallerError {
            throw error
        } catch {
            throw StreamInstallerError.download(error.localizedDescription)
        }
        guard Checksum.matches(data, expectedHex: TabletConfig.streamSHA256) else {
            throw StreamInstallerError.checksumMismatch
        }
        try await TabletSSH.run(RemoteCommands.upload, stdin: data, timeout: 120)
    }
}
