#if DEBUG
import SwiftUI

/// Every request state from sample data, films and shows on one page and books on
/// the other — for checking the design without Overseerr or Shelfmark. Debug builds
/// only; open it with `marquee://debug/requests`. Nothing here submits a request:
/// the sheets' buttons would, so leave them alone against a real server.
struct RequestStatesGallery: View {
    @State private var sheet: GallerySheet?
    @State private var confirming = false

    /// Every sheet the gallery can open, each with its sample details.
    enum GallerySheet: String, Identifiable {
        case seasons, filmNone, filmDownloading, filmOnPlex
        case bookDownloading, bookPick, bookDone, bookInCalibre
        var id: String { rawValue }
    }

    var body: some View {
        MarqueeScreen {
            FoldSpread(spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("Films and shows")
                    labelled("Nothing asked for") { RequestButton(status: RequestSamples.none) { sheet = .filmNone } }
                    labelled("Waiting for approval") { RequestButton(status: RequestSamples.pending) {} }
                    labelled("Approved, searching") { RequestButton(status: RequestSamples.processing) {} }
                    labelled("Downloading") { RequestButton(status: RequestSamples.downloading) { sheet = .filmDownloading } }
                    labelled("Show, partly on Plex") { RequestButton(status: RequestSamples.show) { sheet = .seasons } }
                    labelled("On Plex") { RequestButton(status: RequestSamples.available) { sheet = .filmOnPlex } }

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
                        Button("Show details") { sheet = .seasons }.buttonStyle(.mqChip)
                        Button("Film, not requested") { sheet = .filmNone }.buttonStyle(.mqChip)
                        Button("Film, downloading") { sheet = .filmDownloading }.buttonStyle(.mqChip)
                        Button("Film, on Plex") { sheet = .filmOnPlex }.buttonStyle(.mqChip)
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
                    SectionHeader("Book sheets")
                    ChipRow {
                        Button("Downloading") { sheet = .bookDownloading }.buttonStyle(.mqChip)
                        Button("Choose a copy") { sheet = .bookPick }.buttonStyle(.mqChip)
                        Button("Requested, in Calibre") { sheet = .bookDone }.buttonStyle(.mqChip)
                        Button("Already in Calibre") { sheet = .bookInCalibre }.buttonStyle(.mqChip)
                    }
                }
                .padding(.horizontal, MQ.gutter)
                .padding(.top, 10)
            }
        }
        .navigationTitle("Request states")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .seasons:
                SeasonRequestSheet(showID: 0, status: RequestSamples.show, sampleDetail: RequestSamples.showDetail) {}
            case .filmNone:
                MovieRequestSheet(movieID: 0, status: RequestSamples.none,
                                  sampleDetail: RequestDetail(status: "none", requests: [], downloads: [])) {}
            case .filmDownloading:
                MovieRequestSheet(movieID: 0, status: RequestSamples.downloading,
                                  sampleDetail: RequestSamples.filmDownloadingDetail) {}
            case .filmOnPlex:
                MovieRequestSheet(movieID: 0, status: RequestSamples.available,
                                  sampleDetail: RequestSamples.filmOnPlexDetail) {}
            case .bookDownloading:
                BookRequestDetailSheet(title: "Piranesi", request: BookRequestSamples.all[1], sample: true)
            case .bookPick:
                BookRequestDetailSheet(title: "The Dispossessed", request: BookRequestSamples.all[3], sample: true)
            case .bookDone:
                BookRequestDetailSheet(title: "Station Eleven", request: BookRequestSamples.all[4],
                                       inCalibre: BookRequestSamples.calibre, sample: true)
            case .bookInCalibre:
                BookRequestDetailSheet(title: "Station Eleven", inCalibre: BookRequestSamples.calibre, sample: true)
            }
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

extension RequestSamples {
    /// The `request/detail` payload, as the server sends it, so the sample goes
    /// through the real decoder and its keys.
    private static func detail(_ json: String) -> RequestDetail {
        (try? JSONDecoder().decode(RequestDetail.self, from: Data(json.utf8))) ?? RequestDetail()
    }

    private static func ago(_ seconds: TimeInterval) -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(-seconds))
    }

    static let filmOnPlexDetail = detail("""
    {"enabled": true, "status": "available",
     "requests": [{"id": 412, "status": "Completed", "requested_by": "Kaden", "created_at": "\(ago(9 * 86400))",
                   "is4k": true, "seasons": [], "mine": true, "can_delete": true}],
     "downloads": [],
     "file": {"resolution": "4K", "video": "HEVC", "audio": "EAC3 5.1", "hdr": "Dolby Vision",
              "container": "MKV", "size": "58.2 GB", "bitrate": "62.4 Mbps", "copies": 2}}
    """)

    static let filmDownloadingDetail = detail("""
    {"enabled": true, "status": "processing",
     "requests": [{"id": 418, "status": "Approved", "requested_by": "Sam", "created_at": "\(ago(5400))",
                   "is4k": false, "seasons": [], "mine": false, "can_delete": true},
                  {"id": 419, "status": "Waiting for approval", "requested_by": "Kaden",
                   "created_at": "\(ago(1200))", "is4k": true, "seasons": [], "mine": true, "can_delete": true}],
     "downloads": [{"title": "The.Salt.Road.2021.1080p.WEB-DL.DDP5.1.H.264-FLUX", "status": "downloading",
                    "size": "6.8 GB", "progress": 62, "eta": "00:14:40", "season": null, "episode": null}],
     "file": null}
    """)

    static let showDetail = detail("""
    {"enabled": true, "status": "partial",
     "requests": [{"id": 300, "status": "Completed", "requested_by": "Kaden", "created_at": "\(ago(40 * 86400))",
                   "is4k": false, "seasons": [1, 2], "mine": true, "can_delete": true},
                  {"id": 377, "status": "Approved", "requested_by": "Sam", "created_at": "\(ago(2 * 86400))",
                   "is4k": false, "seasons": [3], "mine": false, "can_delete": false},
                  {"id": 391, "status": "Waiting for approval", "requested_by": "Kaden",
                   "created_at": "\(ago(3600))", "is4k": false, "seasons": [4], "mine": true, "can_delete": true}],
     "downloads": [{"title": "Nightporter.S03E04.1080p.WEB-DL.DDP5.1.H.264-NTb", "status": "downloading",
                    "size": "2.1 GB", "progress": 38, "eta": "01:22:05", "season": 3, "episode": 4},
                   {"title": "Nightporter.S03E05.1080p.WEB-DL.DDP5.1.H.264-NTb", "status": "queued",
                    "size": "2.0 GB", "progress": null, "eta": null, "season": 3, "episode": 5}],
     "file": {"resolution": "1080p", "mixed": true, "episodes": 18, "size": "41.6 GB"}}
    """)
}

enum BookRequestSamples {
    static let calibre: CalibreCopy? = try? JSONDecoder().decode(CalibreCopy.self, from: Data("""
    {"id": 812, "title": "Station Eleven", "authors": ["Emily St. John Mandel"], "formats": ["EPUB", "MOBI"], "size": "1 MB"}
    """.utf8))

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
