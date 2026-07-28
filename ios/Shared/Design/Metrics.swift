import SwiftUI

/// Shape and rhythm constants, so a poster is the same poster everywhere.
public enum MQ {
    /// Cards, sheets, hero art.
    public static let radius: CGFloat = 16
    /// Tiles, chips, small panels.
    public static let radiusSmall: CGFloat = 11
    /// Posters are 2:3, always.
    public static let posterAspect: CGFloat = 2.0 / 3.0
    /// Stills and backdrops.
    public static let stillAspect: CGFloat = 16.0 / 9.0

    /// The horizontal gutter every screen shares.
    public static let gutter: CGFloat = 18
    /// Gap between cards in a rail.
    public static let railGap: CGFloat = 13
    /// Width of an Up Next card in a rail.
    public static let upNextWidth: CGFloat = 172
    /// Width of a poster tile in a rail.
    public static let tileWidth: CGFloat = 124
    /// Width of a small "what you watched" card.
    public static let watchedWidth: CGFloat = 116
    /// Vertical slack inside a rail's clip so card shadows survive being clipped.
    public static let railShadowRoom: CGFloat = 14

    /// The poster beside a detail hero. It gives up width at accessibility text
    /// sizes so the facts next to it keep a readable measure instead of wrapping
    /// two words at a time.
    public static func heroPoster(_ size: DynamicTypeSize) -> CGFloat {
        size.isAccessibilitySize ? 86 : 118
    }

    /// Adaptive grid columns that widen at accessibility text sizes. Without this a
    /// poster grid keeps three columns while the captions triple in size, so every
    /// title wraps and every year truncates to an ellipsis. Fewer, wider tiles.
    public static func adaptiveColumns(_ size: DynamicTypeSize,
                                       minimum: CGFloat,
                                       maximum: CGFloat = .infinity,
                                       spacing: CGFloat) -> [GridItem] {
        let scale: CGFloat = size.isAccessibilitySize ? 1.55 : 1
        // Top, not the default centre: a two-line title under one tile would
        // otherwise shove its poster down out of line with the tile beside it.
        return [GridItem(.adaptive(minimum: minimum * scale, maximum: maximum * scale),
                         spacing: spacing, alignment: .top)]
    }
}

/// One line at ordinary text sizes, two at accessibility sizes — where a single
/// line of a tile's "2021 · Marked watched" is nothing but an ellipsis.
public struct MQSecondaryLine: ViewModifier {
    @Environment(\.dynamicTypeSize) private var size
    public init() {}
    public func body(content: Content) -> some View {
        content.lineLimit(size.isAccessibilitySize ? 2 : 1)
    }
}

public extension View {
    func mqSecondaryLine() -> some View { modifier(MQSecondaryLine()) }

    /// A panel: opaque ground, hairline edge, rounded. Deliberately *not* glass —
    /// glass belongs to the control layer, never behind content.
    func mqPanel(radius: CGFloat = MQ.radiusSmall) -> some View {
        self.background(Color.mqPanel, in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.mqHairline, lineWidth: 1))
    }

    /// Poster art: fixed ratio, clipped, with a faint edge so light-mode art
    /// doesn't bleed into the page.
    func mqPosterFrame(radius: CGFloat = MQ.radiusSmall) -> some View {
        self.aspectRatio(MQ.posterAspect, contentMode: .fill)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Color.mqHairline.opacity(0.6), lineWidth: 0.5))
    }
}
