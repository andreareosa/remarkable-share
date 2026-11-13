import XCTest
@testable import RemarkableShareCore

final class RemoteCommandsTests: XCTestCase {
    func testStartUSBBindsToCableAddressOverHTTP() throws {
        let cmd = try RemoteCommands.start(mode: .usb, password: "abcDEF123456xyz")
        XCTAssertTrue(cmd.contains("RK_SERVER_BIND_ADDR='10.11.99.1:2001'"))
        XCTAssertTrue(cmd.contains("RK_HTTPS='false'"))
        XCTAssertTrue(cmd.contains("RK_SERVER_PASSWORD='abcDEF123456xyz'"))
        XCTAssertTrue(cmd.hasSuffix("&"), "server must be detached")
    }

    func testStartWifiBindsAllInterfacesOverHTTPS() throws {
        let cmd = try RemoteCommands.start(mode: .wifi, password: "abcDEF123456xyz")
        XCTAssertTrue(cmd.contains("RK_SERVER_BIND_ADDR=':2001'"))
        XCTAssertTrue(cmd.contains("RK_HTTPS='true'"))
    }

    func testStartRejectsShellMetacharacters() {
        for bad in ["short1", "abcdefghijkl'; rm -rf /", "abcdefghijkl$(x)", "abcdefghijklé", ""] {
            XCTAssertThrowsError(try RemoteCommands.start(mode: .usb, password: bad), bad)
        }
    }

    func testAuthorizeKeyIsIdempotent() {
        let cmd = RemoteCommands.authorizeKey(publicKey: "ssh-ed25519 AAAAC3Nz test@mac\n")
        XCTAssertTrue(cmd.contains("grep -qxF 'ssh-ed25519 AAAAC3Nz test@mac'"))
        XCTAssertFalse(cmd.contains("\n'"), "trailing newline must be trimmed")
    }
}

final class PasswordPolicyTests: XCTestCase {
    func testGeneratedPasswordsAreSafeAndUnique() {
        let a = PasswordPolicy.generate(), b = PasswordPolicy.generate()
        XCTAssertTrue(PasswordPolicy.isSafe(a))
        XCTAssertEqual(a.count, PasswordPolicy.length)
        XCTAssertNotEqual(a, b)
    }

    func testLegacyPasswordStillAccepted() {
        XCTAssertTrue(PasswordPolicy.isSafe("xVmxbKMckiXU"))
    }
}

final class StreamModeTests: XCTestCase {
    func testURLs() {
        XCTAssertEqual(StreamMode.usb.url(host: "10.11.99.1").absoluteString, "http://10.11.99.1:2001/")
        XCTAssertEqual(StreamMode.wifi.url(host: "192.168.0.117").absoluteString, "https://192.168.0.117:2001/")
    }
}

final class SecurityTests: XCTestCase {
    func testSHA256() {
        XCTAssertEqual(Checksum.sha256Hex(Data("abc".utf8)),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertTrue(Checksum.matches(Data("abc".utf8),
                                       expectedHex: "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"))
        XCTAssertFalse(Checksum.matches(Data("abd".utf8), expectedHex: TabletConfig.streamSHA256))
    }

    func testPEMDecoding() {
        let pem = "junk\n-----BEGIN CERTIFICATE-----\nAAEC\nAwQ=\n-----END CERTIFICATE-----\n"
        XCTAssertEqual(PEM.firstCertificateDER(pem), Data([0, 1, 2, 3, 4]))
        XCTAssertNil(PEM.firstCertificateDER("no cert here"))
    }
}

final class AuthSeedTests: XCTestCase {
    func testUserScriptEscapesToken() {
        let js = AuthSeed.userScript(token: "a\"b</script>\\c", expiresIn: 3600)
        XCTAssertTrue(js.contains("\"goMarkableStream_jwt\""))
        XCTAssertFalse(js.contains("</script>"))
        XCTAssertTrue(js.contains("3600 * 1000"))
    }

    func testLoginBodyIsJSON() throws {
        let body = AuthSeed.loginBody(username: "admin", password: "p\"w")
        let obj = try JSONSerialization.jsonObject(with: body) as? [String: String]
        XCTAssertEqual(obj?["password"], "p\"w")
        XCTAssertEqual(obj?["username"], "admin")
    }

    func testDecodesLoginResponse() throws {
        let r = try JSONDecoder().decode(AuthSeed.LoginResponse.self,
                                         from: Data(#"{"token":"t","expiresIn":86400}"#.utf8))
        XCTAssertEqual(r, .init(token: "t", expiresIn: 86400))
    }
}

final class URLActionTests: XCTestCase {
    func testParsesActions() {
        XCTAssertEqual(URLAction(URL(string: "remarkable-share://share/usb")!), .share(.usb))
        XCTAssertEqual(URLAction(URL(string: "remarkable-share://share/wifi")!), .share(.wifi))
        XCTAssertEqual(URLAction(URL(string: "remarkable-share://share")!), .share(.usb))
        XCTAssertEqual(URLAction(URL(string: "REMARKABLE-SHARE://Stop")!), .stop)
        XCTAssertNil(URLAction(URL(string: "remarkable-share://format-tablet")!))
        XCTAssertNil(URLAction(URL(string: "https://share/usb")!))
    }
}

final class SSHArgumentsTests: XCTestCase {
    func testKeyAuthNeverPrompts() {
        let args = SSHArguments.keyAuth(command: "true")
        XCTAssertTrue(args.contains("BatchMode=yes"))
        XCTAssertEqual(args.suffix(2), ["root@10.11.99.1", "true"])
    }
}
