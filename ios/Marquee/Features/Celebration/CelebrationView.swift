import SwiftUI

/// Hosts the completion fanfare above whatever screen you're on. One at a time, in
/// the order they were earned.
extension View {
    func celebrationHost() -> some View {
        modifier(CelebrationHost())
    }
}

private struct CelebrationHost: ViewModifier {
    @Environment(Session.self) private var session

    func body(content: Content) -> some View {
        content.overlay {
            if let celebration = session.celebrationQueue.first {
                CelebrationView(celebration: celebration) {
                    session.finishCelebration(celebration)
                }
                .id(celebration.id)
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.celebrationQueue.first?.id)
    }
}

/// The payoff for weeks of watching: marquee bulbs, spotlight rays, a foil stamp
/// slammed over the poster, and a lot of confetti. A series finale gets red velvet.
///
/// Everything here has a Reduce Motion path that keeps the *moment* — the card, the
/// stamp, the numbers — and drops only the motion.
struct CelebrationView: View {
    let celebration: Celebration
    let done: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.openURL) private var openURL

    @State private var appeared = false
    @State private var stamped = false
    @State private var lettersIn = false
    @State private var confettiStart: Date?
    @State private var dismissed = false

    private var isSeries: Bool { celebration.isSeries }

    var body: some View {
        ZStack {
            ground
            if !reduceMotion { SpotlightRays(velvet: isSeries).opacity(appeared ? 0.85 : 0) }
            if let confettiStart, !reduceMotion {
                ConfettiCanvas(start: confettiStart, rich: isSeries)
                    .allowsHitTesting(false)
            }
            card
        }
        .ignoresSafeArea()
        .contentShape(.rect)
        .onTapGesture { dismiss() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)
        .sensoryFeedback(.success, trigger: lettersIn)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { dismiss() }
        .task { await run() }
    }

    // MARK: - Layers

