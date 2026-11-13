import RemarkableShareCore
import SwiftUI
import WebKit

/// Embeds goMarkableStream's web client. Logged in automatically (JWT seeded before page
/// scripts run) and, in Wi-Fi mode, trusting only the tablet's pinned certificate.
struct StreamWebView: NSViewRepresentable {
    let stream: LiveStream
    let reloadToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(trust: stream.trust) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Fresh, non-persistent storage: nothing from the stream lingers on disk.
        config.websiteDataStore = .nonPersistent()
        config.userContentController.addUserScript(WKUserScript(
            source: AuthSeed.userScript(token: stream.token, expiresIn: stream.expiresIn),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.lastReload = reloadToken
        webView.load(URLRequest(url: stream.url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.trust = stream.trust
        if context.coordinator.lastReload != reloadToken {
            context.coordinator.lastReload = reloadToken
            webView.reload()
        }
        if webView.url?.host != stream.url.host || webView.url?.scheme != stream.url.scheme {
            webView.load(URLRequest(url: stream.url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var trust: PinnedTrust
        var lastReload = 0
        init(trust: PinnedTrust) { self.trust = trust }

        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            let (disposition, credential) = trust.evaluate(challenge)
            completionHandler(disposition, credential)
        }

        // Keep the viewer on the tablet; anything else (e.g. project links) opens in the browser.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { return decisionHandler(.cancel) }
            if url.host == webView.url?.host || webView.url == nil || url.scheme == "about" || url.scheme == "blob" {
                decisionHandler(.allow)
            } else {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}
