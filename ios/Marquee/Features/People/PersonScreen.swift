import SwiftUI

/// One person, and everything of theirs you could watch.
///
/// The filmography is ranked by how widely seen each title is rather than by date,
/// so the roles someone is actually known for lead — a recent bit part doesn't push
/// a signature performance off the first screen.
struct PersonScreen: View {
    let personID: Int

    @Environment(Session.self) private var session
    @State private var person: PersonDetail?
    @State private var error: String?

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 104, maximum: 150, spacing: 12)

    }

    var body: some View {
        MarqueeScreen {
            if let person {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(person)
                        if let bio = person.bio, !bio.isEmpty {
                            ExpandableText(text: bio, lineLimit: 4)
                                .padding(.horizontal, MQ.gutter)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Filmography", count: "\(person.credits.count)")
                                .padding(.horizontal, MQ.gutter)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(person.credits, id: \.uniqueID) { credit in
                                    CreditTile(credit: credit)
                                }
                            }
                            .padding(.horizontal, MQ.gutter)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.bottom, 20)
                }
            } else if let error {
                LoadFailure(message: error) { await load() }
            } else {
                SkeletonBlock(height: 160).padding(MQ.gutter)
            }
        }
        .navigationTitle(person?.name ?? "Person")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func header(_ person: PersonDetail) -> some View {
        HStack(alignment: .top, spacing: 16) {
            RemoteImage(url: person.img, contentMode: .fill, placeholderSymbol: "person.fill")
                .frame(width: 104, height: 104)
                .clipShape(.circle)
                .overlay(Circle().strokeBorder(Color.mqHairlineBold, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text(person.name ?? "")
                    .font(MarqueeFont.body(21, .bold, relativeTo: .title2))
                    .foregroundStyle(Color.mqInk)
                Text(meta(person))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let imdbID = person.imdbID, !imdbID.isEmpty,
                   let url = URL(string: "https://www.imdb.com/name/\(imdbID)/") {
                    Link(destination: url) {
                        Label("IMDb", systemImage: "arrow.up.right.square")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.mqChip)
                }
            }
        }
        .padding(.horizontal, MQ.gutter)
    }

    private func meta(_ person: PersonDetail) -> String {
        var parts: [String] = []
        if let known = person.knownFor, !known.isEmpty { parts.append("Known for \(known)") }
        if let birthday = person.birthday, !birthday.isEmpty {
            let age = years(from: birthday, to: person.deathday)
            let suffix = person.deathday == nil ? age.map { " · \($0)" } ?? "" : ""
            parts.append("Born \(MQTime.medium(birthday))" + suffix)
        }
        if let death = person.deathday, !death.isEmpty {
            let age = years(from: person.birthday, to: death).map { " · \($0)" } ?? ""
            parts.append("Died \(MQTime.medium(death))" + age)
        }
        if let place = person.place, !place.isEmpty { parts.append(place) }
        return parts.joined(separator: " · ")
    }

    private func years(from birthday: String?, to end: String?) -> Int? {
        guard let birthday, let born = MQTime.date(from: birthday) else { return nil }
        let until = end.flatMap { MQTime.date(from: $0) } ?? Date()
        return Calendar.current.dateComponents([.year], from: born, to: until).year
    }

    private func load() async {
        guard let client = session.client else { return }
        do {
            person = try await client.get("person/\(personID)", as: PersonDetail.self)
            error = nil
        } catch let failure as APIError {
            if person == nil { error = failure.errorDescription }
        } catch {
            if person == nil { self.error = error.localizedDescription }
        }
    }
}

private struct CreditTile: View {
    let credit: PersonCredit

    var body: some View {
        NavigationLink(value: credit.isShow ? Navigator.Route.show(credit.id)
                                            : Navigator.Route.movie(credit.id)) {
            VStack(alignment: .leading, spacing: 6) {
                PosterArt(url: credit.poster)
                    .overlay(alignment: .topLeading) {
                        TypeBadge(isShow: credit.isShow).padding(6)
                    }
                    .overlay(alignment: .topTrailing) {
                        if let vote = credit.vote, vote > 0 {
                            Label(String(format: "%.1f", vote), systemImage: "star.fill")
                                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqBrass)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(6)
                        }
                    }
                Text(credit.title ?? "")
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(credit.character?.isEmpty == false ? credit.character! : (credit.year?.text ?? ""))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
