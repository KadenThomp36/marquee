package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexDouble
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlin.math.roundToInt

enum class ReadingKind(val path: String, val unit: String, val unitShort: String) {
    BOOK("book", "pages", "p"), MANGA("manga", "chapters", "ch");

    companion object {
        fun of(raw: String?) = if (raw == "manga") MANGA else BOOK
    }
}

enum class ReadingState(val key: String, val label: String) {
    WANT("want", "Want to read"),
    READING("reading", "Reading"),
    FINISHED("finished", "Finished"),
    PAUSED("paused", "Paused"),
    DNF("dnf", "Didn't finish");

    companion object {
        fun of(raw: String?): ReadingState? = entries.firstOrNull { it.key == raw }
        val primary = listOf(WANT, READING, FINISHED)
        val secondary = listOf(PAUSED, DNF)
        val shelfOrder = listOf(READING, WANT, PAUSED, FINISHED, DNF)
    }
}

object ProgressMode {
    const val PAGES = "pages"
    const val PCT = "pct"
    const val CHAPTERS = "chapters"
}

@Serializable
data class ReadingShelves(val books: ReadingSections = ReadingSections(), val manga: ReadingSections = ReadingSections())

@Serializable
data class ReadingSections(
    val reading: List<ReadingItem> = emptyList(),
    val want: List<ReadingItem> = emptyList(),
    val finished: List<ReadingItem> = emptyList(),
    val paused: List<ReadingItem>? = null,
    val dnf: List<ReadingItem>? = null,
) {
    val all get() = reading + want + (paused ?: emptyList()) + finished + (dnf ?: emptyList())

    fun items(state: ReadingState): List<ReadingItem> = when (state) {
        ReadingState.READING -> reading
        ReadingState.WANT -> want
        ReadingState.FINISHED -> finished
        ReadingState.PAUSED -> paused ?: emptyList()
        ReadingState.DNF -> dnf ?: emptyList()
    }

    fun with(state: ReadingState, items: List<ReadingItem>) = when (state) {
        ReadingState.READING -> copy(reading = items)
        ReadingState.WANT -> copy(want = items)
        ReadingState.FINISHED -> copy(finished = items)
        ReadingState.PAUSED -> copy(paused = items)
        ReadingState.DNF -> copy(dnf = items)
    }

    /** Remove one item wherever it is; returns the new sections and where it was. */
    fun take(id: Int): Triple<ReadingSections, ReadingItem, Pair<ReadingState, Int>>? {
        for (state in ReadingState.shelfOrder) {
            val shelf = items(state)
            val i = shelf.indexOfFirst { it.id == id }
            if (i >= 0) return Triple(with(state, shelf.filterIndexed { j, _ -> j != i }), shelf[i], state to i)
        }
        return null
    }

    fun put(item: ReadingItem, state: ReadingState, index: Int = 0): ReadingSections {
        val shelf = items(state).toMutableList()
        shelf.add(index.coerceIn(0, shelf.size), item)
        return with(state, shelf)
    }
}

