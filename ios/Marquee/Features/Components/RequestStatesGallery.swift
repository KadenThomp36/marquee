#if DEBUG
import SwiftUI

/// Every request state from sample data, films and shows on one page and books on
/// the other — for checking the design without Overseerr or Shelfmark. Debug builds
/// only; open it with `marquee://debug/requests`. Nothing here submits a request:
/// the sheets' buttons would, so leave them alone against a real server.
struct RequestStatesGallery: View {
    @State private var showingSeasons = false
    @State private var movieSheet: RequestStatus?
    @State private var confirming = false

    var body: some View {
        MarqueeScreen {
            FoldSpread(spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("Films and shows")
                    labelled("Nothing asked for") { RequestButton(status: RequestSamples.none) {} }
                    labelled("Waiting for approval") { RequestButton(status: RequestSamples.pending) {} }
                    labelled("Approved, searching") { RequestButton(status: RequestSamples.processing) {} }
                    labelled("Downloading") { RequestButton(status: RequestSamples.downloading) {} }
                    labelled("Show, partly on Plex") { RequestButton(status: RequestSamples.show) {} }
                    labelled("On Plex") { RequestButton(status: RequestSamples.available) {} }

                    SectionHeader("Season rows")
                    ForEach(RequestSamples.show.seasons ?? []) { season in
                        HStack {
                            Text("Season \(season.number)").font(.mqSub).foregroundStyle(Color.mqInk)
                            Spacer()
                            SeasonStateBadge(state: season)
                        }
                    }

                    SectionHeader("Sheets")
                    ChipRow {
                        Button("Season picker") { showingSeasons = true }.buttonStyle(.mqChip)
                        Button("Film, not requested") { movieSheet = RequestSamples.none }.buttonStyle(.mqChip)
                        Button("Film, downloading") { movieSheet = RequestSamples.downloading }.buttonStyle(.mqChip)
                        Button("Confirmation") { confirming = true }.buttonStyle(.mqChip)
                    }
                }
                .padding(.horizontal, MQ.gutter)
                .padding(.top, 10)
            } trailing: {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Books")
                    ForEach(BookRequestSamples.all) { request in
                        BookRequestCard(request: request) { _ in }
                    }
                    SectionHeader("On a book\u{2019}s page")
                    BookRequestCard(request: BookRequestSamples.all[1], compact: true) { _ in }
                }
                .padding(.horizontal, MQ.gutter)
                .padding(.top, 10)
            }
        }
        .navigationTitle("Request states")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSeasons) {
            SeasonRequestSheet(showID: 0, status: RequestSamples.show) {}
        }
        .sheet(item: $movieSheet) { status in
            MovieRequestSheet(movieID: 0, status: status) {}
        }
        .overlay {
            if confirming {
                RequestConfirmation(title: "Requested", detail: "Season 5 is on its way to Plex.")
                    .onTapGesture { confirming = false }
            }
        }
    }

    private func labelled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            content()
        }
    }
}

extension RequestStatus: Identifiable {
    public var id: String { "\(status ?? "")-\(download?.progress ?? -1)" }
}

enum BookRequestSamples {
    static let all: [BookRequest] = {
        let json = """
        [
          {"id": 9001, "title": "The Left Hand of Darkness", "author": "Ursula K. Le Guin", "year": "1969",
           "state": "finding", "message": "Looking for copies", "progress": 0, "requested_by": "Kaden",
           "mine": true, "created_at": "\(MQTime.stamp(Date().addingTimeInterval(-40)))"},
          {"id": 9002, "title": "Piranesi", "author": "Susanna Clarke", "year": 2020, "state": "downloading",
           "message": "Downloading from 6 peers", "progress": 64, "requested_by": "Kaden", "mine": true,
           "copy": {"title": "Piranesi - Susanna Clarke (epub)", "size": 2411724, "format": "epub", "seeders": 14},
           "created_at": "\(MQTime.stamp(Date().addingTimeInterval(-600)))"},
          {"id": 9003, "title": "A Memory Called Empire", "author": "Arkady Martine", "state": "importing",
           "progress": 99, "requested_by": "Sam", "mine": false,
           "created_at": "\(MQTime.stamp(Date().addingTimeInterval(-1800)))"},
          {"id": 9004, "title": "The Dispossessed", "author": "Ursula K. Le Guin", "state": "pick",
           "message": "That copy stalled. Pick another copy.", "requested_by": "Kaden", "mine": true,
           "created_at": "\(MQTime.stamp(Date().addingTimeInterval(-7200)))"},
          {"id": 9005, "title": "Station Eleven", "author": "Emily St. John Mandel", "state": "done",
           "progress": 100, "message": "In Calibre", "requested_by": "Sam", "mine": false,
           "created_at": "\(MQTime.stamp(Date().addingTimeInterval(-86000)))"},
          {"id": 9006, "title": "Gideon the Ninth", "author": "Tamsyn Muir", "state": "failed",
           "message": "No copies found (12 results, none were ebooks).", "requested_by": "Kaden", "mine": true,
           "created_at": "\(MQTime.stamp(Date().addingTimeInterval(-90000)))"},
          {"id": 9007, "title": "Klara and the Sun", "author": "Kazuo Ishiguro", "state": "cancelled",
           "message": "Cancelled", "requested_by": "Sam", "mine": false,
           "created_at": "\(MQTime.stamp(Date().addingTimeInterval(-3600)))"}
        ]
        """
        return (try? JSONDecoder().decode([BookRequest].self, from: Data(json.utf8))) ?? []
    }()
}

#Preview("Request states") {
    NavigationStack { RequestStatesGallery() }
}
#endif
