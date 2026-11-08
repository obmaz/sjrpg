#!/usr/bin/env python3
"""Fetch only the official Android templates through a bounded HTTP Range ZIP.

No full archive is downloaded. ZipFile checks each extracted entry's CRC before
staging is committed. Source URLs are fixed official Godot release locations.
"""
import argparse
from collections import OrderedDict
import hashlib
import http.client
import io
import json
import os
from pathlib import Path
import re
import tempfile
import time
import urllib.error
import urllib.request
import zipfile

BLOCK_SIZE = 4 * 1024 * 1024
CACHE_BLOCKS = 2
ATTEMPTS = 4
TIMEOUT_SECONDS = 90
MAX_READ = 8 * 1024 * 1024
MAX_APK_BYTES = 512 * 1024 * 1024
ENTRY_NAMES = (
    "templates/android_debug.apk",
    "templates/android_release.apk",
    "templates/version.txt",
)
KNOWN_ARCHIVE_SIZE = {"4.7.2": 1281349702}


class FetchError(Exception):
    pass


class RangeFile(io.RawIOBase):
    """Seekable read-only remote file with at most 8 MiB of cached ZIP blocks."""

    def __init__(self, url, version):
        super().__init__()
        self.url = url
        self.position = 0
        self.length = None
        self.validator = None
        self.cache = OrderedDict()
        self.request_count = 0
        self.transferred = 0
        self._fetch(0, 0)
        expected_size = KNOWN_ARCHIVE_SIZE.get(version)
        if expected_size is not None and self.length != expected_size:
            raise FetchError(f"Official archive size changed: {self.length} != {expected_size}")

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            target = offset
        elif whence == io.SEEK_CUR:
            target = self.position + offset
        elif whence == io.SEEK_END:
            target = self.length + offset
        else:
            raise ValueError("Invalid seek mode")
        if target < 0:
            raise ValueError("Negative ZIP seek")
        self.position = target
        return target

    def _fetch(self, start, end):
        last_error = None
        for attempt in range(ATTEMPTS):
            try:
                headers = {
                    "User-Agent": "sjrpg-official-android-template-fetch/1",
                    "Accept-Encoding": "identity",
                    "Range": f"bytes={start}-{end}",
                }
                if self.validator:
                    headers["If-Range"] = self.validator
                request = urllib.request.Request(self.url, headers=headers)
                with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
                    self.request_count += 1
                    if response.status != 206:
                        raise FetchError(
                            f"Server ignored HTTP Range (status {response.status}); "
                            "refusing to download the full export-template archive"
                        )
                    match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", response.headers.get("Content-Range", ""))
                    if not match:
                        raise FetchError("Missing or invalid HTTP Content-Range")
                    actual_start, actual_end, total = map(int, match.groups())
                    if actual_start != start or actual_end != end or total <= end:
                        raise FetchError("HTTP Range response does not match the requested ZIP bytes")
                    if self.length is not None and total != self.length:
                        raise FetchError("Official archive changed between HTTP Range requests")
                    if response.headers.get("Content-Encoding", "identity").lower() != "identity":
                        raise FetchError("Unexpected content encoding for byte-addressed ZIP")
                    validator = response.headers.get("ETag") or response.headers.get("Last-Modified")
                    if self.validator and validator and validator != self.validator:
                        raise FetchError("Official archive identity changed between HTTP Range requests")
                    expected = end - start + 1
                    payload = response.read(expected + 1)
                    if len(payload) != expected:
                        raise OSError(f"Truncated HTTP Range: received {len(payload)} of {expected} bytes")
                    self.length = total
                    if validator and not validator.startswith("W/"):
                        self.validator = validator
                    self.transferred += len(payload)
                    return payload
            except urllib.error.HTTPError as error:
                if error.code not in (408, 429, 500, 502, 503, 504):
                    raise FetchError(f"Official release returned HTTP {error.code}") from error
                last_error = error
            except (urllib.error.URLError, OSError, http.client.HTTPException) as error:
                last_error = error
            if attempt + 1 < ATTEMPTS:
                time.sleep(min(0.5 * 2 ** attempt, 2.0))
        raise FetchError(f"HTTP Range failed after {ATTEMPTS} attempts: {last_error}")

    def _block(self, index):
        if index in self.cache:
            value = self.cache.pop(index)
            self.cache[index] = value
            return value
        start = index * BLOCK_SIZE
        end = min(start + BLOCK_SIZE, self.length) - 1
        if start >= self.length:
            return b""
        # Evict before fetching so the cache never holds three complete blocks.
        if len(self.cache) >= CACHE_BLOCKS:
            self.cache.popitem(last=False)
        value = self._fetch(start, end)
        self.cache[index] = value
        return value

    def read(self, size=-1):
        if size is None or size < 0:
            size = self.length - self.position
        if size > MAX_READ:
            raise FetchError(f"ZIP requested an unexpectedly large read ({size} bytes)")
        size = min(size, max(0, self.length - self.position))
        output = bytearray()
        while len(output) < size:
            index, within = divmod(self.position, BLOCK_SIZE)
            block = self._block(index)
            count = min(size - len(output), len(block) - within)
            if count <= 0:
                break
            output.extend(block[within:within + count])
            self.position += count
        return bytes(output)


