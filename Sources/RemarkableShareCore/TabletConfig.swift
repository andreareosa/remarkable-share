import Foundation

/// Static facts about the tablet and the pinned goMarkableStream release.
public enum TabletConfig {
    /// The reMarkable always exposes itself at this address over the USB cable.
    public static let usbHost = "10.11.99.1"
    public static let port = 2001
    public static let sshUser = "root"

    public static let remoteBinary = "/home/root/goMarkableStream"
    public static let remoteLog = "/home/root/gms.log"
    public static let remoteCert = "/home/root/.config/goMarkableStream/certs/server.crt"

    /// Pinned release. `lite` = no Tailscale (smaller, nothing listens beyond what we bind).
    public static let streamVersion = "v1.4.0"
    public static let streamAsset = "gomarkablestream-RM2-lite"
    public static let streamSHA256 = "35b3f17ee96995344954fb754fd108f1c10a68580291c3dcb3f8c4998f1aba5b"

    public static var streamDownloadURL: URL {
        URL(string: "https://github.com/owulveryck/goMarkableStream/releases/download/\(streamVersion)/\(streamAsset)")!
    }

    public static let streamUsername = "admin"
    public static let keychainService = "remarkable-share"
    public static let keychainAccount = "admin"

    public static var sshKeyPath: String { NSHomeDirectory() + "/.ssh/remarkable_ed25519" }
    public static var knownHostsPath: String { NSHomeDirectory() + "/.ssh/known_hosts_remarkable" }
}

/// How the stream is exposed on the tablet.
public enum StreamMode: String, CaseIterable, Sendable {
    /// Bound to the USB address only; plain HTTP over the cable (a point-to-point link).
    case usb
    /// Bound to all interfaces so the Mac can view it over Wi-Fi; HTTPS with a pinned certificate.
    case wifi

    public var usesHTTPS: Bool { self == .wifi }

    public func bindAddress() -> String {
        switch self {
        case .usb: return "\(TabletConfig.usbHost):\(TabletConfig.port)"
        case .wifi: return ":\(TabletConfig.port)"
        }
    }

    public func url(host: String) -> URL {
        let scheme = usesHTTPS ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(TabletConfig.port)/")!
    }
}
