#!/usr/bin/env python3
"""Independently verify resource hashes, Quran IDs/counts, and exact source text.

Runs entirely offline. Exits nonzero for missing/untracked chapter resources,
modified content, edition mixing, or lost source attribution.
"""

from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
COUNTS = [
    7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,
    98,135,112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,
    75,85,54,53,89,59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,
    13,14,11,11,18,12,12,30,52,52,44,28,28,20,56,40,31,50,40,46,42,
    29,19,36,25,22,17,19,26,30,20,15,21,11,8,8,19,5,8,8,11,11,8,3,
    9,5,4,7,3,6,3,5,4,5,6,
]


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def main() -> int:
    manifest = json.loads((ROOT / "CONTENT_SOURCES.json").read_bytes())
    resources = ROOT / manifest["resourceDirectory"]
    expected_files = set(manifest["files"])
    found_files = {p.relative_to(resources).as_posix() for p in resources.rglob("*") if p.is_file() and p.name != ".DS_Store"}
    require(found_files == expected_files, f"Resource inventory differs: missing={expected_files-found_files}, extra={found_files-expected_files}")
    for relative, expected in manifest["files"].items():
        data = (resources / relative).read_bytes()
        require(len(data) == expected["bytes"], f"Wrong byte count: {relative}")
        require(hashlib.sha256(data).hexdigest() == expected["sha256"], f"SHA256 mismatch: {relative}")
        if relative.endswith((".json", ".txt")):
            data.decode("utf-8", errors="strict")

    originals = {}
    for source in manifest["sources"]:
        raw = gzip.decompress((resources / source["snapshot"]).read_bytes())
        require(hashlib.sha256(raw).hexdigest() == source["sha256"], f"Upstream snapshot hash mismatch: {source['edition']}")
        document = json.loads(raw)
        require(document["data"]["edition"]["identifier"] == source["edition"], "Snapshot edition identity mismatch")
        originals[source["edition"]] = document["data"]["surahs"]
    require(set(originals) == {"quran-uthmani", "quran-tajweed"}, "Missing edition source snapshot")

    index = json.loads((resources / "index.json").read_bytes())
    require(index["version"] == 1, "Unexpected index schema")
    require(len(index["surahs"]) == 114, "Expected 114 surahs")
    require("Tanzil" in index["source"] and "https://tanzil.net/" in index["source"], "Missing attribution link")
    require(len(COUNTS) == 114 and sum(COUNTS) == 6236, "Invalid independent verse inventory")
    next_global = 1
    for number, count in enumerate(COUNTS, 1):
        chapter = json.loads((resources / f"{number:03}.json").read_bytes())
        require(chapter["surah"] == index["surahs"][number-1], f"Index/chapter metadata mismatch: {number}")
        require(chapter["surah"]["id"] == number, f"Wrong surah identity: {number}")
        require(chapter["surah"]["numberOfAyahs"] == count and len(chapter["ayahs"]) == count, f"Wrong verse count: {number}")
        require("Copyright (C) 2007-2021 Tanzil Project" in chapter.get("_notice", ""), f"Missing source copyright: {number}")
        require("CHANGING IT IS NOT ALLOWED" in chapter["_notice"], f"Missing verbatim condition: {number}")
        for ayah_number, ayah in enumerate(chapter["ayahs"], 1):
            require((ayah["id"], ayah["surahID"], ayah["numberInSurah"]) == (next_global, number, ayah_number), f"Wrong verse reference: {number}:{ayah_number}")
            for field, edition in (("text", "quran-uthmani"), ("tajweed", "quran-tajweed")):
                original_chapter = originals[edition][number-1]
                original = original_chapter["ayahs"][ayah_number-1]
                require(original_chapter["number"] == number, f"Source chapter mismatch: {edition}/{number}")
                require(original["number"] == next_global and original["numberInSurah"] == ayah_number, f"Source verse mismatch: {edition}/{number}:{ayah_number}")
                # A UTF-8 byte comparison catches normalization and invisible-character changes.
                require(ayah[field].encode("utf-8") == original["text"].encode("utf-8"), f"Modified {edition} text: {number}:{ayah_number}")
            next_global += 1
    require(next_global == 6237, "Expected 6236 globally unique ayahs")
    require(manifest["ayahCount"] == 6236 and manifest["surahCount"] == 114, "Manifest count mismatch")
    print("Verified: 114 surahs, 6236 consecutive ayahs, both editions preserved byte-for-byte, all resource/source SHA256 hashes and source notices.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        print(f"Content verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
