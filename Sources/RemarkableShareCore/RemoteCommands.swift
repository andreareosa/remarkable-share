import Foundation

public enum RemoteCommandError: Error, Equatable {
    case unsafePassword
}

/// Shell snippets executed on the tablet (BusyBox sh) over SSH.
public enum RemoteCommands {
    /// Prints PIDs of the running stream server (empty if none). `pidof` matches the
    /// process name, so it never matches the ssh shell running this command.
    public static let pid = "pidof goMarkableStream || true"

    public static let isInstalled = "test -x \(TabletConfig.remoteBinary) && echo yes || echo no"

    /// SIGTERM, then SIGKILL: the server lingers on SIGTERM while a viewer is connected.
    public static let stop = """
    p=$(pidof goMarkableStream) || exit 0
    kill $p 2>/dev/null
    for i in 1 2 3; do sleep 1; pidof goMarkableStream >/dev/null || exit 0; done
    kill -9 $(pidof goMarkableStream) 2>/dev/null; sleep 1; true
    """

    public static let wifiIP =
        "ip -4 -o addr show wlan0 2>/dev/null | awk '{print $4}' | cut -d/ -f1"

    public static let readCert = "cat \(TabletConfig.remoteCert) 2>/dev/null || true"

    /// Reads the binary from stdin, then atomically replaces the installed one.
    public static let upload = """
    cat > \(TabletConfig.remoteBinary).new && chmod +x \(TabletConfig.remoteBinary).new \
    && mv \(TabletConfig.remoteBinary).new \(TabletConfig.remoteBinary)
    """

    public static let uninstall = "rm -f \(TabletConfig.remoteBinary) \(TabletConfig.remoteLog)"

    public static func authorizeKey(publicKey: String) -> String {
        let key = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys \
        && (grep -qxF '\(key)' ~/.ssh/authorized_keys || echo '\(key)' >> ~/.ssh/authorized_keys) \
        && chmod 600 ~/.ssh/authorized_keys
        """
    }

    /// Starts the server detached. The password is interpolated into a shell command, so
    /// only passwords from `PasswordPolicy` (alphanumeric) are accepted.
    public static func start(mode: StreamMode, password: String) throws -> String {
        guard PasswordPolicy.isSafe(password) else { throw RemoteCommandError.unsafePassword }
        return "RK_SERVER_BIND_ADDR='\(mode.bindAddress())' "
            + "RK_SERVER_USERNAME='\(TabletConfig.streamUsername)' "
            + "RK_SERVER_PASSWORD='\(password)' "
            + "RK_HTTPS='\(mode.usesHTTPS ? "true" : "false")' "
            + "nohup \(TabletConfig.remoteBinary) > \(TabletConfig.remoteLog) 2>&1 </dev/null &"
    }
}

public enum PasswordPolicy {
    public static let length = 20

    public static func isSafe(_ password: String) -> Bool {
        password.count >= 12 && password.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    public static func generate() -> String {
        let alphabet = Array("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in alphabet.randomElement(using: &rng)! })
    }
}
