#!/usr/bin/env python3
"""Upload one local file (normally the debug APK) to Dropbox and verify its content hash.

Credentials come only from the environment and are never printed or stored:
  DROPBOX_APP_KEY, DROPBOX_APP_SECRET, DROPBOX_REFRESH_TOKEN   (preferred; short-lived access tokens are refreshed)
  DROPBOX_ACCESS_TOKEN                                         (fallback for a single manual run)

The app needs the files.content.write scope (and sharing.write for --link).
For an "App folder" app, --dest-dir is relative to that folder.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.dropboxapi.com/2"
CONTENT = "https://content.dropboxapi.com/2"
TOKEN_URL = "https://api.dropbox.com/oauth2/token"
CHUNK = 8 * 1024 * 1024  # Multiple of 4 MiB, which Dropbox recommends for upload sessions.
SINGLE_LIMIT = 100 * 1024 * 1024  # /files/upload accepts up to 150 MiB; stay well below it.
HASH_BLOCK = 4 * 1024 * 1024  # Dropbox content_hash block size.
TIMEOUT = 120


class DropboxError(RuntimeError):
    pass


def request(url: str, *, headers: dict[str, str], data: bytes | None = None) -> bytes:
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.read()
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", "replace")[:600]
        raise DropboxError(f"HTTP {err.code} from {urllib.parse.urlparse(url).path}: {body}") from None
    except urllib.error.URLError as err:
        raise DropboxError(f"Cannot reach {urllib.parse.urlparse(url).netloc}: {err.reason}") from None


def access_token() -> str:
    refresh = os.environ.get("DROPBOX_REFRESH_TOKEN", "")
    key = os.environ.get("DROPBOX_APP_KEY", "")
    secret = os.environ.get("DROPBOX_APP_SECRET", "")
    if refresh and key and secret:
        form = urllib.parse.urlencode(
            {"grant_type": "refresh_token", "refresh_token": refresh, "client_id": key, "client_secret": secret}
        ).encode()
        raw = request(TOKEN_URL, headers={"Content-Type": "application/x-www-form-urlencoded"}, data=form)
        token = json.loads(raw).get("access_token")
        if not token:
            raise DropboxError("Dropbox token response had no access_token")
        return token
    fallback = os.environ.get("DROPBOX_ACCESS_TOKEN", "")
    if fallback:
        return fallback
    raise DropboxError("Set DROPBOX_APP_KEY, DROPBOX_APP_SECRET and DROPBOX_REFRESH_TOKEN (or DROPBOX_ACCESS_TOKEN)")


def api(token: str, endpoint: str, body: dict) -> dict:
    raw = request(
        f"{API}/{endpoint}",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        data=json.dumps(body).encode(),
    )
    return json.loads(raw) if raw else {}


def content(token: str, endpoint: str, arg: dict, payload: bytes) -> dict:
    raw = request(
        f"{CONTENT}/{endpoint}",
        headers={
            "Authorization": f"Bearer {token}",
            "Dropbox-API-Arg": json.dumps(arg),
            "Content-Type": "application/octet-stream",
        },
        data=payload,
    )
    return json.loads(raw) if raw else {}


def content_hash(path: Path) -> str:
    """Dropbox content hash: SHA-256 over the SHA-256 digests of each 4 MiB block."""
    outer = hashlib.sha256()
    with path.open("rb") as handle:
        while block := handle.read(HASH_BLOCK):
            outer.update(hashlib.sha256(block).digest())
    return outer.hexdigest()


def upload(token: str, path: Path, dest: str, mode: str) -> dict:
    commit = {"path": dest, "mode": mode, "autorename": mode == "add", "mute": True}
    size = path.stat().st_size
    if size <= SINGLE_LIMIT:
        return content(token, "files/upload", commit, path.read_bytes())
    with path.open("rb") as handle:
        first = handle.read(CHUNK)
        session = content(token, "files/upload_session/start", {"close": False}, first)["session_id"]
        offset = len(first)
        while size - offset > CHUNK:
            block = handle.read(CHUNK)
            cursor = {"session_id": session, "offset": offset}
            content(token, "files/upload_session/append_v2", {"cursor": cursor, "close": False}, block)
            offset += len(block)
            print(f"  uploaded {offset / size:6.1%}", flush=True)
        tail = handle.read()
        cursor = {"session_id": session, "offset": offset}
        return content(token, "files/upload_session/finish", {"cursor": cursor, "commit": commit}, tail)


def shared_link(token: str, dest: str) -> str:
    try:
        return api(token, "sharing/create_shared_link_with_settings", {"path": dest})["url"]
    except DropboxError as err:
        if "shared_link_already_exists" not in str(err):
            raise
        links = api(token, "sharing/list_shared_links", {"path": dest, "direct_only": True}).get("links", [])
        if not links:
            raise
        return links[0]["url"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file", type=Path)
    parser.add_argument("--dest-dir", default="/sjrpg", help="Dropbox folder (default: /sjrpg)")
    parser.add_argument("--name", help="Dropbox file name (default: the local file name)")
    parser.add_argument("--mode", choices=("overwrite", "add"), default="overwrite",
                        help="overwrite replaces the same name; add auto-renames on conflict")
    parser.add_argument("--link", action="store_true", help="also create (or reuse) a shared link")
    args = parser.parse_args()

    if not args.file.is_file() or args.file.stat().st_size == 0:
        print(f"Missing or empty file: {args.file}", file=sys.stderr)
        return 2
    dest = "/" + "/".join(part for part in f"{args.dest_dir}/{args.name or args.file.name}".split("/") if part)
    try:
        token = access_token()
        print(f"Uploading {args.file} ({args.file.stat().st_size:,} bytes) -> Dropbox {dest}", flush=True)
        meta = upload(token, args.file, dest, args.mode)
        expected = content_hash(args.file)
        if meta.get("content_hash") != expected or meta.get("size") != args.file.stat().st_size:
            print(f"Dropbox verification failed for {meta.get('path_display', dest)}", file=sys.stderr)
            return 1
        print(f"verified: {meta['path_display']} size={meta['size']:,} content_hash={expected}")
        if args.link:
            try:
                print(f"link: {shared_link(token, meta['path_lower'])}")
            except DropboxError as err:
                print(f"upload ok, but no shared link: {err}", file=sys.stderr)
    except DropboxError as err:
        print(f"Dropbox upload failed: {err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
