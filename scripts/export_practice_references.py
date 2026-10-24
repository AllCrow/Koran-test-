#!/usr/bin/env python3
"""Export a separate, pinned model-compatible practice-reference edition.

Generate: python3 scripts/export_practice_references.py
Requires quran-transcript==0.6.4 installed from the verified PyPI wheel.
Verify an existing bundle offline, with only Python stdlib:
  python3 scripts/export_practice_references.py --verify

This does not edit the canonical reading edition or download model weights.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "Sources" / "QuranPractice" / "Resources" / "PracticeReferences"
SOURCE = "quran-transcript-0.6.4"
SCRIPT = "quran-transcript-0.6.4-uthmani-practice"
PACKAGE_VERSION = "0.6.4"
PACKAGE_WHEEL_SHA = "8db46fa8217514d44b81abfe548b92f7eb6d23988195ad2c193c7d69c13c50a9"
SOURCE_DATA_SHA = "76513995151fc5e4a47e07eceb61d3bd87db23a6be831a1e55ca689cc24b7f7f"
SOURCE_UTILS_SHA = "ce1b4fa976381f2a847137b3d1d493513e1d932d2decaf52d518d6f7b131dbf7"
MODEL_REPO = "obadx/muaalem-model-v3_2"
MODEL_REVISION = "01a1ef9fbe40d144ef845101e89ff924aed3fef5"
VOCAB_SHA = "dcbdac0162632df023002ca1cdd48e74f0f77a328d7f69503f9ff021afb19473"
COUNTS = [
    7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,
    98,135,112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,
    75,85,54,53,89,59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,
    13,14,11,11,18,12,12,30,52,52,44,28,28,20,56,40,31,50,40,46,42,
    29,19,36,25,22,17,19,26,30,20,15,21,11,8,8,19,5,8,8,11,11,8,3,
    9,5,4,7,3,6,3,5,4,5,6,
]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded_json(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def verify() -> None:
    index = json.loads((DEST / "index.json").read_bytes())
    require(index["version"] == 1 and index["source"] == SOURCE and index["script"] == SCRIPT, "Wrong practice reference identity")
    require(index["package_wheel_sha256"] == PACKAGE_WHEEL_SHA, "Unexpected package pin")
    require(index["source_data_sha256"] == SOURCE_DATA_SHA, "Unexpected package dataset pin")
    require(index["source_utils_sha256"] == SOURCE_UTILS_SHA, "Unexpected package API pin")
    require(index["model_revision"] == MODEL_REVISION, "Unexpected model revision")
    require(sha256((DEST / "model-vocab.json").read_bytes()) == VOCAB_SHA, "Unexpected model vocabulary")
    expected_files = set(index["hashes"]) | {"index.json"}
    actual_files = {p.relative_to(DEST).as_posix() for p in DEST.rglob("*") if p.is_file()}
    require(expected_files == actual_files, "Practice file inventory differs")
    for name, expected in index["hashes"].items():
        raw = (DEST / name).read_bytes()
        require(sha256(raw) == expected, f"Practice SHA256 mismatch: {name}")
        raw.decode("utf-8", errors="strict")
    require(index["surahs"] == [{"id": n, "count": count} for n, count in enumerate(COUNTS, 1)], "Wrong practice surah counts")
    count = 0
    for sid, expected_count in enumerate(COUNTS, 1):
        chapter = json.loads((DEST / f"{sid:03}.json").read_bytes())
        require(chapter["surah_id"] == sid and len(chapter["ayahs"]) == expected_count, f"Wrong practice chapter: {sid}")
        require(chapter["_source"] == SOURCE, f"Missing chapter source: {sid}")
        require("MIT License" in chapter["_notice"] and "Tanzil Quran Text" in chapter["_notice"], f"Missing chapter notices: {sid}")
        basmala = chapter["basmala"]
        require((basmala is None) == (sid in (1, 9)), f"Wrong Basmala inventory: {sid}")
        for ayah_number, ayah in enumerate(chapter["ayahs"], 1):
            require(ayah["ayah_number"] == ayah_number and isinstance(ayah["text"], str) and bool(ayah["text"]), f"Wrong practice verse: {sid}:{ayah_number}")
            require("\ufeff" not in ayah["text"], f"Unexpected BOM: {sid}:{ayah_number}")
            count += 1
    require(count == index["ayah_count"] == 6236, "Wrong full practice verse count")
    require(index["audit"]["all_ayahs_passed"] == 6236 and index["audit"]["unsupported_phonemes"] == [], "Practice export lacks full vocabulary audit")
    print("Verified practice references: 114 surahs, 6236 ayahs, source pins, notices and all file SHA256 hashes.")


def generate() -> None:
    require(importlib.metadata.version("quran-transcript") == PACKAGE_VERSION, "Install exactly quran-transcript==0.6.4")
    import quran_transcript
    from quran_transcript import Aya, MoshafAttributes, quran_phonetizer

    package_dir = Path(quran_transcript.__file__).resolve().parent
    raw_source = (package_dir / "quran-script" / "quran-uthmani-imlaey.json").read_bytes()
    require(sha256(raw_source) == SOURCE_DATA_SHA, "Installed package dataset differs from verified wheel")
    require(sha256((package_dir / "utils.py").read_bytes()) == SOURCE_UTILS_SHA, "Installed package API differs from verified wheel")
    distribution = importlib.metadata.distribution("quran-transcript")
    license_file = next(f for f in distribution.files if str(f).endswith("/licenses/LICENSE"))
    license_text = distribution.locate_file(license_file).read_text(encoding="utf-8")
    require("MIT License" in license_text and "Tanzil Quran Text" in license_text, "Missing upstream software/text licenses")

    vocab_raw = (DEST / "model-vocab.json").read_bytes()
    require(sha256(vocab_raw) == VOCAB_SHA, "Unexpected pinned vocabulary; do not download mutable model metadata")
    allowed = set(json.loads(vocab_raw)["phonemes"])
    settings = MoshafAttributes(rewaya="hafs", madd_monfasel_len=4, madd_mottasel_len=4, madd_mottasel_waqf=4, madd_aared_len=4)
    files: dict[str, bytes] = {"model-vocab.json": vocab_raw}
    base = Aya(1, 1)
    audit_count = 0
    basmala_audit_count = 0
    for sid, expected_count in enumerate(COUNTS, 1):
        base.set(sid, 1)
        info = base.get()
        basmala = info.bismillah_uthmani
        require(info.num_ayat_in_sura == expected_count, f"Unexpected package chapter count: {sid}")
        require((basmala is None) == (sid in (1, 9)), f"Unexpected package Basmala: {sid}")
        verses = []
        for ayah_number in range(1, expected_count + 1):
            base.set(sid, ayah_number)
            # Export the public API's exact training-style reference. Do not trim,
            # normalize, transliterate, or substitute characters from the reader edition.
            text = base.get().uthmani
            phonetic = quran_phonetizer(text, settings, remove_spaces=True)
            unsupported = set(phonetic.phonemes) - allowed
            require(not unsupported, f"Unsupported phonemes for {sid}:{ayah_number}: {unsupported!r}")
            require(len(phonetic.mappings) == len(text), f"Mapping/text mismatch: {sid}:{ayah_number}")
            if ayah_number == 1 and basmala is not None:
                joined = basmala + " " + text
                combined = quran_phonetizer(joined, settings, remove_spaces=True)
                require(not (set(combined.phonemes) - allowed), f"Unsupported opening phrase: {sid}")
                require(len(combined.mappings) == len(joined), f"Opening phrase mapping mismatch: {sid}")
                basmala_audit_count += 1
            verses.append({"ayah_number": ayah_number, "text": text})
            audit_count += 1
        files[f"{sid:03}.json"] = encoded_json({
            "surah_id": sid, "basmala": basmala, "ayahs": verses,
            "_source": SOURCE, "_notice": license_text,
        })

    files["LICENSE-quran-transcript.txt"] = license_text.encode("utf-8")
    files["NOTICE.txt"] = f"""Sakina practice reference edition
