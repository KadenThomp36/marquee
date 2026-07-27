import SwiftUI

/// Where to watch, collapsed behind one summarising line.
///
/// The web client learned this the hard way: a wall of provider logos on every detail
/// page is noise, and the answer you actually want ("Hulu, Paramount+ and 11 more",
/// or better, "it's already on your Plex") fits on one row.
struct WhereToWatch: View {
    let providers: WatchProviders?
    let isOnPlex: Bool

    @State private var expanded = false

    private var groups: [(key: String, label: String, providers: [Provider])] {
        guard let providers else { return [] }
        return [("flatrate", isOnPlex ? "Also streaming" : "Stream", providers.flatrate),
                ("rent", "Rent", providers.rent),
                ("buy", "Buy", providers.buy)]
            .filter { !$0.2.isEmpty }
            .map { (key: $0.0, label: $0.1, providers: $0.2) }
    }

    private var summary: String {
        if isOnPlex { return "Ready to play on your Plex" }
        let names = groups.flatMap { $0.providers.compactMap(\.name) }
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        guard !unique.isEmpty else { return "Nothing listed in the US right now" }
        if unique.count <= 2 { return unique.joined(separator: ", ") }
        return "\(unique.prefix(2).joined(separator: ", ")) and \(unique.count - 2) more"
    }

    var body: some View {
        if providers != nil, isOnPlex || !groups.isEmpty {
            DetailSection(title: "Where to watch",
                          count: providers?.region ?? "US") {
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isOnPlex ? "play.tv.fill" : "ticket.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(isOnPlex ? Color.mqPlex : Color.mqBrass)
                                .frame(width: 30, height: 30)
                                .background(Color.mqBrassSoft, in: .rect(cornerRadius: 9))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isOnPlex ? "On your Plex"
                                     : (expanded ? "Where to watch" : "See where to watch"))
                                    .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                                    .foregroundStyle(Color.mqInk)
                                Text(summary)
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkMuted)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(expanded ? Color.mqBrass : Color.mqInkMuted)
                                .rotationEffect(.degrees(expanded ? 90 : 0))
                        }
                        .padding(13)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(expanded ? "Collapse" : "Expand")

                    if expanded { details }
                }
                .mqPanel(radius: MQ.radius)
                .padding(.horizontal, MQ.gutter)
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isOnPlex {
                HStack(spacing: 11) {
                    Image(systemName: "play.tv.fill")
                        .foregroundStyle(Color.mqPlex)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("On your Plex")
                            .font(MarqueeFont.body(13.5, .bold, relativeTo: .caption))
                            .foregroundStyle(Color.mqInk)
                        Text("Ready to play now\(groups.isEmpty ? "" : " — also streaming below")")
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkSoft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark").foregroundStyle(Color.mqBrass)
                }
                .padding(11)
                .background(Color.mqBrassSoft, in: .rect(cornerRadius: MQ.radiusSmall))
            }

            ForEach(groups, id: \.key) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(group.key == "flatrate" ? Color.mqBrass : Color.mqInkMuted)
                            .frame(width: 7, height: 7)
                        Text(group.label).mqEyebrowStyle()
                    }
                    FlowLayout(spacing: 14, lineSpacing: 14) {
                        ForEach(Array(group.providers.enumerated()), id: \.offset) { _, provider in
                            providerTile(provider)
                        }
                    }
                }
            }

            if let link = providers?.link, let url = URL(string: link) {
                Link(destination: url) {
                    Label("Open on JustWatch", systemImage: "arrow.up.right")
                        .font(.mqCaption)
                }
                .foregroundStyle(Color.mqBrass)
            }
        }
        .padding(.horizontal, 13)
        .padding(.bottom, 14)
    }

    private func providerTile(_ provider: Provider) -> some View {
        VStack(spacing: 7) {
            RemoteImage(url: provider.logo, contentMode: .fill, placeholderSymbol: "play.rectangle")
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(Color.mqHairlineBold, lineWidth: 1))
            Text(provider.name ?? "")
                .font(MarqueeFont.body(10.5, .medium, relativeTo: .caption2))
                .foregroundStyle(Color.mqInkSoft)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 64)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(provider.name ?? "Provider")
    }
}
