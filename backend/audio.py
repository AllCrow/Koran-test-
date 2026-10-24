from __future__ import annotations

from array import array
from dataclasses import dataclass
import io
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

from .config import Settings

SAMPLE_RATE = 16_000


class InvalidAudio(ValueError):
    pass


class InsufficientAudio(ValueError):
    pass


class DecoderUnavailable(RuntimeError):
    pass


@dataclass
class DecodedAudio:
    samples: array
    sample_rate: int = SAMPLE_RATE

    @property
    def duration(self) -> float:
        return len(self.samples) / self.sample_rate


def _pcm16_samples(raw: bytes) -> array:
    if len(raw) % 2:
        raise InvalidAudio("Ljudfilen innehåller ofullständiga PCM-data.")
    integers = array("h")
    integers.frombytes(raw)
    if sys.byteorder != "little":
        integers.byteswap()
    return array("f", (sample / 32768.0 for sample in integers))


def decode_audio(payload: bytes, settings: Settings) -> DecodedAudio:
    """Decode a bounded local file. No recording or filename is logged/retained."""
    raw: bytes | None = None
    if payload.startswith(b"RIFF"):
        try:
            with wave.open(io.BytesIO(payload), "rb") as recording:
                if recording.getcomptype() == "NONE" and recording.getnchannels() == 1 and recording.getsampwidth() == 2 and recording.getframerate() == SAMPLE_RATE:
                    if recording.getnframes() > settings.max_duration_seconds * SAMPLE_RATE:
                        raise InvalidAudio("Inspelningen får vara högst 60 sekunder.")
                    raw = recording.readframes(recording.getnframes())
        except (wave.Error, EOFError) as error:
            raise InvalidAudio("Ljudfilen kunde inte läsas.") from error
    if raw is None:
        executable = shutil.which(settings.ffmpeg_binary)
        if executable is None:
            raise DecoderUnavailable("Ljudavkodaren saknas på servern. Använd PCM WAV, mono, 16 kHz.")
        with tempfile.TemporaryDirectory(prefix="sakina-audio-") as directory:
            source = Path(directory) / "input.audio"
            source.write_bytes(payload)
            try:
                result = subprocess.run(
                    [executable, "-nostdin", "-hide_banner", "-loglevel", "error",
                     "-protocol_whitelist", "file,pipe", "-i", str(source),
                     "-map", "0:a:0", "-vn", "-sn", "-dn",
                     "-ac", "1", "-ar", str(SAMPLE_RATE),
                     "-t", str(settings.max_duration_seconds + 0.1),
                     "-f", "s16le", "-acodec", "pcm_s16le", "pipe:1"],
                    capture_output=True, timeout=20, check=False,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                raise InvalidAudio("Ljudfilen kunde inte avkodas inom tidsgränsen.") from error
            if result.returncode != 0:
                raise InvalidAudio("Ljudfilen kunde inte avkodas.")
            raw = result.stdout
    audio = DecodedAudio(_pcm16_samples(raw))
    if audio.duration > settings.max_duration_seconds:
        raise InvalidAudio("Inspelningen får vara högst 60 sekunder.")
    if audio.duration < settings.min_duration_seconds:
        raise InsufficientAudio("Inspelningen är för kort. Läs en hel fras och försök igen.")
    rms = math.sqrt(sum(sample * sample for sample in audio.samples) / len(audio.samples))
    if rms < 0.0008:
        raise InsufficientAudio("Inspelningen är för tyst för att analysera. Försök igen nära mikrofonen.")
    return audio