@Serializable
data class ReadingItem(
    val id: Int = 0,
    val title: String? = null,
    val cover: String? = null,
    val year: FlexInt = null,
    val state: String? = null,
    val progress: FlexInt = null,
    @SerialName("rating") val ratingValue: FlexDouble = null,
    val startedAt: String? = null,
    val finishedAt: String? = null,
    val mode: String? = null,
    val kind: String? = null,
    val pace: FlexDouble = null,
    val finishDays: FlexInt = null,
    val latestCh: FlexInt = null,
    val latestAt: String? = null,
    val lastReadAt: String? = null,
    val author: String? = null,
    val pages: FlexInt = null,
    val olid: String? = null,
    val hcId: FlexInt = null,
    val communityRating: FlexDouble = null,
    val series: String? = null,
    val chapters: FlexInt = null,
    val volumes: FlexInt = null,
    val status: String? = null,
    val origin: String? = null,
    val genres: String? = null,
    val seriesPos: FlexDouble = null,
) {
    val displayTitle get() = title ?: "Untitled"
    val readingState get() = ReadingState.of(state)
    val rating: Int? get() = ratingValue?.roundToInt()
    val readingKind get() = ReadingKind.of(kind)
    val railId get() = "${readingKind.path}:$id"
    val genreList get() = (genres ?: "").split(",").map { it.trim() }.filter { it.isNotEmpty() }

    val newChapters: Int get() = latestCh?.let { if (it > (progress ?: 0)) it - (progress ?: 0) else 0 } ?: 0

    val paceLine: String?
        get() {
            val behind = newChapters
            if (behind > 0) return "$behind new chapter${if (behind == 1) "" else "s"}"
            val d = finishDays ?: 0
            if (d > 0) return "~$d day${if (d == 1) "" else "s"} left at your pace"
            return null
        }

    fun total(kind: ReadingKind): Int? = if (kind == ReadingKind.BOOK) pages else chapters

    fun fraction(kind: ReadingKind): Float {
        val t = total(kind) ?: return 0f
        return if (t > 0) minOf(1f, (progress ?: 0).toFloat() / t) else 0f
    }

    val chapterPosition: Int
        get() {
            val p = pages ?: 0; val c = chapters ?: 0
            if (p <= 0 || c <= 0) return progress ?: 0
            return minOf(c, ((progress ?: 0).toDouble() / p * c).roundToInt())
        }

    fun incrementedProgress(kind: ReadingKind): Int {
        if (kind == ReadingKind.BOOK && mode == ProgressMode.CHAPTERS && pages != null && (chapters ?: 0) > 0) {
            return minOf(pages, ((chapterPosition + 1).toDouble() / chapters!! * pages).roundToInt())
        }
        return minOf(total(kind) ?: Int.MAX_VALUE, (progress ?: 0) + 1)
    }

    fun progressLabel(kind: ReadingKind): String {
        val t = total(kind)
        if (mode == ProgressMode.PCT && t != null && t > 0) return "${((progress ?: 0).toDouble() / t * 100).roundToInt()}%"
        if (kind == ReadingKind.BOOK && mode == ProgressMode.CHAPTERS && (chapters ?: 0) > 0) return "ch $chapterPosition/$chapters"
        return "${progress ?: 0}${t?.let { "/$it" } ?: ""} ${kind.unitShort}"
    }

    fun supportsIncrement(kind: ReadingKind) =
        kind == ReadingKind.MANGA || (mode == ProgressMode.CHAPTERS && chapters != null && pages != null)
}

@Serializable
data class ReadingDetail(
    val tracked: Boolean = false,
    val kind: String = "book",
    val item: ReadingDetailItem = ReadingDetailItem(),
    val state: ReadingStateRow? = null,
    val sessions: List<ReadingSession> = emptyList(),
    val household: List<HouseholdRead> = emptyList(),
    val reading: ReadingSummary? = null,
    val recentFolio: RecentFolio? = null,
) {
    val readingKind get() = ReadingKind.of(kind)
}

@Serializable
data class ReadingDetailItem(
    val id: Int? = null,
    val title: String? = null,
    val cover: String? = null,
    val year: FlexInt = null,
    val author: String? = null,
    val pages: FlexInt = null,
    val chapters: FlexInt = null,
    val volumes: FlexInt = null,
    val status: String? = null,
    val origin: String? = null,
    val series: String? = null,
    val seriesPos: FlexDouble = null,
    val communityRating: FlexDouble = null,
    val score: FlexDouble = null,
    val desc: String? = null,
    val genres: String? = null,
    val subjects: List<String>? = null,
    val toc: List<String>? = null,
    val chlist: List<@Serializable(MangaChapterSerializer::class) MangaChapter>? = null,
    val hcId: FlexInt = null,
    val slug: String? = null,
) {
    val displayTitle get() = title ?: "Untitled"
    val genreList get() = (genres ?: "").split(",").map { it.trim() }.filter { it.isNotEmpty() }
}

data class MangaChapter(val number: Int, val title: String) {
    val displayTitle get() = title.ifEmpty { "Chapter $number" }
}

private fun JsonElement.num(): Double? = (this as? JsonPrimitive)?.let { it.doubleOrNull ?: it.content.toDoubleOrNull() }
private fun JsonElement.str(): String = (this as? JsonPrimitive)?.content ?: ""

