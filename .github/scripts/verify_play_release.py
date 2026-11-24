#!/usr/bin/env python3
"""Check the Play versionCode before upload and verify Internal track afterward."""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any

PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher"


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


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check-unused", action="store_true")
    modes.add_argument("--verify-internal", action="store_true")
    args = parser.parse_args()
    try:
        check_unused() if args.check_unused else verify_internal()
    except Exception as exc:
        raise SystemExit(f"Google Play verification failed: {type(exc).__name__}: {exc}") from None
