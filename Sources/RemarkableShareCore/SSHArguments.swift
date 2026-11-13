import Foundation

/// Builds argument vectors for /usr/bin/ssh. No shell is involved on the Mac side:
/// arguments go straight to `Process`, so nothing here is subject to local shell injection.
public enum SSHArguments {
    public static func common(host: String = TabletConfig.usbHost, connectTimeout: Int = 5) -> [String] {
        [
            "-o", "UserKnownHostsFile=\(TabletConfig.knownHostsPath)",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=\(connectTimeout)",
            "-o", "ServerAliveInterval=5",
            "-o", "LogLevel=ERROR",
        ]
    }

    /// Key-based, never prompts.
    public static func keyAuth(command: String, host: String = TabletConfig.usbHost) -> [String] {
        ["-i", TabletConfig.sshKeyPath, "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes"]
            + common(host: host)
            + ["\(TabletConfig.sshUser)@\(host)", command]
    }

    /// Password-based (first-time setup). The password is supplied through SSH_ASKPASS.
    public static func passwordAuth(command: String, host: String = TabletConfig.usbHost) -> [String] {
        ["-o", "PubkeyAuthentication=no", "-o", "PreferredAuthentications=password,keyboard-interactive",
         "-o", "NumberOfPasswordPrompts=1"]
            + common(host: host)
            + ["\(TabletConfig.sshUser)@\(host)", command]
    }
}
