import SwiftUI
import WebKit

struct LogicGateWebPanel: UIViewRepresentable {
    let urlString: String
    /// Fired once the page actually commits, so the splash can be held until
    /// there are pixels. Settings/Privacy passes nothing and is unaffected.
    var onFirstPaint: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        private var fired = false
        // didCommit, not didFinish — didFinish lands seconds after the page is usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { fire() }
        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            fire()
        }
        private func fire() { guard !fired else { return }; fired = true; onFirstPaint?() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.overrideUserInterfaceStyle = .light
        context.coordinator.onFirstPaint = onFirstPaint
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Still never reload here — only refresh the callback reference.
        context.coordinator.onFirstPaint = onFirstPaint
    }
}
