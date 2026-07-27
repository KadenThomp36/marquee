import SwiftUI

/// One rating chip, one rule: IMDb when the dataset has it — with the vote count that
/// gives the number its weight — and TMDB otherwise, which is what keeps small and
/// foreign titles from going blank.
struct RatingChip: View {
    var imdb: IMDbRating?
    var tmdbVote: Double?

    var body: some View {
        if let imdb, let rating = imdb.rating {
            HStack(spacing: 5) {
                Text("IMDb")
                    .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color(red: 0.961, green: 0.773, blue: 0.094), in: .rect(cornerRadius: 3))
                Text(String(format: "%.1f", rating))
                    .font(MarqueeFont.body(11.5, .bold, relativeTo: .caption))
                    .foregroundStyle(Color.mqInk)
                if let votes = imdb.votes, votes > 0 {
                    Text(Self.compact(votes))
                        .font(MarqueeFont.body(10, .medium, relativeTo: .caption2))
                        .foregroundStyle(Color.mqInkMuted)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.mqBrassDim.opacity(0.6), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("IMDb \(String(format: "%.1f", rating))"
                + (imdb.votes.map { ", \($0.mqGrouped) votes" } ?? ""))
        } else if let tmdbVote, tmdbVote > 0 {
            MetaChip(text: String(format: "%.1f", tmdbVote), symbol: "star.fill", tinted: true)
                .accessibilityLabel("TMDB rating \(String(format: "%.1f", tmdbVote))")
        }
    }

    static func compact(_ votes: Int) -> String {
        if votes >= 1_000_000 {
            return String(format: votes < 10_000_000 ? "%.1fM" : "%.0fM", Double(votes) / 1_000_000)
        }
        if votes >= 1_000 { return "\(Int((Double(votes) / 1000).rounded()))k" }
        return "\(votes)"
    }
}

/// The small bordered facts along the top of a detail hero.
struct MetaChip: View {
    let text: String
    var symbol: String?
    var tinted = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9.5))
            }
            Text(text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
        .tracking(0.3)
        .foregroundStyle(tinted ? Color.mqBrass : Color.mqInkSoft)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .strokeBorder(tinted ? Color.mqBrassDim : Color.mqHairlineBold, lineWidth: 1))
    }
}

/// Five stars standing for a score out of ten, which is how Marquee has always
/// stored ratings — each star is worth two.
struct StarRating: View {
    @Binding var rating: Int?
    var onChange: (Int?) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                let value = star * 2
                Button {
                    // Tapping the star you're already on clears the rating.
                    let next: Int? = rating == value ? nil : value
                    rating = next
                    onChange(next)
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 17))
                        .foregroundStyle((rating ?? 0) >= value
                                         ? Color.mqBrass : Color.mqHairlineBold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rate \(value) out of 10")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.mqPanelRaised, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .strokeBorder(Color.mqBrassDim, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: rating)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your rating")
        .accessibilityValue(rating.map { "\($0) out of 10" } ?? "Not rated")
    }
}

/// Faces, in billing order. Every one is a door to that person's filmography.
struct CastStrip: View {
    let people: [CastMember]

    var body: some View {
        HorizontalRail(spacing: 14) {
            ForEach(Array(people.enumerated()), id: \.offset) { _, person in
                Group {
                    if let id = person.id {
                        NavigationLink(value: Navigator.Route.person(id)) { face(person) }
                            .buttonStyle(.plain)
                    } else {
                        face(person)
                    }
                }
            }
        }
    }

    private func face(_ person: CastMember) -> some View {
        VStack(spacing: 6) {
            RemoteImage(url: person.img, contentMode: .fill, placeholderSymbol: "person.fill")
                .frame(width: 64, height: 64)
                .clipShape(.circle)
                .overlay(Circle().strokeBorder(Color.mqHairlineBold, lineWidth: 1))
            Text(person.name)
                .font(MarqueeFont.body(11.5, .semibold, relativeTo: .caption2))
                .foregroundStyle(Color.mqInk)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let character = person.character, !character.isEmpty {
                Text(character)
                    .font(MarqueeFont.body(10.5, .regular, relativeTo: .caption2))
                    .foregroundStyle(Color.mqInkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 82)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(person.character.map { "\(person.name) as \($0)" } ?? person.name)
    }
}

/// Body copy that starts clamped and opens on a tap — overviews are usually three
/// lines of interest followed by three of plot summary.
struct ExpandableText: View {
    let text: String
    var lineLimit = 3

    @State private var expanded = false

    var body: some View {
        Text(text)
            .font(.mqBody)
            .foregroundStyle(Color.mqInkSoft)
            .lineSpacing(3)
            .lineLimit(expanded ? nil : lineLimit)
            .contentShape(.rect)
            .onTapGesture { withAnimation(.snappy(duration: 0.25)) { expanded.toggle() } }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(expanded ? "Collapse" : "Expand")
    }
}

/// The section rule used inside a detail page.
struct DetailSection<Content: View>: View {
    let title: String
    var count: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title, count: count)
                .padding(.horizontal, MQ.gutter)
            content
        }
    }
}

/// A row of chip buttons that wraps rather than clipping — which matters most at the
/// accessibility text sizes, where four chips no longer fit on one line.
struct ChipRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        FlowLayout(spacing: 7, lineSpacing: 7) {
            content
        }
    }
}

/// A labelled chip button used in a detail page's action row.
struct ChipButton: View {
    let title: String
    let symbol: String
    var isOn = false
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
        }
        .buttonStyle(.mqChip(on: isOn, destructive: isDestructive))
    }
}
