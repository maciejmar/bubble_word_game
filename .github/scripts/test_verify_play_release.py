import unittest

from verify_play_release import (
    format_api_error,
    has_completed_internal_release,
    production_track_update,
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

    def test_api_error_summary_includes_stage_and_google_reason(self):
        class Response:
            status = 400

        class ApiError(Exception):
            resp = Response()
            content = (
                b'{"error":{"message":"Precondition check failed.","status":"FAILED_PRECONDITION",'
                b'"details":[{"reason":"CHANGES_ALREADY_IN_REVIEW","metadata":{"method":"edits.commit"}}]}}'
            )
            uri = "https://androidpublisher.googleapis.com/path?access_token=do-not-print"

        summary = format_api_error(ApiError("failure"), stage="commit edit")

        self.assertIn("commit edit", summary)
        self.assertIn("HTTP 400", summary)
        self.assertIn("CHANGES_ALREADY_IN_REVIEW", summary)
        self.assertIn("edits.commit", summary)
        self.assertNotIn("access_token", summary)

    def test_prepares_full_production_rollout_from_internal_release(self):
        internal = {
            "releases": [
                {
                    "name": "v1.0.31",
                    "status": "completed",
                    "versionCodes": ["32"],
                    "releaseNotes": [{"language": "en-US", "text": "New level"}],
                }
            ]
        }
        production = {"track": "production", "releases": [{"status": "completed", "versionCodes": [31]}]}

        update = production_track_update(32, internal, production)

        self.assertEqual(update["track"], "production")
        self.assertEqual(update["releases"][0]["status"], "completed")
        self.assertEqual(update["releases"][0]["versionCodes"], ["32"])
        self.assertNotIn("userFraction", update["releases"][0])
        self.assertEqual(update["releases"][0]["releaseNotes"], internal["releases"][0]["releaseNotes"])

    def test_finishes_matching_staged_production_rollout(self):
        internal = {"releases": [{"status": "completed", "versionCodes": [32]}]}
        production = {
            "track": "production",
            "releases": [{"status": "inProgress", "userFraction": 0.1, "versionCodes": ["32"]}],
        }

        update = production_track_update(32, internal, production)

        self.assertEqual(update["releases"][0]["status"], "completed")
        self.assertNotIn("userFraction", update["releases"][0])

    def test_is_idempotent_when_version_is_already_completed_in_production(self):
        internal = {"releases": [{"status": "completed", "versionCodes": [32]}]}
        production = {"track": "production", "releases": [{"status": "completed", "versionCodes": [32]}]}

        self.assertIsNone(production_track_update(32, internal, production))

    def test_refuses_to_overwrite_another_active_production_rollout(self):
        internal = {"releases": [{"status": "completed", "versionCodes": [32]}]}
        production = {"track": "production", "releases": [{"status": "inProgress", "versionCodes": [31]}]}

        with self.assertRaisesRegex(ValueError, "active production rollout"):
            production_track_update(32, internal, production)

    def test_refuses_to_promote_a_version_not_completed_on_internal(self):
        internal = {"releases": [{"status": "inProgress", "versionCodes": [32]}]}

        with self.assertRaisesRegex(ValueError, "completed Internal release"):
            production_track_update(32, internal, {"track": "production", "releases": []})


if __name__ == "__main__":
    unittest.main()
