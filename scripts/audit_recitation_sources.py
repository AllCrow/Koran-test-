#!/usr/bin/env python3
"""Opt-in public-source audit; never run automatically by the app or normal CI.

Fetch three EveryAyah catalogues/checksum lists and 15 whole public MP3s.
Decode every selected file locally with ffmpeg; report metadata/hashes only.
No user recording input, model invocation, upload, or audio retained in Git.
Requires Python 3.10+, ffmpeg and ffprobe. This is not an iOS/rights/quality test.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ((1, 1), (2, 255), (9, 1), (112, 2), (114, 6))
MAX_MP3_BYTES = 32 * 1024 * 1024
MAX_PCM_BYTES = 20 * 1024 * 1024


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


class SameOriginHTTPS(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        old, new = urllib.parse.urlsplit(request.full_url), urllib.parse.urlsplit(new_url)
        require(new.scheme == "https" and new.netloc == old.netloc,
                "Cross-origin or non-HTTPS redirect refused")
        return super().redirect_request(request, fp, code, message, headers, new_url)


def fetch(url: str, maximum_bytes: int) -> tuple[bytes, dict]:
    require(urllib.parse.urlsplit(url).scheme == "https", "HTTPS is required")
    # Preserve environment proxy/CA settings and normal certificate verification.
    opener = urllib.request.build_opener(SameOriginHTTPS())
    request = urllib.request.Request(url, headers={
        "User-Agent": "Sakina-public-source-audit/1.0", "Accept-Encoding": "identity",
    })
    with opener.open(request, timeout=30) as response:
        require(response.status == 200, f"Expected whole response, got {response.status}")
        require(response.headers.get("Content-Encoding", "identity") == "identity",
                "Unexpected content encoding")
        declared = response.headers.get("Content-Length")
        if declared is not None:
            require(0 < int(declared) <= maximum_bytes, "Content-Length exceeds audit limit")
        data = response.read(maximum_bytes + 1)
        require(0 < len(data) <= maximum_bytes, "Response exceeds audit limit or is empty")
        if declared is not None:
            require(len(data) == int(declared), "Incomplete whole response")
        return data, {
            "url": url, "final_url": response.url, "http_status": response.status,
            "content_type": response.headers.get_content_type(),
            "content_length": int(declared) if declared is not None else None,
            "etag": response.headers.get("ETag"),
            "last_modified": response.headers.get("Last-Modified"),
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        }


class FileLinks(HTMLParser):
    def __init__(self, base_url: str):
        super().__init__()
        self.base_url = base_url
        self.files: set[str] = set()

    def handle_starttag(self, tag, attributes):
        if tag == "a":
            for key, value in attributes:
                if key == "href" and value:
                    resolved = urllib.parse.urljoin(self.base_url, value)
                    if resolved.startswith(self.base_url):
                        filename = resolved[len(self.base_url):]
                        if re.fullmatch(r"\d{6}\.mp3", filename):
                            self.files.add(filename)


def command(arguments: list[str]) -> str:
    result = subprocess.run(arguments, capture_output=True, text=True, timeout=90)
    require(result.returncode == 0, f"{Path(arguments[0]).name} failed: {result.stderr[:1000]}")
    return result.stdout


def decode(data: bytes, directory: Path) -> dict:
    mp3, pcm = directory / "source.mp3", directory / "decoded.pcm"
    mp3.write_bytes(data)
    streams = json.loads(command([
        "ffprobe", "-v", "error", "-protocol_whitelist", "file,pipe", "-f", "mp3",
        "-show_entries", "stream=codec_name,sample_rate,channels:format=duration",
        "-of", "json", str(mp3),
    ]))
    require(len(streams["streams"]) == 1, "Expected one audio stream")
    stream = streams["streams"][0]
    require(stream["codec_name"] == "mp3", "Source is not an MP3 stream")
    command([
        "ffmpeg", "-nostdin", "-v", "error", "-xerror", "-y",
        "-protocol_whitelist", "file,pipe", "-f", "mp3", "-i", str(mp3),
        "-map", "0:a:0", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le",
        "-f", "s16le", "-fs", str(MAX_PCM_BYTES + 1), str(pcm),
    ])
    waveform = pcm.read_bytes()
    require(0 < len(waveform) < MAX_PCM_BYTES and len(waveform) % 2 == 0,
            "Empty, odd-length or audit-limit PCM output; whole decode not established")
    require(any(waveform), "Decoded signal is entirely digital silence")
    return {
        "source_codec": stream["codec_name"],
        "source_sample_rate": int(stream["sample_rate"]),
        "source_channels": stream["channels"],
        "container_duration_seconds": float(streams["format"]["duration"]),
        "whole_file_decode": "ffmpeg -xerror, exit 0",
        "pcm_format": "mono s16le 16000 Hz", "pcm_bytes": len(waveform),
        "pcm_duration_seconds": len(waveform) / 32000,
        "pcm_sha256": hashlib.sha256(waveform).hexdigest(),
        "has_nonzero_pcm": True,
    }


def audit() -> dict:
    model_path = ROOT / "Sources/QuranCore/Models.swift"
    source = model_path.read_text(encoding="utf-8")
    reciter_source = source.split("public enum Reciter:", 1)[1]
    directories = dict(re.findall(r'case \.(\w+): return "([A-Za-z0-9_]+_128kbps)"', reciter_source))
    require(set(directories) == {"alafasy", "husary", "minshawi"}, "Review changed app reciter configuration")
    require('https://everyayah.com/data/\\(directoryName)/\\(filename)' in reciter_source,
            "Review changed app audio URL construction")
    require('String(format: "%03d%03d.mp3"' in reciter_source, "Review changed filename construction")
    index_path = ROOT / "App/Resources/Quran/index.json"
    counts = [surah["numberOfAyahs"] for surah in json.loads(index_path.read_bytes())["surahs"]]
    require(len(counts) == 114 and sum(counts) == 6236, "Unexpected bundled verse counts")
    expected = {f"{s:03}{a:03}.mp3" for s, count in enumerate(counts, 1) for a in range(1, count + 1)}
    catalogue, catalogue_meta = fetch("https://everyayah.com/data/recitations.js", 128 * 1024)
    upstream = json.loads(catalogue)
    require(upstream["ayahCount"] == counts, "Upstream/bundled ayah counts differ")
    report = {
        "schema_version": 1, "started_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "Public EveryAyah listings and 15 whole files via Linux HTTPS/proxy and ffmpeg; no iOS playback",
        "limitations": [
            "No human verification of reciter identity, Arabic content, Basmala, verse boundaries or tajweed.",
            "Only sampled files decoded; a complete filename listing does not establish complete playable coverage.",
            "Publisher MD5 is consistency metadata, not an authenticity signature or rights grant.",
            "No physical iPhone, AVFoundation, ATS, energy, word timings or licensing approval.",
        ],
        "app_source_sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
        "bundled_index_sha256": hashlib.sha256(index_path.read_bytes()).hexdigest(),
        "audit_script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "python": platform.python_version(), "platform": platform.system() + " " + platform.machine(),
        "ffmpeg": command(["ffmpeg", "-version"]).splitlines()[0],
        "catalogue": catalogue_meta, "reciters": [], "samples": [], "errors": [],
    }
    for reciter, folder in directories.items():
        entry = {"app_reciter": reciter, "app_directory": folder}
        try:
            matches = [v for v in upstream.values() if isinstance(v, dict) and v.get("subfolder") == folder]
            require(len(matches) == 1, "Reciter directory absent or ambiguous in source catalogue")
            entry["publisher_label"] = matches[0]
            base = f"https://everyayah.com/data/{folder}/"
            listing, entry["listing"] = fetch(base, 6 * 1024 * 1024)
            links = FileLinks(base)
            links.feed(listing.decode("utf-8"))
            entry["listed_mp3s"] = len(links.files)
            entry["missing_canonical_files"] = sorted(expected - links.files)
            entry["extra_numbered_files"] = sorted(links.files - expected)
            require(not entry["missing_canonical_files"], "Missing canonical filenames in listing")
            checksums, entry["publisher_checksum_list"] = fetch(base + "000_checksum.md5", 1024 * 1024)
            md5s = dict((name, digest.lower()) for digest, name in re.findall(
                r"(?m)^([a-fA-F0-9]{32})[ \t]+\*?(\d{6}\.mp3)[ \t]*\r?$", checksums.decode("utf-8")))
            for surah, ayah in SAMPLES:
                sample = {"app_reciter": reciter, "surah_id": surah, "ayah_number": ayah}
                try:
                    filename = f"{surah:03}{ayah:03}.mp3"
                    data, metadata = fetch(base + filename, MAX_MP3_BYTES)
                    sample.update(metadata)
                    require(metadata["content_type"] in ("audio/mpeg", "audio/mp3"), "Unexpected MP3 content type")
                    sample["md5"] = hashlib.md5(data, usedforsecurity=False).hexdigest()
                    sample["publisher_md5"] = md5s.get(filename)
                    require(sample["md5"] == sample["publisher_md5"], "Publisher MD5 mismatch or missing entry")
                    with tempfile.TemporaryDirectory(prefix="sakina-public-audio-") as temporary:
                        sample.update(decode(data, Path(temporary)))
                    print(f"Verified {reciter} {surah}:{ayah}: {len(data)} bytes, whole PCM decode", flush=True)
                except Exception as error:
                    sample["error"] = str(error)
                    report["errors"].append(f"{reciter} {surah}:{ayah}: {error}")
                report["samples"].append(sample)
        except Exception as error:
            entry["error"] = str(error)
            report["errors"].append(f"{reciter}: {error}")
        report["reciters"].append(entry)
    report["passed"] = not report["errors"] and len(report["samples"]) == 15
    report["completed_at_utc"] = datetime.now(timezone.utc).isoformat()
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="JSON metadata; no audio bytes")
    args = parser.parse_args()
    require(shutil.which("ffmpeg") is not None and shutil.which("ffprobe") is not None, "Install ffmpeg/ffprobe first")
    result = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Audit {'passed' if result['passed'] else 'failed'}: {args.output}")
    raise SystemExit(0 if result["passed"] else 1)
