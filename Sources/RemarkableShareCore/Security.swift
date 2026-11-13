import CryptoKit
import Foundation

public enum Checksum {
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func matches(_ data: Data, expectedHex: String) -> Bool {
        sha256Hex(data) == expectedHex.lowercased()
    }
}

public enum PEM {
    /// Decodes the first certificate in a PEM blob to DER bytes.
    public static func firstCertificateDER(_ pem: String) -> Data? {
        let begin = "-----BEGIN CERTIFICATE-----"
        let end = "-----END CERTIFICATE-----"
        guard let start = pem.range(of: begin),
              let stop = pem.range(of: end, range: start.upperBound..<pem.endIndex) else { return nil }
        let body = pem[start.upperBound..<stop.lowerBound]
            .components(separatedBy: .whitespacesAndNewlines).joined()
        return Data(base64Encoded: body)
    }
}

/// goMarkableStream's web client keeps its JWT in localStorage. The app logs in natively
/// and seeds these keys before the page scripts run, so the user never sees a login form.
public enum AuthSeed {
    public static let tokenKey = "goMarkableStream_jwt"
    public static let expiryKey = "goMarkableStream_jwt_expiry"

    public struct LoginResponse: Decodable, Equatable {
        public let token: String
        public let expiresIn: Int
    }

    public static func loginBody(username: String, password: String) -> Data {
        // JSONSerialization handles all escaping.
        (try? JSONSerialization.data(withJSONObject: ["username": username, "password": password])) ?? Data()
    }

    /// JavaScript injected at document start. Mirrors auth.js: expiry stored 5 minutes early.
    public static func userScript(token: String, expiresIn: Int) -> String {
        let tokenLiteral = jsStringLiteral(token)
        return """
        (function () {
          try {
            localStorage.setItem(\(jsStringLiteral(tokenKey)), \(tokenLiteral));
            localStorage.setItem(\(jsStringLiteral(expiryKey)),
              String(Date.now() + \(expiresIn) * 1000 - 5 * 60 * 1000));
          } catch (e) {}
        })();
        """
    }

    /// Encodes a Swift string as a JSON (and therefore JS) string literal.
    static func jsStringLiteral(_ value: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [value], options: [.fragmentsAllowed])) ?? Data("[\"\"]".utf8)
        let array = String(decoding: data, as: UTF8.self)
        // "[\"...\"]" -> "\"...\""
        return String(array.dropFirst().dropLast())
            .replacingOccurrences(of: "</", with: "<\\/")
    }
}
