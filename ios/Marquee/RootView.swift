import SwiftUI

/// Decides which of the app's three states you're in, and hosts the one overlay that
/// can appear over any of them: the completion fanfare.
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    /// This year's Year in Review, presented by itself once after it premieres.
    @State private var premiere: RecapPremiere?

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
        .fullScreenCover(item: $premiere) { premiere in
            NavigationStack { RecapScreen(year: premiere.year, presentedModally: true) }
        }
        .celebrationHost()
        .observesHinge()
        .curtainUpOnUnfold()
        .task { await session.start() }
        .task(id: session.phase) {
            guard session.phase == .ready else { return }
            await session.refreshListMembership()
            await session.loadRequestConfig()
            await session.checkCelebrations()
            await SyncCoordinator.shared.replayPending(session: session)
            await checkPremiere()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, session.phase == .ready else { return }
            // Plex may have finished a season for you while you were away.
            Task {
                await session.checkCelebrations()
                await SyncCoordinator.shared.replayPending(session: session)
                await checkPremiere()
            }
        }
    }
}

extension RootView {
    /// The server says which recap (if any) is still unseen and fresh — from release
    /// day to the end of January. Opening it marks it seen, so it shows once across
    /// every device: whichever one you open first.
    fileprivate func checkPremiere() async {
        guard premiere == nil, session.phase == .ready, let client = session.client,
              let index: RecapIndex = try? await client.get("recap"), let year = index.autoshow
        else { return }
        // let the app settle (and any finish-line fanfare play) before the curtain goes up
        try? await Task.sleep(for: .seconds(1.2))
        guard premiere == nil, session.phase == .ready else { return }
        premiere = RecapPremiere(year: year)
    }
}

struct RecapPremiere: Identifiable, Equatable {
    let year: Int
    var id: Int { year }
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
