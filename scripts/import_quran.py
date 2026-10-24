#!/usr/bin/env python3
"""Import pinned, verbatim Quran editions into lazy-loaded chapter resources.

No dependencies outside Python's standard library. Reproduce the current bundle:
  python3 scripts/import_quran.py --from-snapshots --retrieved-on 2026-10-24
Fetch a new upstream edition intentionally:
  python3 scripts/import_quran.py --refresh

An update must be reviewed before release. This script does not normalize, strip,
join, transliterate, or otherwise modify either source edition's Arabic strings.
"""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
from pathlib import Path
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "App" / "Resources" / "Quran"
SNAPSHOTS = DEST / "Provenance"
COUNTS = (
    7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,
    98,135,112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,
    75,85,54,53,89,59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,
    13,14,11,11,18,12,12,30,52,52,44,28,28,20,56,40,31,50,40,46,42,
    29,19,36,25,22,17,19,26,30,20,15,21,11,8,8,19,5,8,8,11,11,8,3,
    9,5,4,7,3,6,3,5,4,5,6,
)
EDITIONS = {
    "quran-uthmani": "https://api.alquran.cloud/v1/quran/quran-uthmani",
    "quran-tajweed": "https://api.alquran.cloud/v1/quran/quran-tajweed",
}
TANZIL_NOTICE = """Tanzil Quran Text
Copyright (C) 2007-2021 Tanzil Project
License: Creative Commons Attribution 3.0

This copy of the Quran text is carefully produced, highly verified and
continuously monitored by a group of specialists in Tanzil Project.

TERMS OF USE:
- Permission is granted to copy and distribute verbatim copies of this text,
  but CHANGING IT IS NOT ALLOWED.
- This Quran text can be used in any website or application, provided that
  its source (Tanzil Project) is clearly indicated, and a link is made to
  tanzil.net to enable users to keep track of changes.
- This copyright notice shall be included in all verbatim copies of the text,
  and shall be reproduced appropriately in all files derived from or containing
  substantial portion of this text.

Please check updates at: http://tanzil.net/updates/
Source: https://tanzil.net/ ; https://tanzil.net/docs/text_license
"""
NOTICE = TANZIL_NOTICE + """
App edition provenance
----------------------
The source of this app's complete Arabic editions is AlQuran Cloud / Islamic
Network, which attributes its Arabic text curation to sources including Tanzil
Project and Quran Academy. The upstream edition identifiers are quran-uthmani
and quran-tajweed. This attribution does not assert that every edition uses
identical orthography or annotations.

Every Arabic `text` and annotated `tajweed` string is copied verbatim from the
corresponding upstream edition. Metadata is reorganized into per-surah JSON;
neither Arabic string is normalized or rewritten. The two editions may differ in
orthography and invisible characters. Their Unicode offsets are not equivalent.
Tajweed colors must be parsed from the annotated edition itself.
In the supplied Uthmani snapshot, the Basmala is prefixed to ayah 1 of surahs
other than 1 and 9; the Tajweed snapshot places no such prefix there. A reader
may present that exact prefix separately as a Basmala header while preserving
every source character. The Basmala of surah 1 is itself ayah 1.

AlQuran Cloud terms: https://alquran.cloud/terms-and-conditions
Tajweed annotation guide: https://alquran.cloud/tajweed-guide
Tajweed annotations are distributed as supplied by AlQuran Cloud. Its terms
permit embedding/storing/displaying Arabic text and require faithful orthography
and acknowledgement of the sources; no independent annotation-specific license
grant was located. Review the upstream terms before publishing an update.

No tafsir, translation, or recitation audio is contained in these resources.
Audio is streamed separately; public availability does not establish its rights
for repackaging, commercial redistribution, or indefinite hosting availability.
Tafsir requested at runtime is separate source commentary, not Quran text.

The copyright notice applies to source curation. This development import is
mechanically checked for structure and exact source preservation; it has not
received independent scholarly certification.
"""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded_json(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "SakinaContentImporter/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        if response.status != 200:
            raise ValueError(f"Unexpected HTTP status {response.status}: {url}")
        return response.read(16 * 1024 * 1024 + 1)


def validate_source(payload: bytes, identifier: str) -> list[dict]:
    if len(payload) > 16 * 1024 * 1024:
        raise ValueError(f"Oversized source response: {identifier}")
    document = json.loads(payload)
    if document.get("code") != 200 or document.get("status") != "OK":
        raise ValueError(f"Upstream did not report success: {identifier}")
    edition = document["data"]["edition"]
    if edition.get("identifier") != identifier or edition.get("language") != "ar":
        raise ValueError(f"Wrong edition returned: {edition}")
    surahs = document["data"]["surahs"]
    if len(surahs) != 114 or len(COUNTS) != 114 or sum(COUNTS) != 6236:
        raise ValueError("Invalid canonical chapter inventory")
    next_global = 1
    for number, (chapter, expected_count) in enumerate(zip(surahs, COUNTS), 1):
        if chapter["number"] != number or len(chapter["ayahs"]) != expected_count:
            raise ValueError(f"Wrong surah number/count at {number}")
        for in_surah, ayah in enumerate(chapter["ayahs"], 1):
            if ayah["number"] != next_global or ayah["numberInSurah"] != in_surah:
                raise ValueError(f"Wrong ayah identity at {number}:{in_surah}")
            text = ayah["text"]
            if not isinstance(text, str) or not text or not any("\u0600" <= c <= "\u08ff" for c in text):
                raise ValueError(f"Missing Arabic text at {number}:{in_surah}")
            next_global += 1
    if next_global != 6237:
        raise ValueError("Wrong full Quran verse count")
    return surahs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--refresh", action="store_true", help="Fetch both live upstream editions")
    mode.add_argument("--from-snapshots", action="store_true", help="Use included compressed exact source snapshots")
    parser.add_argument("--retrieved-on", help="Snapshot retrieval date (YYYY-MM-DD); preserves existing date for snapshot replay")
    args = parser.parse_args()
    manifest_path = ROOT / "CONTENT_SOURCES.json"
    previous = json.loads(manifest_path.read_bytes()) if manifest_path.exists() else {}
    retrieval_date = args.retrieved_on or (previous.get("retrievedOn") if not args.refresh else None) or dt.date.today().isoformat()
    dt.date.fromisoformat(retrieval_date)

    payloads = {}
    chapters = {}
    for identifier, url in EDITIONS.items():
        snapshot = SNAPSHOTS / f"{identifier}.json.gz"
        if args.refresh or (not args.from_snapshots and not snapshot.exists()):
            payload = fetch(url)
        else:
            payload = gzip.decompress(snapshot.read_bytes())
        chapters[identifier] = validate_source(payload, identifier)
        payloads[identifier] = payload

    # Validate every source completely before replacing any application resource.
    files: dict[str, bytes] = {}
    metadata = []
    for chapter, colored in zip(chapters["quran-uthmani"], chapters["quran-tajweed"]):
        if chapter["number"] != colored["number"] or len(chapter["ayahs"]) != len(colored["ayahs"]):
            raise ValueError("Edition reference mismatch")
        surah = {
            "id": chapter["number"],
            "name": chapter["name"],
            "englishName": chapter["englishName"],
            "englishNameTranslation": chapter["englishNameTranslation"],
            "numberOfAyahs": len(chapter["ayahs"]),
            "revelationType": chapter["revelationType"],
        }
        metadata.append(surah)
        verses = []
        for ayah, annotated in zip(chapter["ayahs"], colored["ayahs"]):
            if (ayah["number"], ayah["numberInSurah"]) != (annotated["number"], annotated["numberInSurah"]):
                raise ValueError("Edition verse identity mismatch")
            verses.append({
                "id": ayah["number"], "surahID": surah["id"],
                "numberInSurah": ayah["numberInSurah"],
                "text": ayah["text"], "tajweed": annotated["text"],
            })
        files[f"{surah['id']:03}.json"] = encoded_json({"surah": surah, "ayahs": verses, "_notice": TANZIL_NOTICE})
    files["index.json"] = encoded_json({
        "version": 1, "source": "AlQuran Cloud — quran-uthmani / quran-tajweed; Tanzil Project: https://tanzil.net/",
        "surahs": metadata, "_notice": TANZIL_NOTICE,
    })
    files["NOTICE.txt"] = NOTICE.encode("utf-8")
    for identifier, payload in payloads.items():
        # Reproducible compression (no original filename, timestamp, or OS-specific header).
        files[f"Provenance/{identifier}.json.gz"] = gzip.compress(payload, compresslevel=9, mtime=0)

    for name, data in files.items():
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    manifest = {
        "schemaVersion": 1, "retrievedOn": retrieval_date, "surahCount": 114, "ayahCount": 6236,
        "resourceDirectory": "App/Resources/Quran",
        "sources": [{"edition": identifier, "url": url, "sha256": sha256(payloads[identifier]),
                     "snapshot": f"Provenance/{identifier}.json.gz"} for identifier, url in EDITIONS.items()],
        "preservation": "Arabic strings copied verbatim; no Unicode normalization, stripping, transliteration or alignment across editions.",
        "licenseURLs": ["https://tanzil.net/docs/text_license", "https://alquran.cloud/terms-and-conditions"],
        "annotationLicense": "No separate annotation-specific grant verified; supplied under AlQuran Cloud text terms. Review before distribution.",
        "excluded": ["tafsir", "translations", "recitation audio"],
        "files": {name: {"sha256": sha256(data), "bytes": len(data)} for name, data in sorted(files.items())},
    }
    manifest_path.write_bytes(encoded_json(manifest))
    total = sum(len(b) for b in files.values())
    print(f"Imported 114 surahs, 6236 ayahs, both Arabic editions; {len(files)} files, {total:,} bytes.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        print(f"Import failed: {error}", file=sys.stderr)
        raise SystemExit(1)