object MangaChapterSerializer : KSerializer<MangaChapter> {
    override val descriptor: SerialDescriptor = JsonArray.serializer().descriptor
    override fun deserialize(decoder: Decoder): MangaChapter {
        val a = (decoder as JsonDecoder).decodeJsonElement() as? JsonArray ?: return MangaChapter(0, "")
        return MangaChapter(a.getOrNull(0)?.num()?.toInt() ?: 0, a.getOrNull(1)?.takeIf { it is JsonPrimitive && it.isString }?.str() ?: "")
    }
    override fun serialize(encoder: Encoder, value: MangaChapter) =
        (encoder as JsonEncoder).encodeJsonElement(JsonArray(listOf(JsonPrimitive(value.number), JsonPrimitive(value.title))))
}

@Serializable
data class ReadingStateRow(
    val state: String? = null,
    val progress: FlexInt = null,
    @SerialName("rating") val ratingValue: FlexDouble = null,
    val startedAt: String? = null,
    val finishedAt: String? = null,
    val mode: String? = null,
) {
    val readingState get() = ReadingState.of(state)
    val rating: Int? get() = ratingValue?.roundToInt()
}

@Serializable
data class ReadingSession(
    val id: Int = 0,
    val date: String = "",
    val minutes: Int = 0,
    val from: Int = 0,
    val to: Int = 0,
    val source: String? = null,
    val sourceLabel: String? = null,
    val startFraction: FlexDouble = null,
    val endFraction: FlexDouble = null,
    /** Newer servers: chapters the sitting crossed, idle minutes Folio left out. */
    val chapters: List<String>? = null,
    val idleMinutes: FlexInt = null,
) {
    val isTimed get() = minutes >= 3
    val isFolio get() = source == "folio"
}

@Serializable
data class HouseholdRead(
    val username: String = "",
    val displayName: String? = null,
    val avatar: String? = null,
    val state: String? = null,
    @SerialName("rating") val ratingValue: FlexDouble = null,
) {
    val rating: Int? get() = ratingValue?.roundToInt()
    val stateLabel get() = state?.let { ReadingState.of(it)?.label ?: it } ?: ""
    val person get() = Person(username = username, displayName = displayName, avatar = avatar, isMe = false)
}

@Serializable
data class ActiveSession(
    val id: Int = 0,
    val kind: String = "book",
    val itemId: Int = 0,
    val startedAt: String = "",
    val startPos: FlexInt = null,
    val title: String? = null,
    val cover: String? = null,
    val pages: FlexInt = null,
    val chapters: FlexInt = null,
    val bookChapters: FlexInt = null,
    val mode: String? = null,
) {
    val readingKind get() = ReadingKind.of(kind)
    val total get() = if (readingKind == ReadingKind.BOOK) pages else chapters
}

@Serializable
data class ActiveSessionsResponse(val sessions: List<ActiveSession> = emptyList(), val recentFolio: RecentFolio? = null)

@Serializable
data class SessionStartResponse(val ok: Boolean? = null, val sessionId: Int? = null, val startedAt: String? = null)

@Serializable data class BookSearchResponse(val results: List<BookSearchResult> = emptyList(), val unavailable: FlexBool = null)

@Serializable
data class BookSearchResult(
    val hcId: Int = 0,
    val title: String? = null,
    val author: String? = null,
    val year: FlexInt = null,
    val pages: FlexInt = null,
    val cover: String? = null,
    val series: String? = null,
    val seriesPos: FlexDouble = null,
    val communityRating: FlexDouble = null,
    val ratingsCount: FlexInt = null,
    val genres: String? = null,
    val desc: String? = null,
    val slug: String? = null,
) {
    val displayTitle get() = title ?: "Untitled"
}

@Serializable data class MangaSearchResponse(val results: List<MangaSearchResult> = emptyList())

@Serializable
data class MangaSearchResult(
    val id: Int = 0,
    val title: String? = null,
    val cover: String? = null,
    val chapters: FlexInt = null,
    val volumes: FlexInt = null,
    val status: String? = null,
    val origin: String? = null,
    val year: FlexInt = null,
    val score: FlexDouble = null,
    val genres: List<String>? = null,
    val desc: String? = null,
) {
    val displayTitle get() = title ?: "Untitled"
}

