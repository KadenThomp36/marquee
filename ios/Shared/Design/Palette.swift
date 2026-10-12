import SwiftUI

/// "Midnight Marquee" — the art-deco cinema palette the web client established, carried
/// over verbatim in dark and re-cut for light. Every value lives in the asset catalog so
/// the system resolves it per appearance and per contrast setting; nothing here hardcodes
/// a hex, which is what lets Increase Contrast and light mode work without a second pass.
public extension Color {

    // MARK: grounds
    /// The page itself. Near-black at night, warm paper by day.
    static let mqGround = Color("Ground", bundle: .marquee)
    /// A card or panel sitting on the ground.
    static let mqPanel = Color("Panel", bundle: .marquee)
    /// A panel raised one step further — sheets, wells, inset fields.
    static let mqPanelRaised = Color("PanelRaised", bundle: .marquee)

    // MARK: rules
    static let mqHairline = Color("Hairline", bundle: .marquee)
    static let mqHairlineBold = Color("HairlineBold", bundle: .marquee)

    // MARK: text
    /// Body and title text.
    static let mqInk = Color("Ink", bundle: .marquee)
    /// Secondary text: subtitles, metadata, the second line of a row.
    static let mqInkSoft = Color("InkSoft", bundle: .marquee)
    /// Tertiary text: section eyebrows, counts, timestamps.
    static let mqInkMuted = Color("InkMuted", bundle: .marquee)

    // MARK: brass
    /// The accent, as text or an icon. Darkened in light mode so it still clears AA.
    static let mqBrass = Color("Brass", bundle: .marquee)
    /// A brighter brass for emphasis on dark grounds.
    static let mqBrassBright = Color("BrassBright", bundle: .marquee)
    /// The accent as a *fill* — same brass in both appearances, because it always
    /// carries `mqBrassOnFill` text rather than being read against the page.
    static let mqBrassFill = Color("BrassFill", bundle: .marquee)
    /// The only colour that belongs on top of `mqBrassFill`.
    static let mqBrassOnFill = Color("BrassOnFill", bundle: .marquee)
    /// A dimmed brass for tracks, borders and inactive marks.
    static let mqBrassDim = Color("BrassDim", bundle: .marquee)
    /// A wash of brass for selected chips and tinted rows.
    static let mqBrassSoft = Color("BrassSoft", bundle: .marquee)

    // MARK: on artwork
    //
    // The one place the asset catalog can't help. Every colour above is cut against
    // the *page*, which is why light mode darkens the brass — `mqBrass` is #9A6B10
    // by day so it clears AA on paper. But a card's text sits on a poster, and a
    // poster is dark whatever the phone's appearance is set to. Read the page inks
    // against artwork and they disappear: dark ochre on a dark still.
    //
    // So these do not adapt, deliberately. They are the dark-mode values, pinned,
    // for anything drawn over art behind a scrim.

    /// Brass for metadata sitting on artwork — episode codes, dates, percentages.
    static let mqBrassOnArt = Color(red: 0.941, green: 0.710, blue: 0.267)
    /// Titles on artwork.
    static let mqInkOnArt = Color(red: 0.976, green: 0.957, blue: 0.925)
    /// The second line on artwork.
    static let mqInkSoftOnArt = Color(red: 0.976, green: 0.957, blue: 0.925).opacity(0.78)

    /// Series finales and destructive actions.
    static let mqVelvet = Color("Velvet", bundle: .marquee)
    /// The gradient foot under poster art, so titles stay legible over any still.
    static let mqScrim = Color("Scrim", bundle: .marquee)

    // MARK: partners
    static let mqOverseerr = Color("Overseerr", bundle: .marquee)
    static let mqPlex = Color("PlexGold", bundle: .marquee)

    // MARK: chart hues
    // The categorical ramp from the web client, CVD-validated against the panel
    // surface, re-darkened for light mode. Order is meaningful — series N always
    // takes slot N so the same genre keeps the same colour across screens.
    static let mqChartAmber = Color("ChartAmber", bundle: .marquee)
    static let mqChartBlue = Color("ChartBlue", bundle: .marquee)
    static let mqChartAqua = Color("ChartAqua", bundle: .marquee)
    static let mqChartViolet = Color("ChartViolet", bundle: .marquee)
    static let mqChartOrange = Color("ChartOrange", bundle: .marquee)
    static let mqChartRed = Color("ChartRed", bundle: .marquee)
    static let mqChartPink = Color("ChartPink", bundle: .marquee)
    static let mqChartGreen = Color("ChartGreen", bundle: .marquee)
    static let mqChartYellow = Color("ChartYellow", bundle: .marquee)
    static let mqChartNeutral = Color("ChartNeutral", bundle: .marquee)

    /// Fixed hue order for identity charts (genres, networks, studios) — the same list
    /// the web client uses, so a genre keeps its colour between the two clients.
    static let mqCategorical: [Color] = [
        .mqChartBlue, .mqChartAqua, .mqChartYellow, .mqChartGreen,
        .mqChartViolet, .mqChartRed, .mqChartPink, .mqChartOrange,
    ]

    /// Red → amber → green quality ramp for a 1–10 score.
    static func mqRating(_ score: Int) -> Color {
        let ramp: [Color] = [
            Color(red: 0.878, green: 0.322, blue: 0.290), Color(red: 0.886, green: 0.400, blue: 0.290),
            Color(red: 0.898, green: 0.510, blue: 0.282), Color(red: 0.910, green: 0.612, blue: 0.275),
            Color(red: 0.925, green: 0.710, blue: 0.267), Color(red: 0.847, green: 0.757, blue: 0.247),
            Color(red: 0.663, green: 0.761, blue: 0.278), Color(red: 0.490, green: 0.757, blue: 0.341),
            Color(red: 0.341, green: 0.753, blue: 0.416), Color(red: 0.247, green: 0.749, blue: 0.435),
        ]
        return ramp[min(max(score, 1), 10) - 1]
    }
}

public extension Bundle {
    /// The bundle that owns the shared asset catalog. Both the app and the widget
    /// extension compile their own copy, so this is always the running bundle — but
    /// naming it makes the lookup explicit rather than an accident of `.main`.
    static let marquee = Bundle(for: MarqueeBundleToken.self)
}

/// Anchor class for `Bundle.marquee`. Lives in the shared sources, so it resolves to
/// whichever binary is asking.
public final class MarqueeBundleToken {}
