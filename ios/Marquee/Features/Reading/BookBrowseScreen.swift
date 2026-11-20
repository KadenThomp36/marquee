import SwiftUI

/// Everything by one author, or everything in one series: your own copies first,
/// then the rest of the bibliography from Hardcover to add from. On the open Duo the
/// header and your shelf are the left page and the rest is the right.
struct BookBrowseScreen: View {
    /// "author" or "series".
    let by: String
    let name: String
    /// Debug builds: render this instead of asking the server.
    var sample: BrowseResponse?

    @Environment(Session.self) private var session
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var data: BrowseResponse?
    @State private var error: String?
    @State private var added: Set<Int> = []

    private var isAuthor: Bool { by == "author" }
    private var columns: [GridItem] { MQ.adaptiveColumns(typeSize, minimum: 100, maximum: 140, spacing: 12) }

    var body: some View {
        MarqueeScreen {
            if let data {
                FoldSpread(spacing: 22, refresh: { await load() }) {
                    header(data)
                    shelf(data)
                } trailing: {
                    more(data)
                }
            } else if let error {
                LoadFailure(message: error) { await load() }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonBlock(height: 110, radius: MQ.radius)
                    SkeletonBlock(height: 200, radius: MQ.radius)
                }
                .padding(MQ.gutter)
            }
        }
        .navigationTitle(data?.name ?? name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: Header

    private func header(_ data: BrowseResponse) -> some View {
        let head = data.header
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                Group {
                    if isAuthor {
                        ZStack {
                            Circle().fill(Color.mqPanelRaised)
                            if let image = head?.image {
                                RemoteImage(url: image, contentMode: .fill, placeholderSymbol: "person.fill")
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color.mqInkMuted)
                            }
                        }
                        .clipShape(.circle)
                        .overlay(Circle().strokeBorder(Color.mqHairline, lineWidth: 1))
                    } else {
                        SeriesGlyph()
                            .stroke(Color.mqBrass, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                            .padding(20)
                            .background(Color.mqBrassSoft, in: .rect(cornerRadius: MQ.radius))
                            .overlay(RoundedRectangle(cornerRadius: MQ.radius).strokeBorder(Color.mqBrassDim, lineWidth: 1))
                    }
                }
                .frame(width: 78, height: 78)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isAuthor ? "Author" : "Series")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqBrass)
                    Text(data.name)
                        .font(.mqTitle)
                        .foregroundStyle(Color.mqInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if let meta = meta(data) {
                        Text(meta)
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                            .monospacedDigit()
                    }
                }
            }

            if let bio = head?.bio, !bio.isEmpty {
                ExpandableText(text: bio, lineLimit: 4)
            }

            if let slug = head?.slug,
               let url = URL(string: "https://hardcover.app/\(isAuthor ? "authors" : "series")/\(slug)") {
                Link(destination: url) {
                    Label("Hardcover", systemImage: "arrow.up.right.square")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.mqChip)
            }
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 12)
    }

    private func meta(_ data: BrowseResponse) -> String? {
        var parts: [String] = []
        if !data.shelf.isEmpty { parts.append("\(data.shelf.count) on your shelf") }
        if let count = data.header?.booksCount, count > 0 {
            parts.append("\(count) \(isAuthor ? "titles" : "books") on Hardcover")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Shelf

    @ViewBuilder
    private func shelf(_ data: BrowseResponse) -> some View {
        if !data.shelf.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("On your shelf", count: "\(data.shelf.count)")
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(data.shelf) { item in
                        NavigationLink(value: Navigator.Route.book(item.id)) {
                            BrowseTile(cover: item.cover, title: item.displayTitle,
                                       subtitle: shelfLine(item),
                                       position: isAuthor ? nil : SeriesPosition.label(item.seriesPos),
                                       fraction: item.readingState == .reading ? item.fraction(for: .book) : nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, MQ.gutter)
        } else if data.more.isEmpty {
            EmptyLine("Nothing found for \u{201C}\(data.name)\u{201D}.")
        }
    }

    private func shelfLine(_ item: ReadingItem) -> String {
        let state = item.readingState.map { state -> String in
            switch state {
            case .reading: "Reading, \(Int((item.fraction(for: .book) * 100).rounded()))%"
            case .want: "Want to read"
            case .finished: item.rating.map { "Finished, \($0)/10" } ?? "Finished"
            case .paused: "Paused"
            case .dnf: "Didn\u{2019}t finish"
            }
        }
        return state ?? (item.year?.text ?? "")
    }

    // MARK: More

    @ViewBuilder
    private func more(_ data: BrowseResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(isAuthor ? "More by \(data.name)" : "Rest of the series",
                          count: data.more.isEmpty ? nil : "\(data.more.count)")
            if data.more.isEmpty {
                Text(data.header == nil
                     ? "Hardcover didn\u{2019}t answer, so only your own copies are here. Pull to try again."
                     : (isAuthor ? "You have everything Hardcover lists for \(data.name)." : "You have every book in the series."))
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(data.more) { book in
                        NavigationLink(value: Navigator.Route.bookPreview(book.hcID)) {
                            BrowseTile(cover: book.cover, title: book.displayTitle,
                                       subtitle: moreLine(book),
                                       position: isAuthor ? nil : SeriesPosition.label(book.seriesPos),
                                       score: book.communityRating,
                                       added: added.contains(book.hcID)) { state in
                                await add(book, state: state)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 12)
    }

    private func moreLine(_ book: BookSearchResult) -> String {
        let lead = isAuthor ? (book.series ?? "") : (book.author ?? "")
        return [lead, book.year?.text ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: Data

    private func load() async {
        if let sample { data = sample; return }
        guard let client = session.client else { return }
        do {
            data = try await client.get("books/browse", query: ["by": by, "name": name],
                                        as: BrowseResponse.self)
            error = nil
        } catch {
            if data == nil { self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription }
        }
    }

    private func add(_ book: BookSearchResult, state: ReadingState) async {
        guard let client = session.client else { return }
        if (try? await client.post("books/add", body: AddBookRequest(from: book, state: state),
                                   as: AddedResponse.self)) != nil {
            added.insert(book.hcID)
        }
    }
}

/// A cover with its series number, title and one line under it. With `add`, the
/// cover carries the shelf's quick-add buttons until it's added.
private struct BrowseTile: View {
    let cover: String?
    let title: String
    let subtitle: String
    var position: String?
    var fraction: Double?
    var score: Double?
    var added = false
    var add: ((ReadingState) async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverArt(url: cover)
                .overlay(alignment: .bottomLeading) {
                    if let position {
                        Text(position)
                            .font(MarqueeFont.body(12, .bold, relativeTo: .caption))
                            .foregroundStyle(Color.mqBrassOnFill)
                            .monospacedDigit()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.mqBrassFill, in: .rect(cornerRadius: 6))
                            .padding(6)
                            .accessibilityLabel("Book \(position.dropFirst())")
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let score {
                        Label(String(format: "%.1f", score), systemImage: "star.fill")
                            .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqBrassOnArt)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: .capsule)
                            .padding(6)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let add {
                        if added {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.mqBrassOnArt)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: .circle)
                                .padding(6)
                                .accessibilityLabel("On your shelf")
                        } else {
                            VStack(spacing: 6) {
                                quickAdd("bookmark", "Want to read") { await add(.want) }
                                quickAdd("book", "Start reading now") { await add(.reading) }
                            }
                            .padding(6)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if let fraction {
                        ProgressBar(fraction: fraction, height: 4)
                            .padding(.horizontal, 6)
                            .padding(.bottom, position == nil ? 6 : 34)
                    }
                }

            Text(title)
                .font(.mqTile)
                .foregroundStyle(Color.mqInk)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .mqSecondaryLine()
            }
        }
        .sensoryFeedback(.success, trigger: added) { _, new in new }
        .accessibilityElement(children: .contain)
        .accessibilityLabel([position.map { "Book \($0.dropFirst())" }, title, subtitle]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". "))
    }

    private func quickAdd(_ symbol: String, _ label: String,
                          action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.mqInk)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Two books standing and one leaning — the web client's series mark, drawn so it
/// scales with whatever it sits beside.
struct SeriesGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        // Drawn on the web icon's 24-point grid, then scaled into `rect`.
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        var path = Path()
        path.addRect(CGRect(origin: point(4.5, 4.5), size: CGSize(width: 3.6 * scale, height: 15 * scale)))
        path.addRect(CGRect(origin: point(10, 4.5), size: CGSize(width: 3.4 * scale, height: 15 * scale)))
        path.move(to: point(16.2, 5.4))
        path.addLine(to: point(19.6, 6.3))
        path.addLine(to: point(16, 19.9))
        path.addLine(to: point(12.6, 19))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
enum BrowseSamples {
    static let series: BrowseResponse? = {
        let json = """
        {"by": "series", "name": "The Expanse",
         "header": {"id": 1, "name": "The Expanse", "slug": "the-expanse", "books_count": 9,
                    "bio": "Humanity has colonised the solar system, and the peace between Earth, Mars and the Belt is about to break."},
         "shelf": [
           {"id": 700007, "title": "Leviathan Wakes", "author": "James S. A. Corey", "year": 2011, "state": "finished",
            "progress": 561, "pages": 561, "rating": 8, "series": "The Expanse", "series_pos": 1},
           {"id": 700099, "title": "Caliban's War", "author": "James S. A. Corey", "year": 2012, "state": "reading",
            "progress": 210, "pages": 595, "series": "The Expanse", "series_pos": 2}],
         "more": [
           {"hc_id": 1, "title": "The Butcher of Anderson Station", "author": "James S. A. Corey", "year": 2011, "series_pos": 1.5, "community_rating": 3.9},
           {"hc_id": 2, "title": "Abaddon's Gate", "author": "James S. A. Corey", "year": 2013, "series_pos": 3, "community_rating": 4.2},
           {"hc_id": 3, "title": "Cibola Burn", "author": "James S. A. Corey", "year": 2014, "series_pos": 4, "community_rating": 4.1},
           {"hc_id": 4, "title": "Nemesis Games", "author": "James S. A. Corey", "year": 2015, "series_pos": 5, "community_rating": 4.4}]}
        """
        return try? JSONDecoder().decode(BrowseResponse.self, from: Data(json.utf8))
    }()
}
#endif
