#!/usr/bin/env python3
"""Check the Play versionCode before upload and verify Internal track afterward."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any

PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher"


class PlayApiFailure(RuntimeError):
    def __init__(self, stage: str, cause: Exception):
        super().__init__(str(cause))
        self.stage = stage
        self.cause = cause


def version_code_from_pubspec(text: str) -> int:
    match = re.search(r"(?m)^version:\s*[^\s+]+\+(\d+)\s*$", text)
    if match is None:
        raise ValueError("pubspec.yaml must define version as name+buildNumber")
    return int(match.group(1))


def version_codes_from_tracks(tracks: dict[str, Any]) -> set[int]:
    codes: set[int] = set()
    for track in tracks.get("tracks", []):
        for release in track.get("releases", []):
            codes.update(int(code) for code in release.get("versionCodes", []))
    return codes


def track_readback_summary(tracks: dict[str, Any]) -> str:
    parts = []
    for track in sorted(tracks.get("tracks", []), key=lambda item: str(item.get("track", ""))):
        name = str(track.get("track", "unknown"))
        releases = track.get("releases", [])
        summary = ", ".join(
            f"{release.get('status')}:{'/'.join(str(code) for code in release.get('versionCodes', []))}"
            for release in releases
        ) or "empty"
        parts.append(f"{name}=[{summary}]")
    return "; ".join(parts) or "no tracks returned"


def format_api_error(error: Exception, stage: str | None = None) -> str:
    cause = getattr(error, "cause", error)
    stage = stage or getattr(error, "stage", None)
    status = getattr(getattr(cause, "resp", None), "status", None)
    message = ""
    reasons: list[str] = []
    methods: list[str] = []
    content = getattr(cause, "content", None)
    if content:
        try:
            payload = json.loads(content.decode("utf-8") if isinstance(content, bytes) else content)
            details = payload.get("error", {})
            message = str(details.get("message", ""))
            if details.get("status"):
                reasons.append(str(details["status"]))
            for item in details.get("errors", []):
                if item.get("reason"):
                    reasons.append(str(item["reason"]))
            for item in details.get("details", []):
                if item.get("reason"):
                    reasons.append(str(item["reason"]))
                method = item.get("metadata", {}).get("method")
                if method:
                    methods.append(str(method))
        except (AttributeError, TypeError, ValueError):
            message = ""

    parts = [f"{stage}:" if stage else "", type(cause).__name__]
    if status is not None:
        parts.append(f"HTTP {status}")
    if reasons:
        parts.append(", ".join(dict.fromkeys(reasons)))
    if methods:
        parts.append(", ".join(dict.fromkeys(methods)))
    if message:
        parts.append(message)
    elif not content:
        parts.append(str(cause))
    return " ".join(part for part in parts if part).replace("\r", " ").replace("\n", " ")[:500]


def require_unused_higher_code(expected: int, tracks: dict[str, Any]) -> None:
    existing = version_codes_from_tracks(tracks)
    if expected in existing:
        raise ValueError(f"Play already contains versionCode {expected}")
    highest = max(existing, default=0)
    if expected <= highest:
        raise ValueError(
            f"versionCode {expected} must be higher than the current Play maximum {highest}"
        )


def has_completed_internal_release(expected: int, track: dict[str, Any]) -> bool:
    return any(
        release.get("status") == "completed"
        and expected in {int(code) for code in release.get("versionCodes", [])}
        for release in track.get("releases", [])
    )


def production_track_update(
    expected: int,
    internal_track: dict[str, Any],
    production_track: dict[str, Any] | None,
) -> dict[str, Any] | None:
    internal_release = next(
        (
            release
            for release in internal_track.get("releases", [])
            if release.get("status") == "completed"
            and expected in {int(code) for code in release.get("versionCodes", [])}
        ),
        None,
    )
    if internal_release is None:
        raise ValueError(f"versionCode {expected} is not a completed Internal release")

    production_releases = (production_track or {}).get("releases", [])
    matching = [
        release
        for release in production_releases
        if expected in {int(code) for code in release.get("versionCodes", [])}
    ]
    other_active = [
        release
        for release in production_releases
        if release not in matching
        and release.get("status") in {"inProgress", "halted", "draft"}
    ]
    if other_active:
        raise ValueError("an active production rollout exists; refusing to overwrite it")

    if matching:
        existing = matching[0]
        status = existing.get("status")
        codes = {int(code) for code in existing.get("versionCodes", [])}
        if status == "completed":
            return None
        if status != "inProgress" or codes != {expected}:
            raise ValueError(
                f"versionCode {expected} already exists on production with status {status}"
            )
        release = dict(existing)
        release["versionCodes"] = [str(expected)]
        release["status"] = "completed"
        release.pop("userFraction", None)
        release.pop("countryTargeting", None)
    else:
        production_codes = version_codes_from_tracks(
            {"tracks": [production_track] if production_track else []}
        )
        highest = max(production_codes, default=0)
        if expected <= highest:
            raise ValueError(
                f"versionCode {expected} is not higher than production versionCode {highest}"
            )
        release = {"versionCodes": [str(expected)], "status": "completed"}
        if internal_release.get("name"):
            release["name"] = internal_release["name"]
        if internal_release.get("releaseNotes"):
            release["releaseNotes"] = internal_release["releaseNotes"]
        if internal_release.get("inAppUpdatePriority") is not None:
            release["inAppUpdatePriority"] = internal_release["inAppUpdatePriority"]

    return {"track": "production", "releases": [release]}


def play_service():
    from google.oauth2 import service_account
    from googleapiclient.discovery import build

    service_account_info = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
    credentials = service_account.Credentials.from_service_account_info(
        service_account_info, scopes=[PLAY_SCOPE]
    )
    return build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)


def with_edit(callback):
    package_name = os.environ["PACKAGE_NAME"]
    service = play_service()
    edit = service.edits().insert(packageName=package_name, body={}).execute()
    edit_id = edit["id"]
    try:
        return callback(service, package_name, edit_id)
    finally:
        service.edits().delete(packageName=package_name, editId=edit_id).execute()


def check_unused() -> None:
    expected = version_code_from_pubspec(Path("pubspec.yaml").read_text())

    def check(service, package_name, edit_id):
        tracks = service.edits().tracks().list(
            packageName=package_name, editId=edit_id
        ).execute()
        require_unused_higher_code(expected, tracks)
        track_summary = track_readback_summary(tracks)
        summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary_path:
            with open(summary_path, "a", encoding="utf-8") as summary_file:
                summary_file.write(
                    "### Play track inventory\n\n"
                    f"- Proposed versionCode: `{expected}`\n"
                    f"- Tracks: `{track_summary}`\n"
                )
        print(
            "::notice file=.github/scripts/verify_play_release.py,line=1,title=Play track inventory::"
            + track_summary
        )
        print(f"Play versionCode preflight passed: {expected} is unused and higher than existing tracks.")

    with_edit(check)


def verify_internal() -> None:
    expected = version_code_from_pubspec(Path("pubspec.yaml").read_text())

    def check(service, package_name, edit_id):
        track = service.edits().tracks().get(
            packageName=package_name, editId=edit_id, track="internal"
        ).execute()
        if not has_completed_internal_release(expected, track):
            raise ValueError(
                f"versionCode {expected} was not found as a completed Internal testing release"
            )
        print(f"Verified Google Play Internal testing contains completed versionCode {expected}.")

    with_edit(check)


def verify_track(track_name: str) -> None:
    expected = version_code_from_pubspec(Path("pubspec.yaml").read_text())

    def check(service, package_name, edit_id):
        track = service.edits().tracks().get(
            packageName=package_name, editId=edit_id, track=track_name
        ).execute()
        if not has_completed_internal_release(expected, track):
            raise ValueError(
                f"versionCode {expected} was not found as a completed release on track {track_name}"
            )
        print(f"Verified Google Play track {track_name} contains completed versionCode {expected}.")

    with_edit(check)


def preflight_production() -> None:
    expected = version_code_from_pubspec(Path("pubspec.yaml").read_text())

    def check(service, package_name, edit_id):
        tracks = service.edits().tracks().list(
            packageName=package_name, editId=edit_id
        ).execute()
        by_name = {track.get("track"): track for track in tracks.get("tracks", [])}
        update = production_track_update(
            expected, by_name.get("internal", {}), by_name.get("production")
        )
        readback = track_readback_summary(tracks)
        summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary_path:
            with open(summary_path, "a", encoding="utf-8") as summary_file:
                summary_file.write(
                    "### Google Play track readback\n\n"
                    f"- Proposed versionCode: `{expected}`\n"
                    f"- Current tracks: `{readback}`\n"
                )
        print(
            "::notice file=.github/scripts/verify_play_release.py,line=1,title=Play track readback::"
            + readback
        )
        if update is None:
            print(f"Production preflight passed: versionCode {expected} is already completed.")
        else:
            print(f"Production preflight passed: Internal versionCode {expected} can be promoted at 100%.")

    with_edit(check)


def promote_to_production() -> None:
    expected = version_code_from_pubspec(Path("pubspec.yaml").read_text())
    package_name = os.environ["PACKAGE_NAME"]
    service = play_service()
    edit_id = None
    committed = False
    stage = "create edit"
    try:
        edit = service.edits().insert(packageName=package_name, body={}).execute()
        edit_id = edit["id"]
        stage = "read tracks"
        tracks = service.edits().tracks().list(
            packageName=package_name, editId=edit_id
        ).execute()
        by_name = {track.get("track"): track for track in tracks.get("tracks", [])}
        internal_track = by_name.get("internal", {})
        production_track = by_name.get("production")
        update = production_track_update(expected, internal_track, production_track)
        if update is None:
            print(f"versionCode {expected} is already completed on production; no update needed.")
            return
        if production_track is None:
            stage = "create production track release"
            service.edits().tracks().create(
                packageName=package_name, editId=edit_id, body=update
            ).execute()
        else:
            stage = "update production track release"
            service.edits().tracks().update(
                packageName=package_name,
                editId=edit_id,
                track="production",
                body=update,
            ).execute()
        stage = "commit edit"
        service.edits().commit(packageName=package_name, editId=edit_id).execute()
        committed = True
        print(f"Promoted Internal versionCode {expected} to production at 100%.")
    except Exception as exc:
        raise PlayApiFailure(stage, exc) from exc
    finally:
        if not committed and edit_id is not None:
            try:
                service.edits().delete(packageName=package_name, editId=edit_id).execute()
            except Exception as cleanup_error:
                if sys.exc_info()[0] is None:
                    raise PlayApiFailure("delete uncommitted edit", cleanup_error) from cleanup_error
                print(
                    "Cleanup failed after the primary Play API error: "
                    + format_api_error(cleanup_error, "delete uncommitted edit"),
                    file=sys.stderr,
                )


def verify_production() -> None:
    expected = version_code_from_pubspec(Path("pubspec.yaml").read_text())

    def check(service, package_name, edit_id):
        track = service.edits().tracks().get(
            packageName=package_name, editId=edit_id, track="production"
        ).execute()
        if not has_completed_internal_release(expected, track):
            raise ValueError(
                f"versionCode {expected} was not found as a completed production release"
            )
        print(f"Verified Google Play production contains completed versionCode {expected}.")

    with_edit(check)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check-unused", action="store_true")
    modes.add_argument("--verify-internal", action="store_true")
    modes.add_argument("--verify-track", action="store_true")
    modes.add_argument("--preflight-production", action="store_true")
    modes.add_argument("--promote-production", action="store_true")
    modes.add_argument("--verify-production", action="store_true")
    args = parser.parse_args()
    try:
        if args.check_unused:
            check_unused()
        elif args.verify_internal:
            verify_internal()
        elif args.verify_track:
            verify_track(os.environ["PLAY_TRACK"])
        elif args.preflight_production:
            preflight_production()
        elif args.promote_production:
            promote_to_production()
        else:
            verify_production()
    except Exception as exc:
        summary = format_api_error(exc)
        print(
            "::error file=.github/scripts/verify_play_release.py,line=1,title=Google Play API error::"
            + summary
        )
        raise SystemExit(f"Google Play operation failed: {summary}") from None
