import Foundation
import RemarkableShareCore
import Security

/// Trusts exactly one certificate: the tablet's self-signed one, fetched over SSH.
/// Used both by URLSession (login/health) and by the WKWebView viewer.
struct PinnedTrust: Sendable {
    let certificateSHA256: String?

    func evaluate(_ challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        guard let pinned = certificateSHA256,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else {
            return (.cancelAuthenticationChallenge, nil)
        }
        let der = SecCertificateCopyData(leaf) as Data
        return Checksum.matches(der, expectedHex: pinned)
            ? (.useCredential, URLCredential(trust: trust))
            : (.cancelAuthenticationChallenge, nil)
    }
}

private final class PinnedSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    let trust: PinnedTrust
    init(trust: PinnedTrust) { self.trust = trust }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = trust.evaluate(challenge)
        completionHandler(disposition, credential)
    }
}

enum StreamClientError: LocalizedError {
    case loginFailed(Int)
    var errorDescription: String? {
        switch self { case .loginFailed(let code): return "Stream login failed (HTTP \(code))." }
    }
}

struct StreamClient {
    let baseURL: URL
    let trust: PinnedTrust

    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        return URLSession(configuration: config, delegate: PinnedSessionDelegate(trust: trust), delegateQueue: nil)
    }

    func isUp() async -> Bool {
        let s = session()
        defer { s.finishTasksAndInvalidate() }
        guard let (_, response) = try? await s.data(from: baseURL) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    func login(password: String) async throws -> AuthSeed.LoginResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = AuthSeed.loginBody(username: TabletConfig.streamUsername, password: password)
        let s = session()
        defer { s.finishTasksAndInvalidate() }
        let (data, response) = try await s.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else { throw StreamClientError.loginFailed(code) }
        return try JSONDecoder().decode(AuthSeed.LoginResponse.self, from: data)
    }
}
