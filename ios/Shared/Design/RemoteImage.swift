import SwiftUI

/// Poster and still art. The API hands back absolute CDN URLs (image.tmdb.org,
/// assets.hardcover.app), which is the one exception to "the phone talks only to the
/// Marquee server" — and the reason this loads them directly rather than proxying.
///
/// Art is cached on disk so a rail you've already seen redraws instantly and an
/// offline launch still has its posters.
struct RemoteImage: View {
    let url: String?
    var contentMode: ContentMode = .fill
    /// Drawn while loading and when there's nothing to load.
    var placeholderSymbol: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fetched: UIImage?

    private var parsed: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    /// Read straight from the cache during `body`. Waiting for `.task` would cost a
    /// frame of placeholder even for art already on screen, which is what made a
    /// second copy of a card flash grey the instant it appeared.
    private var image: UIImage? {
        if let fetched { return fetched }
        return parsed.flatMap { ArtLoader.shared.cached($0) }
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .clipped()
        .task(id: url) {
            guard let parsed, ArtLoader.shared.cached(parsed) == nil else { return }
            let loaded = await ArtLoader.shared.load(parsed)
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                fetched = loaded
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.mqPanelRaised
            if let placeholderSymbol {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.mqInkMuted.opacity(0.5))
            }
        }
    }
}

/// Fill a box of a known height with art, without letting the art decide the width.
///
/// `RemoteImage` scaled to fill has an intrinsic width of `height × aspect`, and a
/// 16:9 backdrop at 260pt tall therefore *demands* 462pt — wider than any phone.
/// Put through a `Color.clear` frame with the image as an overlay, the art fills and
/// crops but contributes nothing to layout.
struct FilledArt: View {
    let url: String?
    let height: CGFloat
    var contentMode: ContentMode = .fill

    var body: some View {
        Color.clear
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay {
                RemoteImage(url: url, contentMode: contentMode)
            }
            .clipped()
    }
}

/// A poster tile that always occupies the same 2:3 slot whether or not art arrives.
struct PosterArt: View {
    let url: String?
    var radius: CGFloat = MQ.radiusSmall

    var body: some View {
        RemoteImage(url: url, contentMode: .fill, placeholderSymbol: "film")
            .aspectRatio(MQ.posterAspect, contentMode: .fit)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Color.mqHairline.opacity(0.7), lineWidth: 0.5)
            )
    }
}

/// The reader's equivalent — covers aren't reliably 2:3, so this keeps the frame and
/// lets the art fill it.
struct CoverArt: View {
    let url: String?
    var radius: CGFloat = MQ.radiusSmall

    var body: some View {
        RemoteImage(url: url, contentMode: .fill, placeholderSymbol: "book.closed")
            .aspectRatio(MQ.posterAspect, contentMode: .fit)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Color.mqHairline.opacity(0.7), lineWidth: 0.5)
            )
    }
}

/// Avatars: the uploaded photo when there is one, else a coloured monogram, which is
/// exactly what the web client falls back to.
struct AvatarView: View {
    let person: Person
    var size: CGFloat = 32
    /// Avatars are served by the Marquee server itself, so they need the paired base.
    var baseURL: URL?

    var body: some View {
        Group {
            if let resolved {
                RemoteImage(url: resolved, contentMode: .fill)
            } else {
                ZStack {
                    Color(hue: person.monogramHue / 360, saturation: 0.42, brightness: 0.46)
                    Text(person.monogram)
                        .font(MarqueeFont.body(size * 0.42, .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityLabel(person.name)
    }

    /// `users.avatar` is a server-relative path like `/avatars/u1.jpg?v=…`.
    private var resolved: String? {
        guard let avatar = person.avatar, !avatar.isEmpty else { return nil }
        if avatar.hasPrefix("http") { return avatar }
        guard let baseURL else { return nil }
        return baseURL.absoluteString + avatar
    }
}