    private var ground: some View {
        ZStack {
            RadialGradient(
                colors: isSeries
                    ? [Color(red: 0.235, green: 0.067, blue: 0.094).opacity(0.94), Color.black.opacity(0.97)]
                    : [Color(red: 0.169, green: 0.125, blue: 0.047).opacity(0.94), Color.black.opacity(0.97)],
                center: .init(x: 0.5, y: 0.4), startRadius: 40, endRadius: 700)

            if let backdrop = celebration.show.backdrop, !reduceTransparency {
                // Through a clear frame, not directly: a `.fill` image asks for a width
                // of height × aspect, which for a 16:9 backdrop over a full-height
                // screen is far wider than the phone. The ZStack grew to match and the
                // whole celebration ended up centred on a canvas half off screen.
                Color.clear
                    .overlay {
                        RemoteImage(url: backdrop, contentMode: .fill)
                            .blur(radius: 40)
                            .opacity(0.4)
                            .scaleEffect(1.2)
                    }
                    .clipped()
                    .allowsHitTesting(false)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            Text(isSeries ? "That's a wrap" : "Season complete")
                .mqEyebrowStyle()
                .tracking(3)
                .foregroundStyle(Color.mqBrass)
                .padding(.bottom, 16)

            artwork
                .padding(.bottom, 18)

            title
                .padding(.bottom, 5)

            Text(subtitle)
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
                .multilineTextAlignment(.center)

            statsRow
                .padding(.top, 18)

            Text("your \(ordinal(celebration.nthThisYear)) \(isSeries ? "series" : "season") finished in \(String(celebration.year))")
                .font(.mqCaption)
                .italic()
                .foregroundStyle(Color.mqInkMuted)
                .padding(.top, 10)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button("Nice") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.mqBrassFill)
                    .foregroundStyle(Color.mqBrassOnFill)

                Button("See the show") {
                    dismiss()
                    Navigator.shared.open(.show(celebration.show.id))
                }
                .buttonStyle(.bordered)
                .tint(Color.mqBrass)
            }
            .font(.mqSub)
            .padding(.top, 20)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 430)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.mqPanelRaised.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color.mqBrass.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.6), radius: 40, y: 24)
                .shadow(color: (isSeries ? Color.mqVelvet : Color.mqBrass).opacity(0.22), radius: 60)
        }
        .overlay(alignment: .top) { BulbRow(count: 11).padding(.top, 10) }
        .overlay(alignment: .bottom) { BulbRow(count: 11).padding(.bottom, 10) }
        .scaleEffect(appeared ? 1 : 0.86)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .modifier(ShakeEffect(shakes: stamped && !reduceMotion ? 1 : 0))
        .padding(.horizontal, 18)
    }

    private var artwork: some View {
        ZStack {
            RemoteImage(url: celebration.show.poster, contentMode: .fill)
                .frame(width: 150, height: 225)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.mqBrass.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 22, y: 12)
                // The poster swings in like a card being turned face up.
                .rotation3DEffect(.degrees(appeared || reduceMotion ? 0 : -62),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .opacity(appeared || reduceMotion ? 1 : 0)

            stamp
                .offset(y: 24)
        }
        .accessibilityHidden(true)
    }

    private var stamp: some View {
        VStack(spacing: 2) {
            Text(isSeries ? "SERIES" : "SEASON")
                .font(MarqueeFont.wordmark(15, relativeTo: .caption))
                .tracking(2.2)
            Text("COMPLETE")
                .font(MarqueeFont.wordmark(22, relativeTo: .title3))
                .tracking(1.2)
        }
        .foregroundStyle(Color.mqBrassBright)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.72), in: .rect(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7)
            .strokeBorder(Color.mqBrassBright, lineWidth: 3))
        .rotationEffect(.degrees(-11))
        .scaleEffect(stamped || reduceMotion ? 1 : 2.7)
        .opacity(stamped || reduceMotion ? 1 : 0)
        .blur(radius: stamped || reduceMotion ? 0 : 6)
    }

    private var title: some View {
        // Letter-by-letter rise, the web client's signature. Collapses to a plain
        // title under Reduce Motion rather than disappearing.
        Group {
            if reduceMotion {
                Text(celebration.show.displayTitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            } else {
                // A wrapping layout, not an HStack: a long title would otherwise make
                // the card as wide as the title and push it off the screen.
                FlowLayout(spacing: 9, lineSpacing: 2, alignment: .center) {
                    ForEach(titleWords) { word in
                        HStack(spacing: 0) {
                            ForEach(Array(word.text.enumerated()), id: \.offset) { offset, character in
                                Text(String(character))
                                    .opacity(lettersIn ? 1 : 0)
                                    .offset(y: lettersIn ? 0 : 14)
                                    .animation(.spring(duration: 0.42)
                                        .delay(Double(word.start + offset) * 0.028), value: lettersIn)
                            }
                        }
                    }
                }
            }
        }
        .font(MarqueeFont.wordmark(25, relativeTo: .title))
        .foregroundStyle(Color.mqInk)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(celebration.show.displayTitle)
    }

    /// Words, each carrying the index of its first letter, so the rise still runs
    /// across the whole title even though wrapping happens between words.
    private struct TitleWord: Identifiable {
        let id = UUID()
        let text: String
        let start: Int
    }

    private var titleWords: [TitleWord] {
        var index = 0
        return celebration.show.displayTitle.split(separator: " ").map { word in
            defer { index += word.count + 1 }
            return TitleWord(text: String(word), start: index)
        }
    }

    private var subtitle: String {
        var parts: [String] = [isSeries ? "The complete series" : (celebration.seasonName ?? "")]
        if let span = spanLabel { parts.append(span) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var spanLabel: String? {
        guard let days = celebration.days else { return nil }
        switch days {
        case ..<2: return "in a single day"
        case ..<31: return "over \(days) days"
        case ..<400: return "over \(Int((Double(days) / 30.4).rounded())) months"
        default: return "over \(String(format: "%.1f", Double(days) / 365)) years"
        }
    }

    private var statsRow: some View {
        FlowLayout(spacing: 9, lineSpacing: 9, alignment: .center) {
            StatPill(value: "\(celebration.episodes)",
                     label: celebration.episodes == 1 ? "episode" : "episodes")
            StatPill(value: hoursLabel(celebration.minutes), label: "watched")
            if isSeries {
                StatPill(value: "\(celebration.seasons)",
                         label: celebration.seasons == 1 ? "season" : "seasons")
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timing

    private func run() async {
        withAnimation(.spring(duration: 0.5)) { appeared = true }
        if !reduceMotion {
            confettiStart = Date()
            try? await Task.sleep(for: .milliseconds(580))
            withAnimation(.spring(duration: 0.42)) { stamped = true }
            try? await Task.sleep(for: .milliseconds(140))
            lettersIn = true
        } else {
            stamped = true
            lettersIn = true
        }
        // Long enough to read, short enough that it never feels like a dialog.
        try? await Task.sleep(for: .seconds(reduceMotion ? 5 : 9))
        dismiss()
    }

    private func dismiss() {
        guard !dismissed else { return }
        dismissed = true
        done()
    }

    private func hoursLabel(_ minutes: Int) -> String {
        minutes >= 60
            ? "\(minutes / 60)h\(minutes % 60 > 0 ? " \(minutes % 60)m" : "")"
            : "\(minutes)m"
    }

    private func ordinal(_ n: Int) -> String {
        let suffixes = ["th", "st", "nd", "rd"]
        let value = n % 100
        let index = (value >= 11 && value <= 13) ? 0 : min(n % 10, 4)
        return "\(n)\(suffixes.indices.contains(index) ? suffixes[index] : "th")"
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(MarqueeFont.body(19, .bold, relativeTo: .title3))
                .foregroundStyle(Color.mqBrassBright)
                .monospacedDigit()
            Text(label)
                .font(.mqEyebrow)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(Color.mqInkSoft)
        }
        .frame(minWidth: 72)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(Color.mqBrassSoft, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

/// The slow sweep of house lights behind the card.
private struct SpotlightRays: View {
    let velvet: Bool
    @State private var angle: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let centre = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let radius = max(size.width, size.height) * 1.4
                let spin = seconds.truncatingRemainder(dividingBy: 26) / 26 * 2 * .pi
                for index in 0..<16 {
                    let start = spin + Double(index) * (.pi * 2 / 16)
                    var path = Path()
                    path.move(to: centre)
                    path.addArc(center: centre, radius: radius,
                                startAngle: .radians(start),
                                endAngle: .radians(start + 0.105), clockwise: false)
                    path.closeSubpath()
                    let tint = velvet && index % 3 == 0
                        ? Color.mqVelvet.opacity(0.2)
                        : Color.mqBrass.opacity(0.17)
                    canvas.fill(path, with: .color(tint))
                }
            }
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Foil rectangles and discs, gravity and flutter — two bursts, then it rains out.
/// Drawn in one `Canvas` per frame rather than as hundreds of views.
private struct ConfettiCanvas: View {
    let start: Date
    let rich: Bool

    private static let gold: [Color] = [
        Color(red: 0.941, green: 0.710, blue: 0.267), Color(red: 1, green: 0.851, blue: 0.541),
        Color(red: 0.753, green: 0.506, blue: 0.094), Color(red: 0.949, green: 0.925, blue: 0.874),
    ]
    private static let pop: [Color] = [
        Color(red: 0.690, green: 0.251, blue: 0.310), Color(red: 0.561, green: 0.498, blue: 0.910),
        Color(red: 0.224, green: 0.529, blue: 0.898), Color(red: 0.133, green: 0.659, blue: 0.353),
    ]

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            Canvas { canvas, size in
                guard elapsed < 11 else { return }
                for bit in Self.bits(rich: rich, size: size) {
                    guard elapsed >= bit.delay else { continue }
                    let t = elapsed - bit.delay
                    let x = bit.origin.x + bit.velocity.dx * t
                    let y = bit.origin.y + bit.velocity.dy * t + 165 * t * t
                    guard y < size.height + 60 else { continue }
                    let flutter = sin(t * 3.1 + bit.phase) * 14
                    let squash = abs(cos(t * 3.4 + bit.phase))
                    let rect = CGRect(x: x + flutter - bit.size.width / 2,
                                      y: y - bit.size.height * squash / 2,
                                      width: bit.size.width,
                                      height: max(1, bit.size.height * squash))
                    var transform = canvas
                    transform.translateBy(x: rect.midX, y: rect.midY)
                    transform.rotate(by: .radians(bit.spin * t + bit.phase))
                    let local = CGRect(x: -rect.width / 2, y: -rect.height / 2,
                                       width: rect.width, height: rect.height)
                    let shape: Path = bit.isDisc ? Path(ellipseIn: local) : Path(local)
                    transform.opacity = max(0, min(1, 1.4 - t / 7))
                    transform.fill(shape, with: .color(bit.color))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private struct Bit {
        var origin: CGPoint
        var velocity: CGVector
        var size: CGSize
        var spin: Double
        var phase: Double
        var color: Color
        var isDisc: Bool
        var delay: Double
    }

    /// Deterministic from a seeded generator, so every frame of a given celebration
    /// draws the same confetti — a `Canvas` is re-evaluated constantly and random
    /// values would boil.
    private static func bits(rich: Bool, size: CGSize) -> [Bit] {
        var generator = SeededGenerator(seed: rich ? 0x5EED_BEEF : 0x5EED_CAFE)
        var out: [Bit] = []

        func burst(count: Int, at origin: CGPoint, spread: Double, power: Double, delay: Double) {
            for _ in 0..<count {
                let angle = -Double.pi / 2 + (Double.random(in: -0.5...0.5, using: &generator)) * spread
                let speed = power * Double.random(in: 0.55...1.3, using: &generator)
                let usePop = Double.random(in: 0...1, using: &generator) < (rich ? 0.34 : 0.22)
                let palette = usePop ? pop : gold
                out.append(Bit(
                    origin: origin,
                    velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                    size: CGSize(width: Double.random(in: 5...12, using: &generator),
                                 height: Double.random(in: 9...21, using: &generator)),
                    spin: Double.random(in: -5...5, using: &generator),
                    phase: Double.random(in: 0...6.28, using: &generator),
                    color: palette[Int.random(in: 0..<palette.count, using: &generator)],
                    isDisc: Double.random(in: 0...1, using: &generator) < 0.22,
                    delay: delay))
            }
        }

        burst(count: 70, at: CGPoint(x: size.width / 2, y: size.height * 0.52),
              spread: 2.4, power: 520, delay: 0)
        burst(count: 44, at: CGPoint(x: 0, y: size.height), spread: 1.1, power: 760, delay: 0.26)
        burst(count: 44, at: CGPoint(x: size.width, y: size.height), spread: 1.1, power: 760, delay: 0.26)
        for step in 0..<6 {
            burst(count: 9,
                  at: CGPoint(x: Double.random(in: 0...size.width, using: &generator), y: -20),
                  spread: 3.1, power: 60, delay: 1.5 + Double(step) * 0.9)
        }
        return out
    }
}

/// Reproducible pseudo-randomness for the confetti layout.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// The stamp landing knocks the card sideways once.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard shakes > 0 else { return ProjectionTransform(.identity) }
        let travel = sin(shakes * .pi * 4) * 7 * (1 - shakes)
        return ProjectionTransform(CGAffineTransform(translationX: travel, y: 0))
    }
}
