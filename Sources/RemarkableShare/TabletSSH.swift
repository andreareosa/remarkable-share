import Foundation
import RemarkableShareCore

enum TabletSSHError: LocalizedError {
    case commandFailed(String)
    case wrongRootPassword
    case keygenFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let detail): return "Tablet command failed: \(detail)"
        case .wrongRootPassword: return "The tablet rejected that root password."
        case .keygenFailed(let detail): return "Couldn't create the SSH key: \(detail)"
        }
    }
}

/// All communication with the tablet goes through the system ssh client over the USB link.
enum TabletSSH {
    static let ssh = "/usr/bin/ssh"

    @discardableResult
    static func run(_ command: String, stdin: Data? = nil, timeout: TimeInterval = 20) async throws -> String {
        let result = await ProcessRunner.run(ssh, SSHArguments.keyAuth(command: command), stdin: stdin, timeout: timeout)
        guard result.ok else {
            throw TabletSSHError.commandFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isReachable() async -> Bool {
        await ProcessRunner.run("/sbin/ping", ["-c", "1", "-t", "1", TabletConfig.usbHost], timeout: 3).ok
    }

    static func keyWorks() async -> Bool {
        guard FileManager.default.fileExists(atPath: TabletConfig.sshKeyPath) else { return false }
        return await ProcessRunner.run(ssh, SSHArguments.keyAuth(command: "true"), timeout: 10).ok
    }

    /// One-time: create a dedicated key and authorize it on the tablet using the root password.
    static func installKey(rootPassword: String) async throws {
        let keyPath = TabletConfig.sshKeyPath
        let sshDir = (keyPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: sshDir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        if !FileManager.default.fileExists(atPath: keyPath) {
            let gen = await ProcessRunner.run("/usr/bin/ssh-keygen",
                                              ["-q", "-t", "ed25519", "-N", "", "-C", "remarkable-share", "-f", keyPath])
            guard gen.ok else { throw TabletSSHError.keygenFailed(gen.stderr) }
        }
        let publicKey = try String(contentsOfFile: keyPath + ".pub", encoding: .utf8)

        // SSH_ASKPASS helper reads the password from the environment, so it never touches disk.
        let askpass = FileManager.default.temporaryDirectory.appendingPathComponent("rms-askpass-\(UUID().uuidString)")
        try "#!/bin/sh\nprintf '%s\\n' \"$RMS_ROOT_PASSWORD\"\n".write(to: askpass, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: askpass.path)
        defer { try? FileManager.default.removeItem(at: askpass) }

        let result = await ProcessRunner.run(
            ssh,
            SSHArguments.passwordAuth(command: RemoteCommands.authorizeKey(publicKey: publicKey)),
            environment: [
                "SSH_ASKPASS": askpass.path,
                "SSH_ASKPASS_REQUIRE": "force",
                "DISPLAY": "remarkable-share",
                "RMS_ROOT_PASSWORD": rootPassword,
            ],
            timeout: 20
        )
        guard result.ok else {
            if result.stderr.localizedCaseInsensitiveContains("denied") { throw TabletSSHError.wrongRootPassword }
            throw TabletSSHError.commandFailed(result.stderr)
        }
        guard await keyWorks() else { throw TabletSSHError.commandFailed("key was installed but login still fails") }
    }
}
