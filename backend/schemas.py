from __future__ import annotations

from typing import Literal
from pydantic import BaseModel, ConfigDict, Field

from .config import ENGINE_VERSION, MODEL_ID, MODEL_REVISION


class ReferenceID(BaseModel):
    model_config = ConfigDict(extra="forbid")
    surah_id: int
    ayah_number: int


class Issue(BaseModel):
    model_config = ConfigDict(extra="forbid")
    kind: Literal["tajweed", "normal", "tashkeel"]
    category: Literal["insert", "delete", "replace"]
    start_scalar: int = Field(ge=0)
    end_scalar: int = Field(ge=0)
    expected: str
    observed: str
    message: str


class Assessment(BaseModel):
    model_config = ConfigDict(extra="forbid")
    schema_version: Literal[1] = 1
    status: Literal["assessed", "unavailable", "insufficient_audio"]
    experimental: Literal[True] = True
    engine: Literal["quran-muaalem"] = "quran-muaalem"
    engine_version: str = ENGINE_VERSION
    model: str = MODEL_ID
    model_revision: str = MODEL_REVISION
    reference: ReferenceID
    reference_text: str
    reference_source: str = "quran-transcript-0.6.4"
    reference_scalar_offset: int = Field(ge=0)
    include_basmala: bool
    issues: list[Issue] = Field(default_factory=list)
    message: str
    assumptions: list[str] = Field(default_factory=lambda: [
        "Hafs an Asim",
        "Madd munfasil: 4 harakat; madd muttasil: 4; muttasil vid waqf: 4. Madd arid: 2, 4 eller 6 harakat godtas för samma långvokal.",
        "Endast fonetiska modellutdata jämförs; sifat-huvudena bedöms inte i denna version.",
        "Experimentell modell. Kvaliteten har inte jämförts med Tarteel eller verifierats av tajweedlärare.",
    ])