def urls(version):
    filename = f"Godot_v{version}-stable_export_templates.tpz"
    return [
        f"https://github.com/godotengine/godot-builds/releases/download/{version}-stable/{filename}",
        f"https://github.com/godotengine/godot/releases/download/{version}-stable/{filename}",
    ]


def fetch(url, version, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    records = []
    with RangeFile(url, version) as remote:
        with zipfile.ZipFile(remote) as archive:
            infos = {}
            for name in ENTRY_NAMES:
                entries = [entry for entry in archive.infolist() if entry.filename == name]
                if len(entries) != 1:
                    raise FetchError("Missing or duplicate official ZIP entry: " + name)
                entry = entries[0]
                limit = 4096 if name.endswith("version.txt") else MAX_APK_BYTES
                if entry.is_dir() or entry.flag_bits & 1 or not 0 < entry.file_size <= limit:
                    raise FetchError("Invalid official ZIP entry: " + name)
                infos[name] = entry
            with tempfile.TemporaryDirectory(prefix=".android-templates-", dir=destination.parent) as temporary:
                staging = Path(temporary)
                for name in ENTRY_NAMES:
                    entry = infos[name]
                    target = staging / Path(name).name
                    digest = hashlib.sha256()
                    count = 0
                    with archive.open(entry) as source, target.open("wb") as output:
                        while True:
                            chunk = source.read(1024 * 1024)
                            if not chunk:
                                break  # ZipExtFile validates CRC before EOF is returned.
                            count += len(chunk)
                            if count > entry.file_size:
                                raise FetchError("ZIP entry exceeded its declared size: " + name)
                            output.write(chunk)
                            digest.update(chunk)
                        output.flush()
                        os.fsync(output.fileno())
                    if count != entry.file_size:
                        raise FetchError("Incomplete official ZIP entry: " + name)
                    records.append({"entry": name, "bytes": count, "sha256": digest.hexdigest(), "crc32": f"{entry.CRC:08x}"})
                marker = (staging / "version.txt").read_text(encoding="utf-8").strip()
                expected_version = version + ".stable"
                if marker != expected_version:
                    raise FetchError(f"Official template version mismatch: {marker!r} != {expected_version!r}")
                # All entries and CRCs are verified before existing templates change.
                destination.mkdir(parents=True, exist_ok=True)
                for name in ENTRY_NAMES:
                    basename = Path(name).name
                    os.replace(staging / basename, destination / basename)
        return {
            "version": version + ".stable",
            "source": url,
            "archive_bytes": remote.length,
            "range_bytes_downloaded": remote.transferred,
            "range_requests": remote.request_count,
            "cache_limit_bytes": BLOCK_SIZE * CACHE_BLOCKS,
            "destination": str(destination),
            "entries": records,
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", args.version):
        parser.error("--version must be an official stable numeric Godot version")
    failures = []
    for url in urls(args.version):
        try:
            report = fetch(url, args.version, args.destination.expanduser().resolve())
            print("ANDROID_TEMPLATES_FETCHED " + json.dumps(report, sort_keys=True), flush=True)
            return 0
        except (FetchError, OSError, ValueError, zipfile.BadZipFile, RuntimeError) as error:
            failures.append(f"{url}: {error}")
            print("ANDROID_TEMPLATE_SOURCE_FAILED " + failures[-1], flush=True)
    parser.exit(1, "Official Android template fetch failed:\n" + "\n".join(failures) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
