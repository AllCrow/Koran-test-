from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re

from .schemas import ReferenceID

REFERENCE_SOURCE = "quran-transcript-0.6.4"


class ReferenceUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class ResolvedReference:
    identifier: ReferenceID
    text: str
    scalar_offset: int
    include_basmala: bool


class ReferenceRepository:
    """Read the same pinned practice edition independently bundled by iOS.

    This edition is separate from the reader's Uthmani resource. Error offsets
    must never be applied to the reader's edition.
    """
    source = REFERENCE_SOURCE

    def __init__(self, directory: Path):
        self.directory = directory

    @lru_cache(maxsize=1)
    def _index(self) -> dict:
        try:
            index = json.loads((self.directory / "index.json").read_text(encoding="utf-8"))
            if (not isinstance(index, dict) or type(index.get("version")) is not int
                    or index["version"] != 1 or index.get("source") != self.source):
                raise ValueError("Wrong practice reference source")
            declarations = index.get("surahs")
            hashes = index.get("hashes")
            if not isinstance(declarations, list) or not declarations or not isinstance(hashes, dict):
                raise ValueError("Invalid practice reference index")
            seen = set()
            for declaration in declarations:
                if (not isinstance(declaration, dict)
                        or type(declaration.get("id")) is not int
                        or not 1 <= declaration["id"] <= 114
                        or declaration["id"] in seen
                        or type(declaration.get("count")) is not int
                        or declaration["count"] < 1):
                    raise ValueError("Invalid practice reference declaration")
                seen.add(declaration["id"])
                digest = hashes.get(f"{declaration['id']:03d}.json")
                if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
                    raise ValueError("Invalid practice reference checksum")
            return index
        except (OSError, KeyError, TypeError, ValueError) as error:
            raise ReferenceUnavailable("Practice reference index unavailable") from error

    @property
    def available(self) -> bool:
        try:
            index = self._index()
            return all((self.directory / f"{entry['id']:03d}.json").is_file() for entry in index["surahs"])
        except (ReferenceUnavailable, KeyError, TypeError, OSError):
            return False

    @lru_cache(maxsize=114)
    def _chapter(self, surah_id: int) -> dict:
        try:
            name = f"{surah_id:03d}.json"
            payload = (self.directory / name).read_bytes()
            expected_hash = self._index()["hashes"][name]
            if hashlib.sha256(payload).hexdigest() != expected_hash:
                raise ValueError("Practice reference checksum mismatch")
            chapter = json.loads(payload)
            if (not isinstance(chapter, dict) or type(chapter.get("surah_id")) is not int
                    or chapter["surah_id"] != surah_id):
                raise ValueError("Wrong practice reference chapter")
            declaration = next(entry for entry in self._index()["surahs"] if entry["id"] == surah_id)
            ayahs = chapter.get("ayahs")
            if not isinstance(ayahs, list) or len(ayahs) != declaration["count"]:
                raise ValueError("Wrong practice reference verse count")
            for number, ayah in enumerate(ayahs, 1):
                if (not isinstance(ayah, dict) or type(ayah.get("ayah_number")) is not int
                        or ayah["ayah_number"] != number or not isinstance(ayah.get("text"), str)
                        or not ayah["text"].strip()):
                    raise ValueError("Invalid practice reference verse")
            basmala = chapter.get("basmala")
            if basmala is not None and (not isinstance(basmala, str) or not basmala.strip()):
                raise ValueError("Invalid practice reference Basmala")
            return chapter
        except (OSError, KeyError, TypeError, ValueError) as error:
            raise ReferenceUnavailable("Practice reference chapter unavailable") from error

    def resolve(self, surah_id: int, ayah_number: int, *, include_basmala: bool) -> ResolvedReference:
        if not 1 <= surah_id <= 114 or ayah_number < 1:
            raise ValueError("Invalid reference")
        declared = next((entry for entry in self._index()["surahs"] if entry["id"] == surah_id), None)
        if declared is None or ayah_number > declared["count"]:
            raise ValueError("Invalid reference")
        chapter = self._chapter(surah_id)
        # _chapter validated consecutive numbering and the declared count.
        ayah = chapter["ayahs"][ayah_number - 1]
        text = ayah["text"]
        if include_basmala and ayah_number == 1 and surah_id not in (1, 9):
            basmala = chapter.get("basmala")
            if not isinstance(basmala, str) or not basmala:
                raise ReferenceUnavailable("Attested practice Basmala unavailable")
            text = basmala + " " + text
        scalar_offset = 1 if text.startswith("\ufeff") else 0
        if scalar_offset:
            text = text[1:]
        return ResolvedReference(
            identifier=ReferenceID(surah_id=surah_id, ayah_number=ayah_number),
            text=text,
            scalar_offset=scalar_offset,
            include_basmala=include_basmala,
        )
