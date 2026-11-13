import Foundation
import Observation
import RemarkableShareCore

/// What the viewer needs to show a live stream.
struct LiveStream: Equatable {
    let mode: StreamMode
    let url: URL
    let token: String
    let expiresIn: Int
    let certificateSHA256: String?

    var trust: PinnedTrust { PinnedTrust(certificateSHA256: certificateSHA256) }
    static func == (a: LiveStream, b: LiveStream) -> Bool { a.url == b.url && a.token == b.token }
}

enum TabletState: Equatable {
    case checking
    case noCable
    case needsSetup
    case ready
    case working(String)
    case streaming(LiveStream)
    case failed(String)

    var isBusy: Bool { if case .working = self { return true } else { return false } }
    var stream: LiveStream? { if case .streaming(let s) = self { return s } else { return nil } }
}

@MainActor
@Observable
final class TabletController {
    private(set) var state: TabletState = .checking
    private var pollTask: Task<Void, Never>?

    struct WindowRequest: Equatable { let id: String; let nonce = UUID() }
    /// Set to ask the UI to open a window from outside SwiftUI (e.g. a URL-scheme action).
    private(set) var windowRequest: WindowRequest?
    func requestWindow(_ id: String) { windowRequest = WindowRequest(id: id) }

    init() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    var statusText: String {
        switch state {
        case .checking: return "Looking for your tablet…"
        case .noCable: return "Plug in the tablet's USB cable"
        case .needsSetup: return "One-time setup needed"
        case .ready: return "Tablet connected — ready to share"
        case .working(let message): return message
        case .streaming(let s): return s.mode == .usb ? "Sharing over USB" : "Sharing over Wi-Fi"
        case .failed(let message): return message
        }
    }

    /// Background status check; never interrupts an action in progress.
    func refresh() async {
        switch state {
        case .working: return
        case .streaming(let s):
            if s.mode == .wifi {
                if await !StreamClient(baseURL: s.url, trust: s.trust).isUp() { state = .failed("Wi-Fi stream stopped") }
            } else if await !TabletSSH.isReachable() {
                state = .noCable
            }
            return
        case .failed:
            // Keep the error visible until the user acts, unless the cable situation changed.
            if await !TabletSSH.isReachable() { state = .noCable }
            return
        default: break
        }
        guard await TabletSSH.isReachable() else { state = .noCable; return }
        if case .working = state { return }
        state = await TabletSSH.keyWorks() ? .ready : .needsSetup
    }

    func start(_ mode: StreamMode) async {
        guard !state.isBusy else { return }
        do {
            state = .working("Connecting to tablet…")
            guard await TabletSSH.isReachable() else { state = .noCable; return }
            guard await TabletSSH.keyWorks() else {
                state = .needsSetup
                requestWindow("setup")
                return
            }

            if try await !StreamInstaller.isInstalled() {
                state = .working("Installing streaming tool on tablet…")
                try await StreamInstaller.install()
            }

            let password = Keychain.ensureStreamPassword()
            var host = TabletConfig.usbHost
            if mode == .wifi {
                host = try await TabletSSH.run(RemoteCommands.wifiIP)
                guard !host.isEmpty else {
                    state = .failed("Tablet isn't on Wi-Fi — connect it, or share over USB")
                    return
                }
            }

            state = .working("Starting stream…")
            try await TabletSSH.run(RemoteCommands.stop, timeout: 15)
            try await TabletSSH.run(try RemoteCommands.start(mode: mode, password: password))

            let url = mode.url(host: host)
            var pin: String?
            var client = StreamClient(baseURL: url, trust: PinnedTrust(certificateSHA256: nil))
            for _ in 0..<20 {
                if mode.usesHTTPS, pin == nil,
                   let der = PEM.firstCertificateDER(try await TabletSSH.run(RemoteCommands.readCert)) {
                    pin = Checksum.sha256Hex(der)
                    client = StreamClient(baseURL: url, trust: PinnedTrust(certificateSHA256: pin))
                }
                if await client.isUp() { break }
                try await Task.sleep(for: .milliseconds(750))
            }
            guard await client.isUp() else {
                state = .failed("Stream didn't start on the tablet")
                return
            }
            let auth = try await client.login(password: password)
            state = .streaming(LiveStream(mode: mode, url: url, token: auth.token,
                                          expiresIn: auth.expiresIn, certificateSHA256: pin))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard state.stream != nil || {
            if case .failed = state { return true } else { return false }
        }() else { return }
        state = .working("Stopping…")
        if await TabletSSH.isReachable() {
            _ = try? await TabletSSH.run(RemoteCommands.stop, timeout: 15)
            state = .ready
        } else {
            state = .noCable
        }
    }

    func completeSetup(rootPassword: String) async throws {
        state = .working("Setting up secure connection…")
        do {
            try await TabletSSH.installKey(rootPassword: rootPassword)
            _ = Keychain.ensureStreamPassword()
            state = .ready
        } catch {
            state = .needsSetup
            throw error
        }
    }

    func dismissError() { if case .failed = state { state = .checking; Task { await refresh() } } }

    /// Best-effort cleanup on quit so the tablet isn't left streaming.
    func shutdown() async {
        pollTask?.cancel()
        if state.stream != nil, await TabletSSH.isReachable() {
            _ = try? await TabletSSH.run(RemoteCommands.stop, timeout: 8)
        }
    }

    func uninstallFromTablet() async {
        state = .working("Removing streaming tool from tablet…")
        _ = try? await TabletSSH.run(RemoteCommands.stop, timeout: 15)
        _ = try? await TabletSSH.run(RemoteCommands.uninstall)
        state = .ready
    }
}
