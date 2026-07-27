import SwiftUI

/// Decides which of the app's three states you're in, and hosts the one overlay that
/// can appear over any of them: the completion fanfare.
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch session.phase {
            case .starting:
                SplashView()
            case .unpaired:
                PairingView()
                    .transition(.opacity)
            case .ready:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.phase)
        .celebrationHost()
        .task { await session.start() }
        .task(id: session.phase) {
            guard session.phase == .ready else { return }
            await session.refreshListMembership()
            await session.loadRequestConfig()
            await session.checkCelebrations()
            await SyncCoordinator.shared.replayPending(session: session)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, session.phase == .ready else { return }
            // Plex may have finished a season for you while you were away.
            Task {
                await session.checkCelebrations()
                await SyncCoordinator.shared.replayPending(session: session)
            }
        }
    }
}

/// A held beat on the wordmark while the Keychain is read. Deliberately quiet — this
/// is on screen for a frame or two.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.mqGround.ignoresSafeArea()
            Text("Marquee")
                .font(MarqueeFont.wordmark(34, relativeTo: .largeTitle))
                .foregroundStyle(Color.mqBrass)
                .tracking(2)
        }
        .accessibilityLabel("Marquee, starting")
    }
}
