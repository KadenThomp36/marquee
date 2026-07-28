import SwiftUI

/// Tap the cover and you get every poster and backdrop TMDB has, full screen.
///
/// English and language-neutral art comes first — the server sorts it that way,
/// because a wall of foreign posters isn't what you wanted when you tapped the cover.
struct ArtworkGallery: View {
    let itemType: String
    let itemID: Int
    let title: String

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var artwork: ArtworkResponse?
    @State private var index = 0
    @State private var paged: Int?
    @State private var loadFailed = false
    @State private var chromeVisible = true

    private var images: [Artwork] { artwork?.all ?? [] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if images.isEmpty {
                if loadFailed {
                    ContentUnavailableView("No other artwork",
                                           systemImage: "photo.on.rectangle",
                                           description: Text("TMDB doesn't have any more art for this one."))
                        .foregroundStyle(Color.mqInkSoft)
                } else {
                    ProgressView().tint(Color.mqBrass)
                }
            } else {
                // A paging scroll view rather than TabView's page style: it keeps its
                // place properly as pages come and go, and hands off to the thumbnail
                // strip through one shared position.
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(images.enumerated()), id: \.offset) { offset, art in
                            RemoteImage(url: art.full ?? art.thumb, contentMode: .fit)
                                .containerRelativeFrame(.horizontal)
                                .id(offset)
                                .accessibilityLabel("\(art.kind == "poster" ? "Poster" : "Backdrop") \(offset + 1) of \(images.count)")
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $paged)
                .scrollIndicators(.hidden)
                .ignoresSafeArea()
                .onAppear { paged = index }
                .onChange(of: paged) { _, new in
                    if let new { index = new }
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { chromeVisible.toggle() }
                }
            }

            if chromeVisible, !images.isEmpty {
                VStack {
                    topBar
                    Spacer()
                    thumbnailStrip
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden()
        .task { await load() }
    }

    private var topBar: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Text(title)
                    .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(index + 1) / \(images.count)")
                    .font(.mqCaption)
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 10)
    }

    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(Array(images.enumerated()), id: \.offset) { offset, art in
                        Button {
                            withAnimation(.snappy) {
                                index = offset
                                paged = offset
                            }
                        } label: {
                            RemoteImage(url: art.thumb, contentMode: .fill)
                                .frame(width: 46, height: 69)
                                .clipShape(.rect(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(offset == index ? Color.mqBrass : .white.opacity(0.15),
                                                  lineWidth: offset == index ? 2 : 1))
                                .opacity(offset == index ? 1 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .id(offset)
                        .accessibilityLabel("Artwork \(offset + 1)")
                    }
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .frame(height: 82)
            .background(.ultraThinMaterial)
            .onChange(of: index) { _, new in
                withAnimation(.snappy) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private func load() async {
        guard let client = session.client else { loadFailed = true; return }
        do {
            artwork = try await client.get("images/\(itemType)/\(itemID)", as: ArtworkResponse.self)
            if artwork?.count == 0 { loadFailed = true }
        } catch {
            loadFailed = true
        }
    }
}