@Serializable data class AddedResponse(val ok: Boolean? = null, val id: Int? = null)
@Serializable data class BookMatchesResponse(val current: Int? = null, val results: List<BookSearchResult> = emptyList())

@Serializable
data class BrowseResponse(
    val by: String = "author",
    val name: String = "",
    val header: BrowseHeader? = null,
    val shelf: List<ReadingItem> = emptyList(),
    val more: List<BookSearchResult> = emptyList(),
) {
    val isAuthor get() = by == "author"
}

@Serializable
data class BrowseHeader(
    val id: Int? = null,
    val name: String? = null,
    val slug: String? = null,
    val booksCount: FlexInt = null,
    val bio: String? = null,
    val image: String? = null,
)

@Serializable data class ReadingStatsResponse(val books: ReadingStats? = null, val manga: ReadingStats? = null)

@Serializable
data class ReadingStats(
    val totals: ReadingTotals = ReadingTotals(),
    val pace: FlexDouble = null,
    val avgSessionMin: FlexInt = null,
    val streak: Streak = Streak(),
    val daily30: List<@Serializable(DailyUnitsSerializer::class) DailyUnits>? = null,
    val monthly: List<@Serializable(MonthlyUnitsSerializer::class) MonthlyUnits>? = null,
    val yearly: List<@Serializable(MonthlyUnitsSerializer::class) MonthlyUnits>? = null,
    val clock: List<Int>? = null,
    val weekday: List<Int>? = null,
    val finished: FinishedCounts = FinishedCounts(),
    val readingNow: Int = 0,
    val fastest: FastestFinish? = null,
    val longest: LongestRead? = null,
    val bigDay: BigReadingDay? = null,
    val ratingHist: Map<String, Int>? = null,
) {
    val isEmpty get() = totals.all == 0 && totals.sessions == 0 && finished.all == 0
}

@Serializable
data class ReadingTotals(
    val week: Int = 0, val month: Int = 0, val year: Int = 0, val all: Int = 0,
    val hoursAll: Double = 0.0, val hoursMonth: Double = 0.0, val sessions: Int = 0, val timedSessions: Int = 0,
)

@Serializable data class FinishedCounts(val all: Int = 0, val year: Int = 0)
@Serializable data class FastestFinish(val title: String = "", val days: Int = 0)
@Serializable data class LongestRead(val title: String = "", val units: Int = 0)
@Serializable data class BigReadingDay(val date: String = "", val units: Int = 0)

data class DailyUnits(val date: String, val units: Double)
data class MonthlyUnits(val key: String, val units: Int)

object DailyUnitsSerializer : KSerializer<DailyUnits> {
    override val descriptor: SerialDescriptor = JsonArray.serializer().descriptor
    override fun deserialize(decoder: Decoder): DailyUnits {
        val a = (decoder as JsonDecoder).decodeJsonElement() as? JsonArray ?: return DailyUnits("", 0.0)
        return DailyUnits(a.getOrNull(0)?.str() ?: "", a.getOrNull(1)?.num() ?: 0.0)
    }
    override fun serialize(encoder: Encoder, value: DailyUnits) =
        (encoder as JsonEncoder).encodeJsonElement(JsonArray(listOf(JsonPrimitive(value.date), JsonPrimitive(value.units))))
}

object MonthlyUnitsSerializer : KSerializer<MonthlyUnits> {
    override val descriptor: SerialDescriptor = JsonArray.serializer().descriptor
    override fun deserialize(decoder: Decoder): MonthlyUnits {
        val a = (decoder as JsonDecoder).decodeJsonElement() as? JsonArray ?: return MonthlyUnits("", 0)
        return MonthlyUnits(a.getOrNull(0)?.str() ?: "", a.getOrNull(1)?.num()?.toInt() ?: 0)
    }
    override fun serialize(encoder: Encoder, value: MonthlyUnits) =
        (encoder as JsonEncoder).encodeJsonElement(JsonArray(listOf(JsonPrimitive(value.key), JsonPrimitive(value.units))))
}

object SeriesPosition {
    fun label(position: Double?): String? {
        if (position == null || position <= 0) return null
        return if (position == Math.rint(position)) "#${position.toInt()}" else "#${position.toString().trimEnd('0').trimEnd('.')}"
    }
}
