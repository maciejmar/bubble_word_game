import unittest

from verify_play_release import (
    has_completed_internal_release,
    require_unused_higher_code,
    version_code_from_pubspec,
    version_codes_from_tracks,
)


class PlayVersionCodeTests(unittest.TestCase):
    def test_reads_build_number_from_pubspec(self):
        self.assertEqual(version_code_from_pubspec("name: game\nversion: 1.0.31+32\n"), 32)

    def test_collects_codes_across_all_tracks(self):
        tracks = {
            "tracks": [
                {"track": "internal", "releases": [{"versionCodes": ["30", 31]}]},
                {"track": "production", "releases": [{"versionCodes": ["29"]}]},
            ]
        }
        self.assertEqual(version_codes_from_tracks(tracks), {29, 30, 31})

    def test_accepts_a_new_code_above_every_track(self):
        require_unused_higher_code(32, {"tracks": [{"releases": [{"versionCodes": [31]}]}]})

    def test_rejects_a_code_already_present(self):
        with self.assertRaisesRegex(ValueError, "already contains"):
            require_unused_higher_code(31, {"tracks": [{"releases": [{"versionCodes": [31]}]}]})

    def test_rejects_a_code_lower_than_another_track(self):
        with self.assertRaisesRegex(ValueError, "must be higher"):
            require_unused_higher_code(31, {"tracks": [{"releases": [{"versionCodes": [32]}]}]})

    def test_requires_completed_internal_release(self):
        self.assertTrue(
            has_completed_internal_release(
                32, {"releases": [{"status": "completed", "versionCodes": ["32"]}]}
            )
        )
        self.assertFalse(
            has_completed_internal_release(
                32, {"releases": [{"status": "inProgress", "versionCodes": [32]}]}
            )
        )


if __name__ == "__main__":
    unittest.main()