Source identifier: {SOURCE}
Script identifier: {SCRIPT}

These references are exported verbatim from Aya(surah, ayah).get().uthmani in
the verified quran-transcript==0.6.4 PyPI wheel. They are separate from Sakina's
canonical reading resources; their orthography, marks and Unicode positions
are not interchangeable with the reading edition or the colored Tajweed edition.

Each chapter's basmala field is exported verbatim from the same source API's
bismillah_uthmani value. It is null for chapters 1 and 9. The Basmala of chapter 1
is itself verse 1. For other chapters, basmala is separate from verse text.
An optional joined reference uses the exact basmala + one ASCII space + verse 1.
Vocabulary compatibility of that joining does not establish that every pause
between the Basmala and verse is acoustically equivalent; this needs evaluation.

No source string is rewritten by this exporter. The public source API supplies
a training-style Quran representation without the full reader's pause/hizb/sajda
mark set. The included software and original text retain the complete MIT and
Tanzil CC BY 3.0 notices in LICENSE-quran-transcript.txt and every chapter file.
Source project: https://github.com/obadx/quran-transcript
Source package: https://pypi.org/project/quran-transcript/0.6.4/
Tanzil source: https://tanzil.net/

The small model-vocab.json is copied from {MODEL_REPO}
at revision {MODEL_REVISION}; its pinned model card declares MIT.
It is metadata only. No model weights are contained in this dataset.

The exporter validates the complete Quran inventory and all expected phonemes
against the pinned vocabulary with one explicit Hafs configuration. It does not
run speech recognition or certify pronunciation-feedback accuracy.
""".encode("utf-8")
    index = {
        "version": 1, "source": SOURCE, "script": SCRIPT,
        "package_version": PACKAGE_VERSION, "package_wheel_sha256": PACKAGE_WHEEL_SHA,
        "source_data_sha256": SOURCE_DATA_SHA, "source_utils_sha256": SOURCE_UTILS_SHA,
        "model_repository": MODEL_REPO, "model_revision": MODEL_REVISION,
        "ayah_count": audit_count,
        "surahs": [{"id": n, "count": count} for n, count in enumerate(COUNTS, 1)],
        "audit": {
            "all_ayahs_passed": audit_count, "opening_phrases_passed": basmala_audit_count,
            "unsupported_phonemes": [],
            "moshaf": {"rewaya": "hafs", "madd_monfasel_len": 4, "madd_mottasel_len": 4, "madd_mottasel_waqf": 4, "madd_aared_len": 4},
            "scope": "Phoneticizer and mapping compatibility only; no acoustic model execution.",
        },
        "hashes": {name: sha256(data) for name, data in sorted(files.items())},
    }
    # No output is replaced until the complete dataset and vocabulary audit pass.
    DEST.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        (DEST / name).write_bytes(data)
    (DEST / "index.json").write_bytes(encoded_json(index))
    verify()
    print(f"Exported {audit_count} source-exact practice references and {basmala_audit_count} separately sourced opening phrases.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--verify", action="store_true", help="Verify existing resources with Python standard library only")
    args = parser.parse_args()
    if args.verify:
        verify()
    else:
        generate()


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, importlib.metadata.PackageNotFoundError) as error:
        print(f"Practice reference export failed: {error}", file=sys.stderr)
        raise SystemExit(1)
