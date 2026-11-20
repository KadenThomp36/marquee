import SwiftUI
import UIKit

/// Prop the Duo half-open and it becomes a little cinema for whatever you're
/// watching on the big screen.
///
/// The half standing up is the marquee — what's showing, in lights. The half lying
/// flat is the box office: a showtime clock that knows the episode's length and when
/// it'll end, and the one button you want when the credits roll. The crease is the
/// line between them, wherever it runs: laid on a table like a laptop, the sign is
/// above the controls; held like a book, they face each other.
///
/// And when a reading session is running, the phone is held like a book because it's
/// standing in for one: the sign lights the title you're reading, and the controls
/// keep the session's time and end it.
///
/// Folding the phone further dims the house lights.
struct ScreeningRoom: View {
    let onLeave: () -> Void

    enum Mode: Hashable { case watching, reading }

    @Environment(Session.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hinge = Hinge.shared
    @State private var data = RemoteData<Dashboard>(cacheKey: "dashboard")
    /// Reading sessions running right now, newest first.
    @State private var sessions: [ActiveSession] = []
    @State private var loaded = false
    /// Chosen with the switch; until then, a running session wins.
    @State private var chosenMode: Mode?
    /// Which show in the queue is on the marquee.
    @State private var showID: Int?
    @State private var stamping = false
    @State private var punching = false
    @State private var thud = false
    @State private var curtain: CGFloat = 0
    @State private var progressTarget: ReadingProgressTarget?
    @AppStorage("duo.showtime") private var showtimeRecord = ""

    private var queue: [ShowCard] {
        (data.value?.upNext ?? []).filter { $0.nextEp != nil }
    }

    private var current: ShowCard? {
        queue.first { $0.id == showID } ?? queue.first
    }

    private var reading: ActiveSession? { sessions.first }

    private var mode: Mode? {
        switch chosenMode {
        case .reading where reading != nil: return .reading
        case .watching where current != nil: return .watching
        default:
            if reading != nil { return .reading }
            if current != nil { return .watching }
            return nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let fold = proxy.foldLine
            ZStack {
                Color.black.ignoresSafeArea()
                switch mode {
                case .watching:
                    if let show = current { watching(show, in: proxy.size, fold: fold) }
                case .reading:
                    if let reading { readingDesk(reading, in: proxy.size, fold: fold) }
                case nil:
                    if loaded {
                        emptyHouse
                    } else {
                        ProgressView().tint(Color.mqBrassOnArt)
                    }
                }
            }
            // The entrance: the curtain parts on the crease, and the room is lit.
            .overlay {
                CurtainPair(openness: curtain,
                            seam: fold.flatMap { $0.isVertical ? $0.center.x : nil })
                    .ignoresSafeArea()
            }
        }
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: thud)
        .task { await load() }
        .onAppear {
            if reduceMotion {
                curtain = 1
            } else {
                withAnimation(.timingCurve(0.55, 0, 0.25, 1, duration: 0.9).delay(0.15)) {
                    curtain = 1
                }
            }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(item: $progressTarget) { target in
            ReadingProgressSheet(target: target) { _ in await load() }
                // Still in the theatre: the sheet keeps the house lights down too.
                .preferredColorScheme(.dark)
        }
        .accessibilityAction(.escape) { onLeave() }
    }

    // MARK: - Layout around the crease

    /// The lit half and the stalls, either side of the crease. A crease across the
    /// middle (on a table) stacks one over the other; one down the middle (held like
    /// a book) puts them side by side. Without a reading — the moment before the
    /// regions arrive — the shape of the room decides.
    private func stage<Lit: View, Stalls: View>(
        in size: CGSize, fold: FoldLine?,
        @ViewBuilder lit: () -> Lit, @ViewBuilder stalls: () -> Stalls
    ) -> some View {
        let sideBySide = fold.map(\.isVertical) ?? (size.width > size.height)
        let split = fold.map { sideBySide ? $0.frame.minX : $0.frame.minY }
            ?? (sideBySide ? size.width : size.height) / 2
        let gap = fold.map { sideBySide ? $0.frame.width : $0.frame.height } ?? 0

        let layout = sideBySide
            ? AnyLayout(HStackLayout(spacing: 0))
            : AnyLayout(VStackLayout(spacing: 0))

        return layout {
            lit()
                .frame(width: sideBySide ? split : nil, height: sideBySide ? nil : split)
            Color.clear
                .frame(width: sideBySide ? gap : nil, height: sideBySide ? nil : gap)
            stalls()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func watching(_ show: ShowCard, in size: CGSize, fold: FoldLine?) -> some View {
        let showtime = Showtime(record: showtimeRecord, show: show)
        return stage(in: size, fold: fold) {
            marquee(art: show.poster) { wide in
                showSign(show, wide: wide)
            }
        } stalls: {
            boxOffice { ring in
                ShowtimeClock(showtime: showtime, diameter: ring)
            } actions: {
                clockButton(showtime, show: show)
                punchButton(show)
            } header: {
                queueBar(show)
            }
        }
    }

    private func readingDesk(_ live: ActiveSession, in size: CGSize, fold: FoldLine?) -> some View {
        let position = readingPosition(live)
        return stage(in: size, fold: fold) {
            marquee(art: live.cover) { wide in
                bookSign(live, position: position, wide: wide)
            }
        } stalls: {
            boxOffice { ring in
                SessionClock(session: live, position: position, diameter: ring)
            } actions: {
                Button {
                    progressTarget = ReadingProgressTarget(session: live, progress: position)
                } label: {
                    Label("End session", systemImage: "stop.fill")
                }
                .buttonStyle(.mqPrimary)
            } header: {
                modeSwitch
            }
        }
    }

    // MARK: - The marquee

    private func marquee<Sign: View>(art: String?,
                                     @ViewBuilder sign: @escaping (Bool) -> Sign) -> some View {
        GeometryReader { proxy in
            let wide = proxy.size.width > proxy.size.height * 1.15
            ZStack {
                // The art as the light in the room, blurred past recognition.
                RemoteImage(url: art)
                    .blur(radius: 40)
                    .opacity(0.45)
                    .overlay(RadialGradient(colors: [.clear, .black.opacity(0.85)],
                                            center: .center, startRadius: 40,
                                            endRadius: max(proxy.size.width, proxy.size.height) * 0.7))
                    .ignoresSafeArea()

                sign(wide)
                    .padding(.horizontal, wide ? 30 : 24)
                    .padding(.vertical, wide ? 26 : 28)
                    .background(Color.black.opacity(0.55), in: .rect(cornerRadius: 22))
                    .overlay {
                        MarqueeBulbs(houseLights: houseLights, animated: !reduceMotion)
                    }
                    .padding(wide ? 26 : 22)
                    .frame(maxWidth: wide ? 620 : 380)
                    .overlay {
                        if stamping {
                            WatchedStamp()
                                .transition(.scale(scale: 1.6).combined(with: .opacity))
                        }
                    }
                    .padding(18)
            }
        }
        // Not clipped: the glow is meant to spill a little across the crease, the
        // way the light from a sign falls on the seats in front of it.
    }

    private func signLayout(_ wide: Bool) -> AnyLayout {
        wide ? AnyLayout(HStackLayout(alignment: .center, spacing: 22))
             : AnyLayout(VStackLayout(alignment: .center, spacing: 16))
    }

    private func showSign(_ show: ShowCard, wide: Bool) -> some View {
        let episode = show.nextEp
        let layout = signLayout(wide)
        return layout {
            PosterArt(url: show.poster, radius: 10)
                .frame(width: wide ? 112 : 128)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 8)

            signText(eyebrow: "Now showing", title: show.displayTitle,
                     line: episode.map { e in e.title.map { "\(e.code)  \($0)" } ?? e.code },
                     detail: remainingLine(show), wide: wide)
        }
        .id(show.nextEp.map { "\(show.id)-\($0.season)-\($0.number)" } ?? "\(show.id)")
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    private func bookSign(_ live: ActiveSession, position: Int, wide: Bool) -> some View {
        let layout = signLayout(wide)
        return layout {
            CoverArt(url: live.cover, radius: 8)
                .frame(width: wide ? 112 : 128)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 8)

            signText(eyebrow: "Now reading", title: live.title ?? "Untitled",
                     line: positionLine(live, position: position),
                     detail: startedLine(live), wide: wide)
        }
        .accessibilityElement(children: .combine)
    }

    private func signText(eyebrow: String, title: String, line: String?,
                          detail: String?, wide: Bool) -> some View {
        VStack(alignment: wide ? .leading : .center, spacing: 8) {
            Text(eyebrow)
                .font(.mqEyebrow)
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.mqBrassOnArt.opacity(0.8))
            Text(title)
                .font(MarqueeFont.wordmark(wide ? 30 : 28, relativeTo: .largeTitle))
                .foregroundStyle(Color.mqInkOnArt)
                .multilineTextAlignment(wide ? .leading : .center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
            if let line {
                Text(line)
                    .font(.mqHeadline)
                    .foregroundStyle(Color.mqBrassOnArt)
                    .multilineTextAlignment(wide ? .leading : .center)
                    .lineLimit(2)
            }
            if let detail {
                Text(detail)
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkSoftOnArt)
            }
        }
        .frame(maxWidth: .infinity, alignment: wide ? .leading : .center)
    }

    private func remainingLine(_ show: ShowCard) -> String {
        var parts = ["\(show.remaining) left"]
        if let hours = show.hoursRemaining {
            parts.append(hours < 1 ? "\(Int(hours * 60)) min to go"
                                   : String(format: "%.1f hrs to go", hours))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - The box office

    private func boxOffice<Clock: View, Actions: View, Header: View>(
        @ViewBuilder clock: @escaping (CGFloat) -> Clock,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder header: @escaping () -> Header
    ) -> some View {
        GeometryReader { proxy in
            let wide = proxy.size.width > proxy.size.height * 1.25
            let ring = min(wide ? proxy.size.height * 0.58 : proxy.size.width * 0.5, 230)

            VStack(spacing: 0) {
                header()
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                Spacer(minLength: 8)

                let layout = wide
                    ? AnyLayout(HStackLayout(alignment: .center, spacing: 30))
                    : AnyLayout(VStackLayout(alignment: .center, spacing: 22))
                layout {
                    clock(ring)
                    VStack(spacing: 12) {
                        actions()
                    }
                    .frame(maxWidth: 280)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 8)

                Button("Leave the screening room", action: onLeave)
                    .buttonStyle(.mqQuiet)
                    .padding(.bottom, 6)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            // House lights: the further the phone folds, the darker the stalls.
            .background(Color.mqGround.opacity(0.94 - 0.5 * (1 - houseLights)))
        }
    }

    /// Watching or reading, when there's both — otherwise nothing to choose.
    @ViewBuilder
    private var modeSwitch: some View {
        if current != nil, reading != nil {
            Picker("Show", selection: Binding(get: { mode ?? .watching },
                                              set: { new in
                                                  withAnimation(.easeInOut(duration: 0.3)) { chosenMode = new }
                                              })) {
                Text("Watching").tag(Mode.watching)
                Text("Reading").tag(Mode.reading)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            .frame(height: 44)
        } else {
            Color.clear.frame(height: 44)
        }
    }

    private func queueBar(_ show: ShowCard) -> some View {
        let index = queue.firstIndex { $0.id == show.id } ?? 0
        return VStack(spacing: 6) {
            if reading != nil { modeSwitch }
            HStack {
                Button {
                    step(-1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .disabled(queue.count < 2)
                .accessibilityLabel("Previous show")

                Spacer()
                Text(queue.count > 1 ? "\(index + 1) of \(queue.count) up next" : "Up next")
                    .font(.mqCaption)
                    .monospacedDigit()
                    .foregroundStyle(Color.mqInkSoft)
                Spacer()

                Button {
                    step(1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(queue.count < 2)
                .accessibilityLabel("Next show")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.mqBrass)
        }
    }

    @ViewBuilder
    private func clockButton(_ showtime: Showtime, show: ShowCard) -> some View {
        if showtime.startedAt == nil {
            Button {
                startClock(for: show)
            } label: {
                Label("Start the clock", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.mqChip)
        } else {
            Button {
                showtimeRecord = ""
                UIApplication.shared.isIdleTimerDisabled = false
            } label: {
                Label("Reset the clock", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.mqChip)
        }
    }

    private func punchButton(_ show: ShowCard) -> some View {
        Button {
            Task { await punch(show) }
        } label: {
            Label("Mark watched", systemImage: "checkmark")
        }
        .buttonStyle(.mqPrimary)
        .disabled(punching)
        .accessibilityLabel(show.nextEp.map { "Mark \($0.code) of \(show.displayTitle) watched" }
                            ?? "Mark watched")
    }

    private var emptyHouse: some View {
        VStack(spacing: 14) {
            Text("The house is dark")
                .font(MarqueeFont.wordmark(28, relativeTo: .title))
                .foregroundStyle(Color.mqBrassOnArt)
            Text("Nothing's up next. Start a show and it'll play here.")
                .font(.mqBody)
                .foregroundStyle(Color.mqInkSoftOnArt)
                .multilineTextAlignment(.center)
            Button("Leave the screening room", action: onLeave)
                .buttonStyle(.mqChip)
                .padding(.top, 6)
        }
        .padding(30)
    }

    // MARK: - Reading

    /// Where you are now: the shelf's copy of the title if Home has it, else where
    /// the session began.
    private func readingPosition(_ live: ActiveSession) -> Int {
        let item = data.value?.reading?.first {
            $0.readingKind == live.readingKind && $0.id == live.itemID
        }
        return item?.progress ?? live.startPos ?? 0
    }

    private func positionLine(_ live: ActiveSession, position: Int) -> String {
        // Tracked as a percentage: say it the way the rest of the app does.
        if live.mode == "pct", let total = live.total, total > 0 {
            return "\(Int((Double(position) / Double(total) * 100).rounded()))% read"
        }
        let unit = live.readingKind == .book && live.mode != "chapters" ? "Page" : "Chapter"
        if let total = live.total, total > 0 { return "\(unit) \(position) of \(total)" }
        return "\(unit) \(position)"
    }

    private func startedLine(_ live: ActiveSession) -> String? {
        guard let started = MQTime.date(from: live.startedAt) else { return nil }
        return "Session started \(started.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Behaviour

    private func load() async {
        guard let client = session.client else { return }
        await data.load(force: true) { try await client.get("dashboard", as: Dashboard.self) }
        if session.me?.features?.tracksReading == true,
           let response = try? await client.get("reading/active", as: ActiveSessionsResponse.self) {
            sessions = response.sessions.sorted { $0.startedAt > $1.startedAt }
        } else {
            sessions = []
        }
        loaded = true
    }

    /// 1 with the phone propped normally, falling toward 0 as it folds further shut.
    private var houseLights: CGFloat {
        guard let degrees = hinge.degrees else { return 1 }
        return CGFloat(min(max((degrees - 70) / 60, 0), 1))
    }

    private func step(_ delta: Int) {
        guard !queue.isEmpty, let show = current,
              let index = queue.firstIndex(where: { $0.id == show.id }) else { return }
        let next = (index + delta + queue.count) % queue.count
        withAnimation(.easeInOut(duration: 0.3)) { showID = queue[next].id }
    }

    private func startClock(for show: ShowCard) {
        guard let episode = show.nextEp else { return }
        showtimeRecord = Showtime.record(show: show, episode: episode, start: Date())
        // A clock you can't see is no clock. Only while it's running, and only here.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func punch(_ show: ShowCard) async {
        guard let episode = show.nextEp, let client = session.client, !punching else { return }
        punching = true
        defer { punching = false }
        thud.toggle()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { stamping = true }
        showtimeRecord = ""
        UIApplication.shared.isIdleTimerDisabled = false

        do {
            let response: MarkResponse = try await client.post(
                "show/\(show.id)/watch",
                body: MarkEpisodeRequest(season: episode.season, number: episode.number),
                as: MarkResponse.self)
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.35)) {
                stamping = false
                data.mutate { dashboard in
                    guard let index = dashboard.upNext.firstIndex(where: { $0.id == show.id })
                    else { return }
                    if let updated = response.show, updated.nextEp != nil {
                        dashboard.upNext[index] = updated
                    } else {
                        dashboard.upNext.remove(at: index)
                    }
                }
            }
            if let earned = response.celebrate, !earned.isEmpty {
                session.enqueue(earned)
            }
        } catch {
            // Offline: queue it exactly as Watch Next would, and take the show off the
            // marquee — without the catalogue there's no knowing what's next.
            OfflineStore.shared.enqueue(PendingWrite(
                .markEpisode(showID: show.id, season: episode.season,
                             number: episode.number, unwatch: false, previous: false)))
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.35)) {
                stamping = false
                data.mutate { $0.upNext.removeAll { $0.id == show.id } }
            }
        }
        if let dashboard = data.value {
            WidgetBridge.publish(dashboard: dashboard, session: session)
        }
        session.noteWatched()
    }
}

// MARK: - Pieces

/// When this episode's clock was started. One record, kept across launches, so
/// unfolding to check something and folding back doesn't lose your place.
struct Showtime {
    var startedAt: Date?
    /// Episode length, when the show knows its own runtime.
    var runtime: TimeInterval?

    init(record: String, show: ShowCard) {
        runtime = show.avgRuntime.flatMap { $0 > 0 ? TimeInterval($0 * 60) : nil }
        let parts = record.split(separator: ":")
        guard parts.count == 4, let episode = show.nextEp,
              Int(parts[0]) == show.id, Int(parts[1]) == episode.season,
              Int(parts[2]) == episode.number, let start = Double(parts[3])
        else { return }
        startedAt = Date(timeIntervalSince1970: start)
    }

    static func record(show: ShowCard, episode: NextEpisode, start: Date) -> String {
        "\(show.id):\(episode.season):\(episode.number):\(start.timeIntervalSince1970)"
    }
}

/// Elapsed time against the episode's length, as a ring that fills.
private struct ShowtimeClock: View {
    let showtime: Showtime
    let diameter: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = showtime.startedAt.map { max(0, context.date.timeIntervalSince($0)) }
            let fraction = elapsed.flatMap { e in showtime.runtime.map { min(e / $0, 1) } } ?? 0
            let done = fraction >= 1

            ZStack {
                Circle()
                    .stroke(Color.mqBrassDim.opacity(0.5), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.mqBrassFill, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.mqBrassFill.opacity(done ? 0.8 : 0.3), radius: done ? 12 : 4)

                VStack(spacing: 4) {
                    Text(elapsed.map(Self.clock) ?? "0:00")
                        .font(MarqueeFont.body(diameter * 0.2, .bold, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(Color.mqInk)
                        .contentTransition(.numericText())
                    Text(caption(elapsed: elapsed, at: context.date, done: done))
                        .font(.mqCaption)
                        .foregroundStyle(done ? Color.mqBrass : Color.mqInkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(diameter * 0.14)
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(elapsed == nil ? "Showtime clock, not started"
                                : "\(Self.clock(elapsed ?? 0)) elapsed")
            .accessibilityValue(caption(elapsed: elapsed, at: context.date, done: done))
        }
    }

    private func caption(elapsed: TimeInterval?, at now: Date, done: Bool) -> String {
        guard let runtime = showtime.runtime else {
            return elapsed == nil ? "Start when the episode does" : "elapsed"
        }
        let minutes = Int(runtime / 60)
        guard let elapsed else { return "\(minutes) min episode" }
        if done { return "Credits should be rolling" }
        let ends = now.addingTimeInterval(runtime - elapsed)
        return "of \(minutes) min · ends \(ends.formatted(date: .omitted, time: .shortened))"
    }

    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
                         : String(format: "%d:%02d", minutes, seconds)
    }
}

/// A running reading session: the ring is how far through the book you are, the
/// numbers are how long you've been at it.
private struct SessionClock: View {
    let session: ActiveSession
    let position: Int
    let diameter: CGFloat

    var body: some View {
        let started = MQTime.date(from: session.startedAt)
        let fraction = session.total.map { $0 > 0 ? min(Double(position) / Double($0), 1) : 0 } ?? 0
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = started.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            ZStack {
                Circle()
                    .stroke(Color.mqBrassDim.opacity(0.5), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.mqBrassFill, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text(ShowtimeClock.clock(elapsed))
                        .font(MarqueeFont.body(diameter * 0.2, .bold, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(Color.mqInk)
                    Text(session.total == nil ? "this session"
                                              : "this session · \(Int((fraction * 100).rounded()))% through")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(diameter * 0.14)
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reading for \(ShowtimeClock.clock(elapsed))")
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent through")
        }
    }
}

/// Bulbs round the edge of the sign, chasing the way a real marquee does — in steps,
/// two lit and one dark, not a smooth glow. Stepping a few times a second is also what
/// lets this run for a whole episode without warming the phone.
private struct MarqueeBulbs: View {
    /// 1 house lights up … 0 down; the bulbs glow harder in the dark.
    var houseLights: CGFloat
    var animated: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: animated ? 0.32 : 3600)) { context in
            let step = animated ? Int(context.date.timeIntervalSinceReferenceDate / 0.32) : 0
            Canvas { canvas, size in
                let inset: CGFloat = 9
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
                let spacing: CGFloat = 19
                let points = Self.perimeter(of: rect, spacing: spacing)
                let glow = 0.35 + 0.45 * (1 - houseLights)
                for (index, point) in points.enumerated() {
                    let lit = !animated || (index + step) % 3 != 0
                    if lit {
                        canvas.fill(Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7,
                                                           width: 14, height: 14)),
                                    with: .color(Color.mqBrassOnArt.opacity(glow * 0.45)))
                    }
                    canvas.fill(Path(ellipseIn: CGRect(x: point.x - 3.2, y: point.y - 3.2,
                                                       width: 6.4, height: 6.4)),
                                with: .color(lit ? Color(red: 1, green: 0.93, blue: 0.72)
                                                 : Color.mqBrassOnArt.opacity(0.25)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Evenly spaced points round a rectangle, corner to corner, so the bulbs sit
    /// square on every edge instead of drifting.
    private static func perimeter(of rect: CGRect, spacing: CGFloat) -> [CGPoint] {
        func edge(from a: CGPoint, to b: CGPoint) -> [CGPoint] {
            let length = hypot(b.x - a.x, b.y - a.y)
            let count = max(1, Int((length / spacing).rounded()))
            return (0..<count).map { i in
                let t = CGFloat(i) / CGFloat(count)
                return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
        }
        let tl = CGPoint(x: rect.minX, y: rect.minY), tr = CGPoint(x: rect.maxX, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY), bl = CGPoint(x: rect.minX, y: rect.maxY)
        return edge(from: tl, to: tr) + edge(from: tr, to: br) + edge(from: br, to: bl) + edge(from: bl, to: tl)
    }
}

/// The ink stamp that lands on the sign when you mark an episode — the COMPLETE
/// stamp's little sibling.
private struct WatchedStamp: View {
    var body: some View {
        Text("Watched")
            .font(MarqueeFont.wordmark(34, relativeTo: .largeTitle))
            .foregroundStyle(Color.mqBrassOnArt)
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.65), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.mqBrassOnArt, lineWidth: 3))
            .rotationEffect(.degrees(-8))
            .accessibilityHidden(true)
    }
}
