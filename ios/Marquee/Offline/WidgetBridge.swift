import Foundation
import WidgetKit

/// The widgets can't authenticate on their own — the token is in the app's Keychain
/// and the server address is a secret. So the app leaves them a small snapshot in the
/// shared container whenever it has fresh data, and the extension only ever reads it.
///
/// The consequence is deliberate: a widget on a phone that has never paired shows a
/// "not paired yet" face and nothing else. It cannot leak an address it never had.
@MainActor
enum WidgetBridge {

    static func publish(dashboard: Dashboard, session: Session) {
        let upNext = dashboard.upNext.prefix(6).map { show in
            WidgetShow(id: show.id,
                       title: show.displayTitle,
                       poster: show.poster,
                       episodeCode: show.nextEp?.code,
                       episodeTitle: show.nextEp?.title,
                       season: show.nextEp?.season,
                       number: show.nextEp?.number,
                       watched: show.watched,
                       aired: show.aired)
        }
        let waiting = dashboard.upNext.reduce(0) { $0 + $1.remaining }

        let existing = OfflineStore.shared.readWidgetSnapshot()
        let snapshot = WidgetSnapshot(updatedAt: Date(),
                                      upNext: Array(upNext),
                                      reading: existing?.reading ?? [],
                                      episodesWaiting: waiting,
                                      isPaired: session.isPaired)
        OfflineStore.shared.writeWidgetSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        // The extension can't download anything itself, so the posters it will need
        // are fetched here and left in the shared container.
        Task.detached(priority: .utility) {
            await ArtCache.shared.warm(snapshot.upNext.map(\.poster))
            await MainActor.run { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    static func publish(reading shelves: ReadingShelves, session: Session) {
        let inProgress = (shelves.books.reading.map { ($0, ReadingKind.book) }
                          + shelves.manga.reading.map { ($0, ReadingKind.manga) })
            .prefix(6)
            .map { item, kind in
                WidgetRead(id: item.id, kind: kind.rawValue, title: item.displayTitle,
                           cover: item.cover, progress: item.progress ?? 0,
                           total: item.total(for: kind))
            }
        let existing = OfflineStore.shared.readWidgetSnapshot()
        let snapshot = WidgetSnapshot(updatedAt: Date(),
                                      upNext: existing?.upNext ?? [],
                                      reading: Array(inProgress),
                                      episodesWaiting: existing?.episodesWaiting ?? 0,
                                      isPaired: session.isPaired)
        OfflineStore.shared.writeWidgetSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        Task.detached(priority: .utility) {
            await ArtCache.shared.warm(snapshot.reading.map(\.cover))
            await MainActor.run { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// Unpairing has to clear the widgets too, or a poster from the household stays
    /// on the Home Screen after the app has forgotten everything.
    static func clear() {
        OfflineStore.shared.writeWidgetSnapshot(.empty)
        ArtCache.shared.clear()
        LiveDownloads.shared.endAll()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
