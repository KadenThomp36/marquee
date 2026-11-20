"""Book-request ranking, ported from Folio's RankReleasesTest. The release titles are real
Prowlarr results. Run with:  python3 -m unittest discover tests"""
import os
import sys
import tempfile
import unittest

os.environ.setdefault("MARQUEE_DATA", tempfile.mkdtemp())
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import main  # noqa: E402


def rel(title, size, seeders, fmt=""):
    return {"source_id": title, "title": title, "size_bytes": size, "format": fmt or None,
            "seeders": seeders, "protocol": "usenet" if seeders is None else "torrent"}


def best(title, authors, *rs):
    ranked = main.sm_rank_releases(list(rs), title, authors)
    return ranked[0][1]["title"] if ranked else None


DUNE = ("Dune", ["Frank Herbert"])
HAIL_MARY = ("Project Hail Mary", ["Andy Weir"])
PRIDE = ("Pride and Prejudice", ["Jane Austen"])
FRANK = ("Frankenstein; or, The Modern Prometheus", ["Mary Shelley"])


class RankReleases(unittest.TestCase):
    def test_dune_picks_the_novel_not_sequels_packs_or_movies(self):
        self.assertEqual("Dune by Frank Herbert EPUB", best(*DUNE,
            rel("All Dune books + short stories + extras ePUB", 20_800_000, 284),
            rel("Dune Audiobooks - m4b full collection 2023", 20_300_000_000, 187),
            rel("Dune by Frank Herbert EPUB", 949_000, 131),
            rel("Frank Herbert - Dune Messiah 2008 Retail EPUB eBook-BitBook", 375_000, 82),
            rel("Duna Parte 2 2024 Dune Part Two 1080p x264 DUAL AlienVolt", 3_500_000_000, 66),
            rel("Frank Herbert God Emperor Of Dune 2014 RETAiL ePub eBook-LiBRiCiDE", 1_100_000, 58),
            rel("Dune series by Brian Herbert EPUB", 11_100_000, 43)))

    def test_retail_group_release_of_the_right_book_is_acceptable(self):
        self.assertEqual("Frank Herbert - Dune 2003 Retail EPUB eBook-BitBook", best(*DUNE,
            rel("Frank Herbert - Dune 2003 Retail EPUB eBook-BitBook", 1_500_000, 98),
            rel("Frank Herbert - Children Of Dune 2008 Retail EPUB eBook-BitBook", 569_000, 76)))

    def test_hail_mary_prefers_epub_over_audiobook_and_azw3(self):
        self.assertEqual("Project Hail Mary by Andy Weir EPUB", best(*HAIL_MARY,
            rel("Andy Weir Project Hail Mary", 444_500_000, 268),
            rel("Project Hail Mary by Andy Weir AZW3", 4_600_000, 127),
            rel("Project Hail Mary by Andy Weir EPUB", 9_400_000, 387)))

    def test_pride_skips_variations_parodies_and_mp3(self):
        pick = best(*PRIDE,
            rel("[non fiction] Pride  Prejudice and Punditry  The Essential Shashi Tharoor by Shashi Tharoor MOB", 2_400_000, 14),
            rel("Tact  A Pride and Prejudice Variation by Jeannie Peneaux EPUB", 268_000, 7),
            rel("Pride Prejudice and Zombies (Trilogy) - spanikopita", 8_000_000, 5),
            rel("Pride and Prejudice, Jane Austen [MP3 with Text]", 614_000_000, 3),
            rel("Pride and Prejudice - Jane Austen - eBook [EPUB, MOBI]", 786_000, 9),
            rel("Jane Austen - Pride and Prejudice (Penguin Classics) (epub,mobi)", 3_000_000, 40))
        self.assertIn("Jane Austen", pick)

    def test_subtitles_dont_have_to_appear_in_the_release(self):
        self.assertEqual("Frankenstein", main.sm_main_title(FRANK[0]))
        self.assertEqual("Dungeon Crawler Carl", main.sm_main_title("Dungeon Crawler Carl: A LitRPG/Gamelit Adventure"))
        self.assertEqual("Frankenstein - Mary Shelley (epub)", best(*FRANK,
            rel("Frankenstein - Mary Shelley (epub)", 500_000, 20),
            rel("Frankenstein Audiobook - Mary Shelley", 300_000_000, 40)))

    def test_edition_packs_lose_to_a_single_copy(self):
        self.assertEqual("Frankenstein by Mary Shelley EPUB", best(*FRANK,
            rel("Mary Shelley - Frankenstein or The Modern Prometheus (3 editions ...", 22_100_000, 30),
            rel("Frankenstein by Mary Shelley EPUB", 450_000, 4)))

    def test_dead_torrents_and_wrong_books_are_rejected_or_last(self):
        self.assertIsNone(main.sm_score_release(rel("The Martian by Andy Weir EPUB", 2_000_000, 300), *HAIL_MARY))
        ranked = main.sm_rank_releases([rel("Dune by Frank Herbert EPUB", 949_000, 0),
                                        rel("Dune - Frank Herbert (epub)", 900_000, 12)], *DUNE)
        self.assertEqual("Dune - Frank Herbert (epub)", ranked[0][1]["title"])

    def test_loose_filter_drops_films_and_audiobooks(self):
        self.assertFalse(main.sm_looks_like_ebook(rel("Dune Part Two 1080p x264", 3_500_000_000, 66)))
        self.assertFalse(main.sm_looks_like_ebook(rel("Dune Audiobook m4b", 300_000_000, 9)))
        self.assertTrue(main.sm_looks_like_ebook(rel("Dune - Frank Herbert", 900_000, 3)))

    def test_cover_urls_unwrap_to_open_library(self):
        u = main.sm_cover_url("/api/covers/openlibrary_OL893414W?url=aHR0cHM6Ly9jb3ZlcnMub3BlbmxpYnJhcnkub3JnL2IvaWQvMTE0ODEzNTQtTC5qcGc=")
        self.assertEqual("https://covers.openlibrary.org/b/id/11481354-L.jpg", u)
        self.assertIsNone(main.sm_cover_url(None))

    def test_control_characters_in_status_json(self):
        self.assertEqual({"a": {"m": "two  lines"}}, main._sm_json('{"a": {"m": "two\n\tlines"}}'))


if __name__ == "__main__":
    unittest.main()
