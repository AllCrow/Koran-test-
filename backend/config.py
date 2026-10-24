from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path

MODEL_ID = "obadx/muaalem-model-v3_2"
MODEL_REVISION = "01a1ef9fbe40d144ef845101e89ff924aed3fef5"
ENGINE_VERSION = "0.2.2"


@dataclass(frozen=True)
class Settings:
    resource_directory: Path = Path(__file__).resolve().parents[1] / "Sources/QuranPractice/Resources/PracticeReferences"
    max_upload_bytes: int = 8 * 1024 * 1024
    max_duration_seconds: float = 60.0
    min_duration_seconds: float = 0.35
    api_key: str | None = None
    enable_model: bool = False
    model_local_files_only: bool = True
    model_device: str = "cpu"
    ffmpeg_binary: str = "ffmpeg"

    @classmethod
    def from_env(cls) -> "Settings":
        default = cls()
        return cls(
            resource_directory=Path(os.environ.get("SAKINA_QURAN_RESOURCES", str(default.resource_directory))),
            api_key=os.environ.get("SAKINA_API_KEY") or None,
            enable_model=os.environ.get("SAKINA_ENABLE_MODEL", "0") == "1",
            model_local_files_only=os.environ.get("SAKINA_ALLOW_MODEL_DOWNLOAD", "0") != "1",
            model_device=os.environ.get("SAKINA_MODEL_DEVICE", "cpu"),
            ffmpeg_binary=os.environ.get("SAKINA_FFMPEG", "ffmpeg"),
        )
