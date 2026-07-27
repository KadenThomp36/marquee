import Foundation
import SwiftUI

/// One screen's worth of data, with the web client's caching behaviour carried over:
/// show the last good copy immediately, fetch in the background, and only redraw when
/// something actually changed — so back-navigation never flashes a skeleton.
///
/// It also satisfies the offline rule: a launch with no server shows the cached state
/// rather than a spinner or an error.
@MainActor
@Observable
public final class RemoteData<Value: Codable & Sendable & Equatable> {

    public private(set) var value: Value?
    public private(set) var error: String?
    public private(set) var isLoading = false
    /// True when what's on screen came from disk and the network hasn't answered yet.
    public private(set) var isStale = false
    public private(set) var cachedAt: Date?

    private let cacheKey: String?

    public init(cacheKey: String? = nil) {
        self.cacheKey = cacheKey
        if let cacheKey, let cached = OfflineStore.shared.cached(Value.self, for: cacheKey) {
            value = cached
            isStale = true
            cachedAt = OfflineStore.shared.cacheDate(for: cacheKey)
        }
    }

    /// Nothing to show and nothing tried yet — the only state that deserves a skeleton.
    public var isEmpty: Bool { value == nil && error == nil }

    public func load(force: Bool = false,
                     _ fetch: @Sendable () async throws -> Value) async {
        if isLoading { return }
        if !force, value != nil, !isStale { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await fetch()
            error = nil
            isStale = false
            cachedAt = Date()
            if fresh != value {
                value = fresh
            }
            if let cacheKey {
                OfflineStore.shared.cache(fresh, for: cacheKey)
            }
        } catch let failure as APIError {
            // Offline with something cached isn't an error state — it's yesterday's
            // paper, and the caller says so in a footer rather than a red banner.
            if value == nil { error = failure.errorDescription }
        } catch {
            if value == nil { self.error = error.localizedDescription }
        }
    }

    /// Patch what's on screen without a refetch — used after a punch, a rating, a
    /// list edit, so the card advances in place.
    public func mutate(_ change: (inout Value) -> Void) {
        guard var current = value else { return }
        change(&current)
        value = current
        if let cacheKey { OfflineStore.shared.cache(current, for: cacheKey) }
    }

    public func replace(_ new: Value) {
        value = new
        isStale = false
        if let cacheKey { OfflineStore.shared.cache(new, for: cacheKey) }
    }
}

// MARK: - Screen chrome

/// Every screen sits on the same ground and shares the same gutter.
struct MarqueeScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.mqGround.ignoresSafeArea()
            content
        }
    }
}

/// `SECTION ─────────── All ›` — the rule that separates one rail from the next.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var count: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, count: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.count = count
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).mqEyebrowStyle()
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Rectangle()
                .fill(Color.mqHairline)
                .frame(height: 1)
                .accessibilityHidden(true)
            if let count {
                Text(count)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .monospacedDigit()
            }
            trailing
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, count: String? = nil) {
        self.init(title, count: count) { EmptyView() }
    }
}

/// A rail title with a "See all" affordance — bigger than a section eyebrow, because
/// these head the content you actually came for.
struct RailHeader<Destination: View>: View {
    let title: String
    var moreLabel = "All"
    @ViewBuilder var destination: Destination

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(MarqueeFont.body(17, .bold, relativeTo: .title3))
                .foregroundStyle(Color.mqInk)
            Spacer(minLength: 12)
            NavigationLink {
                destination
            } label: {
                HStack(spacing: 2) {
                    Text(moreLabel)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                }
                .font(.mqCaption)
                .foregroundStyle(Color.mqBrass)
            }
        }
        .padding(.horizontal, MQ.gutter)
    }
}

struct PlainRailHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MarqueeFont.body(17, .bold, relativeTo: .title3))
            .foregroundStyle(Color.mqInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MQ.gutter)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The shimmer placeholder used while a screen has genuinely nothing to draw.
struct SkeletonBlock: View {
    var height: CGFloat = 64
    var radius: CGFloat = MQ.radiusSmall
    @State private var shift = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.mqPanel)
            .frame(height: height)
            .overlay {
                LinearGradient(colors: [.clear, Color.mqInk.opacity(0.05), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .offset(x: shift ? 260 : -260)
                    .clipShape(.rect(cornerRadius: radius))
            }
            .task {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shift = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// A one-line footer for a screen showing cached data while offline.
struct StaleFooter: View {
    let cachedAt: Date?

    var body: some View {
        if let cachedAt {
            Label {
                Text("Showing your last sync · \(cachedAt.formatted(.relative(presentation: .named)))")
            } icon: {
                Image(systemName: "wifi.slash")
            }
            .font(.mqCaption)
            .foregroundStyle(Color.mqInkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}
