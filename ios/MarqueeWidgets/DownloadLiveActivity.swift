import ActivityKit
import SwiftUI
import WidgetKit

/// The download, on the Lock Screen and in the Dynamic Island.
struct DownloadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color.mqGround)
                .activitySystemActionForegroundColor(Color.mqBrass)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WidgetPoster(url: context.attributes.poster)
                        .frame(width: 42)
                        .clipShape(.rect(cornerRadius: 6))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.finished ? "Ready" : "\(context.state.progress)%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mqBrass)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        if let subtitle = context.attributes.subtitle {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.mqInkMuted)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        ProgressView(value: context.state.fraction)
                            .tint(Color.mqBrassFill)
                        Text(statusLine(context.state))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.finished ? "checkmark.circle.fill"
                                                         : "arrow.down.circle")
                    .foregroundStyle(Color.mqBrass)
            } compactTrailing: {
                Text(context.state.finished ? "" : "\(context.state.progress)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mqBrass)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(Color.mqBrass)
            }
            .widgetURL(URL(string: "marquee://\(context.attributes.itemType)/\(context.attributes.itemID)"))
        }
    }

    private func lockScreen(_ context: ActivityViewContext<DownloadAttributes>) -> some View {
        HStack(spacing: 12) {
            WidgetPoster(url: context.attributes.poster)
                .frame(width: 46)
                .clipShape(.rect(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 5) {
                Text(context.state.finished ? "Ready to watch" : "Downloading")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.mqBrass)
                Text(context.attributes.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(1)
                ProgressView(value: context.state.fraction)
                    .tint(Color.mqBrassFill)
                Text(statusLine(context.state))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mqInkMuted)
            }

            Text(context.state.finished ? "✓" : "\(context.state.progress)%")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.mqBrass)
                .monospacedDigit()
        }
        .padding(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(context.attributes.title), \(statusLine(context.state))")
    }

    private func statusLine(_ state: DownloadAttributes.ContentState) -> String {
        if state.finished { return "On your Plex" }
        var parts: [String] = []
        if state.active > 1 { parts.append("\(state.active) files") }
        if let eta = state.eta, !eta.isEmpty { parts.append("\(eta) left") }
        return parts.isEmpty ? "In progress" : parts.joined(separator: " · ")
    }
}
