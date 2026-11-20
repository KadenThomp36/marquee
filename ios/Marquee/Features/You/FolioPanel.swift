import SwiftUI
import UIKit

/// Folio — the household's own e-reader app on a Boox Palma — reporting to this
/// account. Per account, like everything in Settings: you switch it on for yourself
/// and pair your own reader, with the same six-digit code the phone app pairs with.
/// The reader shows up here the moment Folio registers.
struct FolioPanel: View {
    @Environment(Session.self) private var session

    @State private var state: FolioIntegration?
    @State private var pairing: PairCode?
    @State private var pairingUntil: Date?
    @State private var unpairing: FolioDevice?
    @State private var failed = false

    var body: some View {
        Panel(title: "Folio", symbol: "book.pages",
              note: "Your reader sends every sitting here — time, pages and chapters — and your shelf keeps up on its own.") {
            if let state {
                VStack(alignment: .leading, spacing: 0) {
                    Toggle(isOn: Binding(get: { state.enabled },
                                         set: { value in Task { await update(.init(enabled: value)) } })) {
                        label("Send reading from Folio",
                              state.enabled ? "On. Sittings from your reader land on your shelf."
                                            : "Off. Your reader keeps its sittings until you switch this back on.")
                    }
                    .tint(Color.mqBrassFill)

                    if state.enabled {
                        Divider().overlay(Color.mqHairline).padding(.vertical, 8)
                        Toggle(isOn: Binding(get: { state.autoCapture },
                                             set: { value in Task { await update(.init(autoCapture: value)) } })) {
                            label("Record sittings automatically",
                                  "Folio starts timing when you open a book and stops when you put it down. Off, you start each one on the reader.")
                        }
                        .tint(Color.mqBrassFill)

                        Divider().overlay(Color.mqHairline).padding(.top, 8)
                        devices(state.devices)
                        pairBlock
                    }
                }
            } else if failed {
                Text("Couldn’t reach your server for this.")
                    .font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            } else {
                Text("Loading…").font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            }
        }
        .task { await load() }
        .confirmationDialog("Unpair \(unpairing?.displayName ?? "this reader")?",
                            isPresented: .init(get: { unpairing != nil },
                                               set: { if !$0 { unpairing = nil } }),
                            titleVisibility: .visible) {
            Button("Unpair", role: .destructive) {
                if let device = unpairing { Task { await unpair(device) } }
                unpairing = nil
            }
        } message: {
            Text("It stops syncing until you pair it again. Sittings already here stay.")
        }
    }

    @ViewBuilder
    private func devices(_ devices: [FolioDevice]) -> some View {
        if devices.isEmpty {
            Text("No reader paired yet.")
                .font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                .padding(.vertical, 12)
        }
        ForEach(devices) { device in
            HStack(spacing: 11) {
                Image(systemName: "book.pages")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(device.signedIn == false ? Color.mqInkMuted : Color.mqChartAqua)
                    .frame(width: 34, height: 34)
                    .background(Color.mqPanelRaised, in: .rect(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .font(MarqueeFont.body(13.5, .semibold, relativeTo: .caption))
                        .foregroundStyle(Color.mqInk)
                    Text(detail(for: device))
                        .font(.mqCaption)
                        .foregroundStyle(device.signedIn == false ? Color.mqVelvet : Color.mqInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(device.sessionsSynced)")
                        .font(MarqueeFont.body(16, .heavy, relativeTo: .headline))
                        .foregroundStyle(Color.mqInk)
                        .monospacedDigit()
                    Text(device.sessionsSynced == 1 ? "sitting" : "sittings")
                        .font(MarqueeFont.body(10.5, .medium, relativeTo: .caption2))
                        .foregroundStyle(Color.mqInkMuted)
                }
                Menu {
                    Button("Unpair \(device.displayName)", role: .destructive) { unpairing = device }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mqInkMuted)
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Options for \(device.displayName)")
            }
            .padding(.vertical, 11)
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Unpair") { unpairing = device }
            Divider().overlay(Color.mqHairline)
        }
    }

    @ViewBuilder
    private var pairBlock: some View {
        if let pairing, let until = pairingUntil {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(Array(pairing.code.enumerated()), id: \.offset) { _, digit in
                        Text(String(digit))
                            .font(MarqueeFont.wordmark(30, relativeTo: .title))
                            .foregroundStyle(Color.mqBrass)
                            .frame(minWidth: 26)
                            .padding(.bottom, 3)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.mqBrassDim).frame(height: 2)
                            }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Pairing code \(pairing.code.map(String.init).joined(separator: " "))")
                Text("Type this into Folio when its setup asks for a Marquee pairing code. It works once.")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(until.timeIntervalSince(context.date)))
                    Text(left > 0 ? "Expires in \(left / 60):\(String(format: "%02d", left % 60))"
                                  : "That code expired.")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .monospacedDigit()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.mqPanelRaised, in: .rect(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mqBrassDim, lineWidth: 1) }
            .padding(.top, 12)
            .task(id: pairing.code) { await watchForReader(until: until) }
        } else {
            Button {
                Task { await startPairing() }
            } label: {
                Label("Pair a reader", systemImage: "plus")
            }
            .buttonStyle(.mqChip)
            .padding(.top, 12)
        }
    }

    private func label(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(MarqueeFont.body(13.5, .semibold, relativeTo: .caption))
                .foregroundStyle(Color.mqInk)
            Text(detail)
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detail(for device: FolioDevice) -> String {
        guard device.signedIn != false else { return "Signed out — unpair it, then pair it again" }
        var parts: [String] = []
        if let synced = device.lastSyncAt, !synced.isEmpty {
            parts.append("Synced \(MQTime.relative(synced))")
        } else {
            parts.append("Paired, waiting for its first sync")
        }
        if let version = device.appVersion, !version.isEmpty { parts.append("Folio \(version)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Server

    private func load() async {
        guard let client = session.client else { return }
        do {
            state = try await client.get("integrations/folio", as: FolioIntegration.self)
            failed = false
        } catch {
            failed = state == nil
        }
    }

    private func update(_ change: FolioIntegrationUpdate) async {
        guard let client = session.client else { return }
        if let next = try? await client.post("integrations/folio", body: change, as: FolioIntegration.self) {
            state = next
        }
    }

    private func unpair(_ device: FolioDevice) async {
        guard let client = session.client else { return }
        _ = try? await client.delete("integrations/folio/devices/\(device.id)", as: Empty.self)
        await load()
    }

    private func startPairing() async {
        guard let client = session.client,
              let code = try? await client.post("pair/start", as: PairCode.self) else { return }
        pairingUntil = Date().addingTimeInterval(TimeInterval(code.expiresIn ?? 300))
        pairing = code
    }

    /// Poll while the code is live; the reader appears the moment Folio registers.
    private func watchForReader(until: Date) async {
        let known = state?.devices.count ?? 0
        while Date() < until, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard let client = session.client,
                  let next = try? await client.get("integrations/folio", as: FolioIntegration.self)
            else { continue }
            if next.devices.count > known {
                state = next
                pairing = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return
            }
        }
        if !Task.isCancelled { pairing = nil }
    }
}
