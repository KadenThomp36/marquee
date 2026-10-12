import SwiftUI

/// The two button shapes the app uses outside the system's own glass controls.
///
/// `.glass` and `.glassProminent` are the default for anything floating over content —
/// these are for the flat, opaque cases: a full-width primary in a form, and a quiet
/// text action underneath it.
public struct MarqueePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mqHeadline)
            .foregroundStyle(Color.mqBrassOnFill)
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color.mqBrassFill, in: .capsule)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.22), value: configuration.isPressed)
    }
}

public struct MarqueeQuietButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mqSub)
            .foregroundStyle(Color.mqInkSoft)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A bordered pill for secondary actions in a row — the `.chip-btn` of the web client.
public struct MarqueeChipButtonStyle: ButtonStyle {
    public var isOn: Bool
    public var isDestructive: Bool

    public init(isOn: Bool = false, isDestructive: Bool = false) {
        self.isOn = isOn
        self.isDestructive = isDestructive
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mqSub)
            .foregroundStyle(tint)
            .padding(.vertical, 9)
            .padding(.horizontal, 13)
            .background(isOn ? Color.mqBrassSoft : Color.mqPanel, in: .rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isOn ? Color.mqBrassDim : Color.mqHairline, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }

    private var tint: Color {
        if isDestructive { return .mqVelvet }
        return isOn ? .mqBrass : .mqInkSoft
    }
}

public extension ButtonStyle where Self == MarqueePrimaryButtonStyle {
    static var mqPrimary: MarqueePrimaryButtonStyle { .init() }
}

public extension ButtonStyle where Self == MarqueeQuietButtonStyle {
    static var mqQuiet: MarqueeQuietButtonStyle { .init() }
}

public extension ButtonStyle where Self == MarqueeChipButtonStyle {
    static var mqChip: MarqueeChipButtonStyle { .init() }
    static func mqChip(on: Bool, destructive: Bool = false) -> MarqueeChipButtonStyle {
        .init(isOn: on, isDestructive: destructive)
    }
}
