import Foundation

/// Actions reachable via the `remarkable-share://` URL scheme (Shortcuts, Raycast, scripts).
public enum URLAction: Equatable, Sendable {
    case share(StreamMode)
    case stop

    public static let scheme = "remarkable-share"

    public init?(_ url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        let parts = ([url.host ?? ""] + url.pathComponents.filter { $0 != "/" }).map { $0.lowercased() }
        switch parts.first {
        case "share":
            let mode = parts.dropFirst().first.flatMap(StreamMode.init(rawValue:)) ?? .usb
            self = .share(mode)
        case "stop":
            self = .stop
        default:
            return nil
        }
    }
}
