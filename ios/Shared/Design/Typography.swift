import SwiftUI

/// Limelight over Archivo, the two faces the web client has always used. Every style
/// goes through `relativeTo:` so Dynamic Type scales it — a custom face that ignores
/// the user's text size is the single most common way a themed app becomes unusable.
public enum MarqueeFont {

    private static let display = "Limelight-Regular"

    private static func archivo(_ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light, .regular: "Archivo-Regular"
        case .medium: "Archivo-Medium"
        case .semibold: "Archivo-SemiBold"
        case .bold: "Archivo-Bold"
        default: "Archivo-ExtraBold"
        }
    }

    /// The wordmark and the COMPLETE stamp — the only places the display face belongs.
    public static func wordmark(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(display, size: size, relativeTo: style)
    }

    /// Body face at an explicit size and weight, scaling from `style`.
    public static func body(_ size: CGFloat,
                            _ weight: Font.Weight = .regular,
                            relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(archivo(weight), size: size, relativeTo: style)
    }
}

public extension Font {
    /// Screen titles.
    static let mqTitle = MarqueeFont.body(26, .bold, relativeTo: .largeTitle)
    /// Card and row titles.
    static let mqHeadline = MarqueeFont.body(17, .bold, relativeTo: .headline)
    /// A poster tile's title.
    static let mqTile = MarqueeFont.body(13, .semibold, relativeTo: .subheadline)
    /// Running text.
    static let mqBody = MarqueeFont.body(15, .regular, relativeTo: .body)
    /// Secondary line under a title.
    static let mqSub = MarqueeFont.body(13, .medium, relativeTo: .subheadline)
    /// Metadata, timestamps, counts.
    static let mqCaption = MarqueeFont.body(12, .medium, relativeTo: .caption)
    /// The small-caps rule that heads a section.
    static let mqEyebrow = MarqueeFont.body(11, .bold, relativeTo: .caption2)
    /// Numbers that want to line up in a column.
    static let mqNumeric = MarqueeFont.body(13, .bold, relativeTo: .footnote)
}

public extension View {
    /// A section eyebrow: uppercase, letterspaced, muted — `SECTION ─────────`.
    func mqEyebrowStyle() -> some View {
        self.font(.mqEyebrow)
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(Color.mqInkMuted)
    }
}
